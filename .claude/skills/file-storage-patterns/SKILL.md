---
name: file-storage-patterns
description: "Load when: designing or implementing file upload, storage, retrieval, image processing pipeline, or virus scanning for photos and videos. Block storage, presigned URLs, CDN delivery. Loaded by: sk.architecture, sk.implement (backend)."
---

# File Storage Patterns

## Purpose
Production patterns for block storage of user-generated photos and videos. Covers the upload flow, presigned URL generation, image processing pipeline (resize, thumbnail, format conversion), async virus scanning with quarantine, CDN delivery, and access control. Applies to any service handling binary assets.

## Core Rules

### Storage Topology
* **Block storage** (S3-compatible API): primary store for all files. Two buckets per environment:
  * `{env}-uploads-quarantine` — incoming files land here first, before virus scan clears them.
  * `{env}-assets-private` — scan-cleared files that require auth to access (draft listings, private documents).
  * `{env}-assets-public` — scan-cleared files served publicly via CDN (active listing photos, public thumbnails).
* Files never move from quarantine to public in one step — always quarantine → private → public (promotion requires explicit domain event).
* Never expose raw bucket URLs to clients. All access via presigned URLs (private assets) or CDN URLs (public assets).

### Upload Flow (Client-Initiated Direct Upload)
1. Client requests an upload URL from the BFF/API: `POST /api/v1/uploads/presign`.
2. Backend generates a presigned PUT URL for the quarantine bucket (TTL: 15 minutes).
3. Client uploads directly to block storage using the presigned URL — binary never passes through the backend.
4. Backend publishes `FileUploaded` event with `fileId`, `bucketKey`, `ownerId`, `mimeType`, `sizeBytes`.
5. Virus scan consumer processes the file asynchronously (see Virus Scan section).
6. Image pipeline consumer processes cleared images asynchronously (see Image Pipeline section).

### Presigned URL Rules
* Presigned PUT URL (upload): TTL 15 minutes. Single-use conceptually — do not reuse after upload.
* Presigned GET URL (download private asset): TTL maximum 1 hour. Generated on demand per request — never stored.
* Public CDN URL: permanent until the file is deleted or replaced. No presigned URL needed.
* Always validate `Content-Type` and `Content-Length` server-side after upload (read metadata from storage). Never trust client-provided values.
* Maximum file size: enforce at the presign step via storage policy (e.g., `content-length-range` condition in S3 presign). Do not rely solely on client-side validation.

### File Validation
* Allowed MIME types: `image/jpeg`, `image/png`, `image/webp`, `image/heic`, `video/mp4`, `video/quicktime`.
* After upload completes: verify actual MIME type by reading magic bytes (not file extension). Reject mismatches.
* File size limits: images 20MB, videos 500MB. Enforce at presign (`content-length-range`).
* Reject files that fail MIME verification immediately — publish `FileRejected` event, delete from quarantine.

### Virus Scanning
* Every uploaded file is scanned before it leaves the quarantine bucket.
* Scan trigger: MassTransit consumer on `FileUploaded` event.
* Integration: ClamAV (self-hosted) or cloud AV service via HTTP. Wrap in circuit breaker (Polly).
* On **clean**: move file from quarantine to private bucket → publish `FileScanCleared` event.
* On **infected**: delete file from quarantine → publish `FileScanInfected` event → notify owner → log at ERROR with `fileId`, `ownerId`, `threatName`.
* On **scan error**: retry 3 times with backoff → dead-letter after exhaustion → alert ops → file stays in quarantine.
* SLA: scan must complete within 60 seconds of upload for images, 5 minutes for videos.
* Never promote a file to private or public bucket without a confirmed clean scan result recorded in the database.

### Image Processing Pipeline
* Trigger: MassTransit consumer on `FileScanCleared` for image MIME types.
* Processing steps (in order):
  1. **HEIC → JPEG conversion** (if applicable).
  2. **Strip EXIF metadata** (removes GPS location, device info — privacy requirement).
  3. **Generate variants**: thumbnail (150×150 crop), medium (800px max dimension), large (1600px max dimension), original (as-uploaded, no resize).
  4. **Compress**: JPEG quality 85, WebP conversion for modern clients.
  5. **Write all variants** to private bucket under structured key: `{ownerId}/{listingId}/{fileId}/{variant}.{ext}`.
* Publish `ImageProcessingCompleted` event with variant keys and dimensions.
* Failures: retry 3 times → dead-letter → alert ops. Do not block listing publish on image processing — decouple.

### Bucket Key Structure
```
{env}/{entity-type}/{owner-id}/{entity-id}/{file-id}/{variant}.{extension}
```
Example: `prod/listings/usr_abc/lst_xyz/fid_123/medium.webp`

* Never use sequential integers or predictable patterns in key paths for private assets.
* Include entity context (`listingId`) in the key for efficient listing-level cleanup on deletion.

### CDN Delivery (Public Assets)
* Public assets served via CDN (CloudFront, Cloudflare, or similar). CDN origin: public bucket.
* CDN cache TTL: 1 year (assets are immutable — content-addressed or versioned keys).
* On asset replacement (new photo uploaded): use a new `fileId` — never overwrite existing keys. Old keys expire from CDN naturally.
* Do NOT issue CDN cache invalidations per-file — prohibitively expensive at scale. Use versioned keys instead.
* CDN URL format: `https://cdn.example.com/{env}/{entity-type}/{owner-id}/{entity-id}/{file-id}/{variant}.{ext}`.

### Access Control
* Private assets: presigned GET URL generated server-side after authorization check. TTL ≤ 1 hour.
* Public assets: CDN URL returned directly. No auth required to access — by design for published listings.
* Audit: log every presigned GET URL generation (who requested access to what, when).
* File ownership: store `ownerId`, `entityId`, `entityType` in the `file_assets` table. Authorization check in application handler before presign.

### File Lifecycle & Deletion
* Soft-delete in database first (`deleted_at`). Schedule physical deletion via Hangfire job (default: 30-day grace period).
* Physical deletion: delete all variants from storage → delete database record.
* On listing deletion: cascade delete all associated file records (soft). Hangfire cleanup job handles physical deletion.
* Never delete immediately on user request — use grace period for accidental deletion recovery.

### Observability
* Metrics: `file_upload_total{status}`, `file_scan_duration_seconds`, `file_scan_result_total{result}`, `image_processing_duration_seconds{variant}`, `file_storage_bytes_total{bucket}`.
* Alert: `file_scan_result_total{result="error"}` rate > 0. Any scan error needs ops attention.
* Alert: `image_processing_duration_seconds p99 > 30s` — pipeline is congested.

## Patterns / Examples

### Presign upload endpoint
```csharp
[HttpPost("presign")]
[Authorize]
public async Task<ActionResult<PresignedUploadResponse>> RequestUpload(
    PresignUploadRequest request, CancellationToken ct)
{
    // Validate allowed MIME type
    if (!_allowedMimeTypes.Contains(request.MimeType))
        return BadRequest(ProblemDetails.From("Unsupported file type"));

    var fileId = Guid.NewGuid();
    var key    = $"quarantine/{User.GetOwnerId()}/{request.EntityId}/{fileId}";

    var presignedUrl = await _storage.GeneratePresignedPutUrlAsync(
        bucket: _options.QuarantineBucket,
        key: key,
        mimeType: request.MimeType,
        maxBytes: _options.MaxImageBytes,
        ttl: TimeSpan.FromMinutes(15),
        ct);

    await _fileRepo.RegisterPendingUploadAsync(fileId, User.GetOwnerId(), request.EntityId, key, ct);
    await _uow.CommitAsync(ct);

    return Ok(new PresignedUploadResponse(fileId, presignedUrl, ExpiresInSeconds: 900));
}
```

### Virus scan consumer
```csharp
public class VirusScanConsumer(IStorageService storage, IVirusScanService scanner,
    IFileRepository fileRepo, IPublishEndpoint publish, ILogger<VirusScanConsumer> logger)
    : IConsumer<FileUploaded>
{
    public async Task Consume(ConsumeContext<FileUploaded> context)
    {
        var msg = context.Message;
        var stream = await storage.OpenReadAsync(_options.QuarantineBucket, msg.BucketKey, context.CancellationToken);

        var result = await scanner.ScanAsync(stream, context.CancellationToken);

        if (result.IsClean)
        {
            await storage.MoveAsync(_options.QuarantineBucket, msg.BucketKey,
                                    _options.PrivateBucket, msg.BucketKey, context.CancellationToken);
            await fileRepo.MarkScanClearedAsync(msg.FileId, context.CancellationToken);
            await publish.Publish(new FileScanCleared(msg.FileId, msg.MimeType, msg.OwnerId), context.CancellationToken);
        }
        else
        {
            logger.LogError("Virus detected in file {FileId} for owner {OwnerId}: {Threat}", msg.FileId, msg.OwnerId, result.ThreatName);
            await storage.DeleteAsync(_options.QuarantineBucket, msg.BucketKey, context.CancellationToken);
            await fileRepo.MarkScanInfectedAsync(msg.FileId, result.ThreatName!, context.CancellationToken);
            await publish.Publish(new FileScanInfected(msg.FileId, msg.OwnerId, result.ThreatName!), context.CancellationToken);
        }
    }
}
```

## When to Use
* Any feature that accepts user-uploaded photos or videos
* Designing the file storage schema and bucket structure
* Implementing the upload flow, scan pipeline, or image processing
* `sk.architecture` when a service needs to handle binary assets

## When NOT to Use
* CMS images (Strapi + Cloudflare R2 — separate pipeline managed by Strapi)
* Small configuration files or JSON documents → PostgreSQL JSONB or object storage without the full pipeline
* Serving static frontend assets → CDN-delivered build artefacts, not this pipeline

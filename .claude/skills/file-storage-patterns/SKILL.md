---
name: file-storage-patterns
description: "Load when: designing or implementing file upload, storage, retrieval, image processing pipeline, or virus scanning for photos and videos. Block storage, presigned URLs, CDN delivery."
---

# File Storage Patterns

## Purpose
Production patterns for block storage of user-generated photos and videos. Covers the upload flow, presigned URL generation, image processing pipeline (resize, thumbnail, format conversion), async virus scanning with quarantine, CDN delivery, and access control. Applies to any service handling binary assets.

## Core Rules

### Bounded Context & Aggregate

File storage is a **bounded context** owned by a dedicated `file-svc` (or co-located inside the owning service when volume is low — but always with its own schema and aggregate). Other services reference files by `FileAssetId` only; they never read storage keys, MIME types, or scan state directly.

**Aggregate root: `FileAsset`** — the consistency boundary for the lifecycle of a single binary asset. State machine:

```
PendingUpload  → (presigned URL issued, awaiting client PUT)
   → Quarantined        (FileUploaded received; sitting in quarantine bucket)
       → Cleared        (FileScanCleared; moved to private bucket)
           → PublicPromoted   (owner published the entity referencing this asset)
       → Infected       (FileScanInfected; deleted from quarantine; terminal)
   → Rejected           (MIME or size validation failed; terminal)
   → Archived           (soft-deleted; awaiting Hangfire physical purge; terminal)
```

* All state transitions go through methods on `FileAsset` (`MarkUploaded`, `MarkScanCleared`, `MarkScanInfected`, `PromoteToPublic`, `SoftDelete`). External code never sets state fields directly.
* MIME-type allow-list and size limits are aggregate invariants enforced in `FileAsset.RequestUpload(...)` — see the presign example below. Controllers and consumers never duplicate these checks.

**Domain events** (raised by `FileAsset`, published as integration events via the transactional outbox — see `messaging-patterns`):

| Event | Raised when | Subscribers (typical) |
|---|---|---|
| `FileUploaded` | Client confirms PUT (or storage-side notification fires) | Virus scan consumer |
| `FileScanCleared` | Scan returns clean and file is moved to private bucket | Image pipeline consumer; owning entity (e.g. listing) for read-model update |
| `FileScanInfected` | Scan detects malware | Owner notification consumer; audit log |
| `FileRejected` | MIME/size verification fails post-upload | Owner notification |
| `ImageProcessingCompleted` | All variants written | Owning entity for read-model update; CDN warm-up |
| `FilePromotedToPublic` | Entity that owns the file is published | CDN URL exposure |
| `FileArchived` | Soft-delete applied | Hangfire schedule for physical purge |

**Orchestration choice for the upload → scan → process pipeline:** use a **MassTransit state-machine saga** (see `messaging-patterns`), not Elsa. Rationale: the flow is a fixed technical pipeline with no SLA breach alerts, no human steps, and no business-configurable branching — exactly the shape sagas were designed for. Reserve Elsa (`workflow-patterns`) for SLA-driven business workflows (e.g. "listing must be approved within 48h"). The saga state machine owns: `Pending → Scanning → Processing → Ready` with compensating transitions to `Infected` / `Failed`, persisted via the EF Core saga repository.

### Storage Topology
* **Block storage** (S3-compatible API): primary store for all files. Two buckets per environment:
  * `{env}-uploads-quarantine` — incoming files land here first, before virus scan clears them.
  * `{env}-assets-private` — scan-cleared files that require auth to access (draft listings, private documents).
  * `{env}-assets-public` — scan-cleared files served publicly via CDN (active listing photos, public thumbnails).
* Files never move from quarantine to public in one step — always quarantine → private → public (promotion requires explicit domain event).
* Never expose raw bucket URLs to clients. All access via presigned URLs (private assets) or CDN URLs (public assets).

### Event Publishing — Always via the Transactional Outbox

Every domain event raised by `FileAsset` (`FileUploaded`, `FileScanCleared`, `FileScanInfected`, `FileRejected`, `ImageProcessingCompleted`, `FilePromotedToPublic`, `FileArchived`) is published as a MassTransit integration event through the **transactional outbox** — see `messaging-patterns` (Transactional Outbox section). Hard rules:

* The command handler / consumer that mutates the `FileAsset` aggregate writes state and the outbox row in a single database transaction (`AddEntityFrameworkOutbox<FileAssetDbContext>`). Never call `IPublishEndpoint.Publish` outside the outbox-managed unit of work.
* The virus scan consumer and image pipeline consumer below are themselves MassTransit consumers — when they update `FileAsset` state and publish a follow-on event, the same outbox guarantee applies. Any direct `Publish` call in their `Consume` method is a bug: the file's state and the downstream event must commit atomically or not at all.
* This eliminates the dual-write problem between block storage and the database: the bucket move (quarantine → private) is done first; the state update + outbox row is committed second; the event is relayed third. If the relay never runs, retry by replaying outbox rows — the operation is naturally idempotent because storage moves are key-addressed.

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

### Presign upload — thin controller, MediatR command, write-side handler

The controller owns no orchestration. The command handler owns aggregate construction, persistence, and presigned URL generation through an injected port.

```csharp
// API layer — controller does only validation + dispatch
[ApiController]
[Route("api/v1/uploads")]
[Authorize(Policy = "RequireAuthenticated")]
public class UploadsController(ISender mediator) : ControllerBase
{
    [HttpPost("presign")]
    [ProducesResponseType<PresignedUploadResponse>(StatusCodes.Status201Created)]
    public async Task<ActionResult<PresignedUploadResponse>> Presign(
        PresignUploadRequest req, CancellationToken ct)
        => (await mediator.Send(req.ToCommand(User.GetUserId()), ct))
              .ToActionResult(this);
}

// Application layer — CQRS command (write side: creates a FileAsset aggregate)
public record RequestPresignedUploadCommand(
    Guid OwnerId, Guid EntityId, string EntityType, string MimeType, long SizeBytes)
    : ICommand<PresignedUploadResponse>;

public class RequestPresignedUploadHandler(
    IFileAssetWriteRepository repo,
    IFileStoragePort storage,                  // port abstracting S3 — Infrastructure implements
    IUnitOfWork uow,
    IOptions<FileStorageOptions> options,
    ILogger<RequestPresignedUploadHandler> logger)
    : ICommandHandler<RequestPresignedUploadCommand, PresignedUploadResponse>
{
    public async Task<Result<PresignedUploadResponse>> Handle(
        RequestPresignedUploadCommand cmd, CancellationToken ct)
    {
        // Domain validates MIME + size — invariants live in the aggregate, not the controller
        var asset = FileAsset.RequestUpload(
            ownerId:    cmd.OwnerId,
            entityId:   cmd.EntityId,
            entityType: cmd.EntityType,
            mimeType:   cmd.MimeType,
            sizeBytes:  cmd.SizeBytes,
            policy:     options.Value.UploadPolicy);
        if (asset.IsFailure) return Result.Failure<PresignedUploadResponse>(asset.Error);

        await repo.AddAsync(asset.Value, ct);

        // Port returns the presigned URL — the handler does not know about S3 directly
        var url = await storage.GeneratePresignedPutUrlAsync(
            bucket:    options.Value.QuarantineBucket,
            key:       asset.Value.QuarantineKey,
            mimeType:  cmd.MimeType,
            maxBytes:  options.Value.MaxBytesFor(cmd.MimeType),
            ttl:       TimeSpan.FromMinutes(15),
            ct);

        await uow.CommitAsync(ct);
        logger.LogInformation("Presigned upload requested: file {FileId} owner {OwnerId}",
            asset.Value.Id, cmd.OwnerId);

        return Result.Success(new PresignedUploadResponse(asset.Value.Id, url, ExpiresInSeconds: 900));
    }
}
```

Notes:
* `FileAsset.RequestUpload(...)` is the aggregate factory — it owns MIME-type allow-list and size limit invariants. The controller and handler never validate these themselves.
* `IFileStoragePort` is the Application-layer abstraction; the concrete S3-compatible implementation lives in Infrastructure.
* The response (`PresignedUploadResponse`) is a write-side acknowledgement DTO — it carries only the new ID and the URL needed to perform the upload, nothing about the asset state. Subsequent reads use the query side.

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
* When a service needs to handle binary assets (photos, videos, documents)

## When NOT to Use
* CMS images (Strapi + Cloudflare R2 — separate pipeline managed by Strapi)
* Small configuration files or JSON documents → PostgreSQL JSONB or object storage without the full pipeline
* Serving static frontend assets → CDN-delivered build artefacts, not this pipeline

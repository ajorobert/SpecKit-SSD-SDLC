---
name: file-pipeline-patterns
description: |
  End-to-end file upload pipeline for .NET 10: SeaweedFS object storage, ImageSharp processing, nClam virus scanning, Wolverine-driven upload state machine (quarantine → scan → process → private/public). Covers presigned uploads via FastEndpoints, Upload aggregate persistence, image-variant generation, blob lifecycle, and ABAC for file access. Use for any feature that accepts user uploads or serves user-owned files.
when_to_load:
  - Task mentions: upload, file, attachment, image, blob, storage, seaweedfs, s3, presigned, virus, scan, clamav, imagesharp, resize, thumbnail, quarantine
  - Files touched: any *Upload*.cs, *File*.cs, *Image*.cs, *Attachment*.cs, *Storage*.cs, *.Adapters.SeaweedFs/*, *.Adapters.Nclam/*, *.Adapters.ImageSharp/*
co_loads_with:
  - wolverine-patterns (saga + outbox)
  - persistence-patterns (Upload aggregate write path)
  - fastendpoints-patterns (presigned-upload endpoint + idempotency)
  - backend-feature-patterns (handler shape)
references:
  - keycloak-patterns (ABAC for owner-scoped file access)
  - hybridcache-patterns (thumbnail URL caching)
  - workflow-and-jobs-patterns (orphan-cleanup recurring job — Phase 4e placeholder)
---

# File-Pipeline Patterns

## 1. Mental model

```
   FastEndpoints presign endpoint → signed URL to quarantine + Upload aggregate ID (Pending)
        ▼
   Client PUTs bytes directly to SeaweedFS quarantine
        ▼
   FastEndpoints complete endpoint → command UploadCompleted
        ▼
   Wolverine handler persists Upload (Quarantined); outbox UploadQuarantinedEvent
        ▼
   UploadProcessingSaga:
     UploadQuarantinedEvent → IVirusScanService.ScanAsync
        clean    → UploadScanCleanEvent
        infected → UploadScanInfectedEvent (file purged, aggregate Rejected, saga ends)
     UploadScanCleanEvent → if image: IImageProcessor.ProcessAsync (resize, EXIF strip)
        → UploadProcessedEvent
     UploadProcessedEvent → MoveAsync quarantine → private|public
        → aggregate Available; outbox UploadAvailableIntegrationEvent
```

**Rule:** every uploaded byte transits the `quarantine` bucket first; nothing reaches `private` or `public` until scan + process complete.

## 2. Bucket strategy

| Bucket | Purpose | Access | Retention |
|---|---|---|---|
| `quarantine` | Uploaded, unscanned | Signed PUT only (write); read by scanner | 24h max (lifecycle policy auto-purges abandoned uploads) |
| `private` | Scanned-clean, owner-scoped | Signed read URLs only (TTL ≤ 1h) | aggregate-lifetime |
| `public` | Scanned-clean, world-readable | CDN-fronted; immutable, content-addressed URLs (`<hash>/<filename>`) | aggregate-lifetime |

A file moves `quarantine → private` OR `quarantine → public` — never `private ↔ public` directly. Per-bucket versioning, encryption-at-rest, and lifecycle config is a deployment concern, not a skill concern.

## 3. Port: IFileStorageService

Interface in Application; SeaweedFS implementation in `YourContext.Adapters.SeaweedFs`. App code never touches the S3 SDK directly.

```csharp
namespace YourContext.Application.Files;

public enum Bucket { Quarantine, Private, Public }

public sealed record UploadCredentials(string PresignedUrl, IReadOnlyDictionary<string, string> FormFields, DateTimeOffset ExpiresAt);

public interface IFileStorageService
{
    Task<UploadCredentials> GetUploadCredentialsAsync(Bucket bucket, string key, TimeSpan ttl, CancellationToken ct);
    Task<Stream> OpenReadAsync(Bucket bucket, string key, CancellationToken ct);
    Task MoveAsync(Bucket from, string fromKey, Bucket to, string toKey, CancellationToken ct);
    Task DeleteAsync(Bucket bucket, string key, CancellationToken ct);
    Task<string> GetSignedReadUrlAsync(Bucket bucket, string key, TimeSpan ttl, CancellationToken ct);
}
```

## 4. Port: IImageProcessor

Interface in Application; ImageSharp implementation in `YourContext.Adapters.ImageSharp`. The caller (the saga) chooses destination bucket + key; the processor only produces bytes.

```csharp
namespace YourContext.Application.Files;

public sealed record ImageVariantSpec(string Name, int MaxWidth, int MaxHeight, string Format, int Quality);
public sealed record ImageProcessingOptions(IReadOnlyList<ImageVariantSpec> Variants, bool StripExif = true);
public sealed record ProcessedImageVariant(string Name, ReadOnlyMemory<byte> Bytes, string ContentType, int Width, int Height);
public sealed record ProcessedImage(IReadOnlyList<ProcessedImageVariant> Variants);

public interface IImageProcessor
{
    Task<ProcessedImage> ProcessAsync(Stream source, ImageProcessingOptions options, CancellationToken ct);
}
```

## 5. Port: IVirusScanService

Interface in Application; nClam implementation in `YourContext.Adapters.Nclam`. The caller streams the source — no full-file buffering.

```csharp
namespace YourContext.Application.Files;

public enum ScanOutcome { Clean, Infected, Error }
public sealed record ScanResult(ScanOutcome Outcome, string? SignatureName = null);

public interface IVirusScanService
{
    Task<ScanResult> ScanAsync(Stream source, CancellationToken ct);
}
```

Timeout: 30s per scan. Circuit-break on repeated `Error` outcomes — see `integration-adapter-patterns` §5 (standard resilience pipeline) for the wiring; the nClam adapter consumes it.

## 6. Presigned-upload endpoint

```csharp
namespace YourContext.Api.Features.Uploads.Presign;

public sealed class PresignUploadEndpoint(IMessageBus bus) : Endpoint<Request, Response>
{
    public override void Configure()
    {
        // ENDPOINT: POST /api/v1/uploads/presign
        Post("/api/v1/uploads/presign");
        // AUTH: Policy uploads.create — see keycloak-patterns §5
        Policies("uploads.create");
        MaxRequestBodySize(2 * 1024);
    }
    public override async Task HandleAsync(Request req, CancellationToken ct)
    {
        // IDEMPOTENCY: header forwarded on the command — see fastendpoints-patterns §6
        var idem = HttpContext.Request.Headers.TryGetValue("Idempotency-Key", out var v) ? v.ToString() : null;
        var result = await bus.InvokeAsync<ErrorOr<PresignedUploadResult>>(
            new RequestPresignedUploadCommand(req.Filename, req.ContentType, req.SizeBytes, req.TargetVisibility, idem), ct);
        await this.ToHttpResultAsync(result, r => new Response(r.UploadId, r.PresignedUrl, r.FormFields, r.ExpiresAt), ct);
    }
}
public sealed record Request(string Filename, string ContentType, long SizeBytes, string TargetVisibility);
public sealed record Response(Guid UploadId, string PresignedUrl, IDictionary<string, string> FormFields, DateTimeOffset ExpiresAt);
```

The aggregate is created in `Pending` state by the handler. It transitions to `Quarantined` only when the client calls `POST /api/v1/uploads/{uploadId}/complete` confirming the bytes are uploaded.

## 7. Upload aggregate

Aggregate root in `YourContext.Domain.Uploads.Upload`. States: `Pending → Quarantined → Scanning → Clean → Processing → Available | Rejected`.

```csharp
namespace YourContext.Domain.Uploads;

public sealed class Upload : AggregateRoot
{
    public UploadId Id { get; }
    public Guid OwnerId { get; } public Guid TenantId { get; }
    public UploadStatus Status { get; private set; }
    public string ContentType { get; private set; } public long SizeBytes { get; private set; }
    public string QuarantineKey { get; private set; } public string? FinalKey { get; private set; }
    public Bucket TargetBucket { get; private set; }
    public string? Checksum { get; private set; } public string? ScanSignature { get; private set; }

    public ErrorOr<Success> MarkQuarantined(string checksum)
    {
        if (Status != UploadStatus.Pending) return Error.Conflict("Upload.NotPending");
        Status = UploadStatus.Quarantined; Checksum = checksum;  // UPLOAD-STATE: Pending → Quarantined
        RaiseEvent(new UploadQuarantinedEvent(Id.Value, OwnerId, TenantId, QuarantineKey, ContentType));
        return Result.Success;
    }
    public ErrorOr<Success> MarkScanInfected(string sig) { Status = UploadStatus.Rejected; ScanSignature = sig; return Result.Success; }  // UPLOAD-STATE: → Rejected
    public ErrorOr<Success> MarkAvailable(string finalKey) { Status = UploadStatus.Available; FinalKey = finalKey; return Result.Success; }  // UPLOAD-STATE: Processing → Available
}
```

Aggregate persistence + outbox-bound publish follow `persistence-patterns` §3.

## 8. UploadProcessingSaga

Wolverine saga (`wolverine-patterns` §7). Each handler is its own transaction + outbox commit (`wolverine-patterns` §4, §6). Idempotent by saga state: re-receiving an event whose step already ran is a no-op.

```csharp
namespace YourContext.Application.Files.Saga;

public sealed class UploadProcessingSaga : Saga
{
    public Guid Id { get; set; }                                              // SAGA-STATE: correlation
    public Guid UploadId { get; set; }                                        // SAGA-STATE
    public Guid OwnerId { get; set; }                                         // SAGA-STATE
    public Guid TenantId { get; set; }                                        // SAGA-STATE
    public string QuarantineKey { get; set; } = "";                           // SAGA-STATE
    public string ContentType { get; set; } = "";                             // SAGA-STATE
    public Bucket TargetBucket { get; set; }                                  // SAGA-STATE
    public UploadStep Step { get; set; }                                      // SAGA-STATE

    [Transactional]
    public async Task<object[]> Handle(UploadQuarantinedEvent evt, IFileStorageService storage, IVirusScanService scanner, CancellationToken ct)
    {
        if (Step >= UploadStep.Scanned) return [];
        Id = UploadId = evt.UploadId; OwnerId = evt.OwnerId; TenantId = evt.TenantId;
        QuarantineKey = evt.QuarantineKey; ContentType = evt.ContentType;
        await using var stream = await storage.OpenReadAsync(Bucket.Quarantine, evt.QuarantineKey, ct);
        var scan = await scanner.ScanAsync(stream, ct);
        Step = UploadStep.Scanned;
        return scan.Outcome switch
        {
            ScanOutcome.Clean    => [new UploadScanCleanEvent(UploadId)],
            ScanOutcome.Infected => [new UploadScanInfectedEvent(UploadId, scan.SignatureName ?? "unknown")],
            _                    => throw new InvalidOperationException("Scanner Error — Wolverine retry"),
        };
    }

    [Transactional]
    public async Task<object[]> Handle(UploadScanCleanEvent _, IImageProcessor images, IFileStorageService storage, CancellationToken ct)
    {
        if (Step >= UploadStep.Processed) return [];
        if (ContentType.StartsWith("image/"))
        {
            await using var src = await storage.OpenReadAsync(Bucket.Quarantine, QuarantineKey, ct);
            _ = await images.ProcessAsync(src, ImagePipelineDefaults.Options, ct);
            // (Variant upload via storage — omitted for brevity)
        }
        Step = UploadStep.Processed;
        return [new UploadProcessedEvent(UploadId)];
    }

    [Transactional]
    public async Task Handle(UploadScanInfectedEvent evt, IFileStorageService storage, IUploadsRepository repo, CancellationToken ct)
    {
        await storage.DeleteAsync(Bucket.Quarantine, QuarantineKey, ct);
        var upload = (await repo.GetByIdAsync(new UploadId(UploadId), ct)).Value;
        _ = upload.MarkScanInfected(evt.SignatureName);
        await repo.SaveChangesAsync(ct);
        MarkCompleted();
    }

    [Transactional]
    public async Task Handle(UploadProcessedEvent _, IFileStorageService storage, IUploadsRepository repo, IMessageContext bus, CancellationToken ct)
    {
        var finalKey = $"{TenantId}/{UploadId}/original";
        await storage.MoveAsync(Bucket.Quarantine, QuarantineKey, TargetBucket, finalKey, ct);
        var upload = (await repo.GetByIdAsync(new UploadId(UploadId), ct)).Value;
        _ = upload.MarkAvailable(finalKey);
        // OUTBOX: integration event committed with the aggregate write
        await bus.EnqueueAsync(new UploadAvailableIntegrationEvent(UploadId, OwnerId, TenantId, TargetBucket, finalKey));
        await repo.SaveChangesAsync(ct);
        MarkCompleted();
    }
}

public enum UploadStep { Started, Scanned, Processed, Done }
```

## 9. Adapter: SeaweedFS specifics

S3-compatible API via AWSSDK.S3 configured against the SeaweedFS endpoint. Adapter lives in `YourContext.Adapters.SeaweedFs`; app code never sees `IAmazonS3`.

```csharp
namespace YourContext.Adapters.SeaweedFs;

public sealed class SeaweedFileStorageService(IAmazonS3 s3, IOptions<SeaweedOptions> opts) : IFileStorageService
{
    public async Task<UploadCredentials> GetUploadCredentialsAsync(Bucket bucket, string key, TimeSpan ttl, CancellationToken ct)
    {
        var req = new GetPreSignedUrlRequest { BucketName = opts.Value.BucketName(bucket), Key = key, Verb = HttpVerb.PUT, Expires = DateTime.UtcNow.Add(ttl) };
        // CONFIGUREAWAIT: adapter library code.
        var url = await Task.Run(() => s3.GetPreSignedURL(req), ct).ConfigureAwait(false);
        return new(url, new Dictionary<string, string>(), DateTimeOffset.UtcNow.Add(ttl));
    }
    // OpenReadAsync, MoveAsync (CopyObject + DeleteObject), DeleteAsync, GetSignedReadUrlAsync — analogous
}
```

Multi-part upload is used by the SDK transparently when files exceed ~100 MB.

## 10. Adapter: ImageSharp specifics

Configure at startup with format providers (JPEG, PNG, WebP, AVIF). Always strip EXIF before serving public images. Generate variants at upload time — never on read. Cache signed thumbnail URLs in `HybridCache` (TTL ≤ signed-URL-TTL / 2) — see `hybridcache-patterns` §4.

```csharp
namespace YourContext.Adapters.ImageSharp;

public sealed class ImageSharpProcessor : IImageProcessor
{
    public async Task<ProcessedImage> ProcessAsync(Stream source, ImageProcessingOptions options, CancellationToken ct)
    {
        using var img = await Image.LoadAsync(source, ct).ConfigureAwait(false);
        if (options.StripExif) img.Metadata.ExifProfile = null;
        var outs = new List<ProcessedImageVariant>(options.Variants.Count);
        foreach (var v in options.Variants)
        {
            using var clone = img.Clone(c => c.Resize(new ResizeOptions { Size = new Size(v.MaxWidth, v.MaxHeight), Mode = ResizeMode.Max }));
            await using var ms = new MemoryStream();
            IImageEncoder encoder = v.Format switch { "webp" => new WebpEncoder { Quality = v.Quality }, "jpeg" => new JpegEncoder { Quality = v.Quality }, _ => new PngEncoder() };
            await clone.SaveAsync(ms, encoder, ct).ConfigureAwait(false);
            outs.Add(new(v.Name, ms.ToArray(), $"image/{v.Format}", clone.Width, clone.Height));
        }
        return new(outs);
    }
}
```

## 11. Adapter: nClam specifics

`ClamClient(host, port)` is connection-pooled per app instance. `PingAsync` health-checks on startup and via periodic probe — see `observability-backend` for health-probe wiring. The freshclam signature-update sidecar runs alongside the ClamAV daemon (deployment concern).

```csharp
namespace YourContext.Adapters.Nclam;

public sealed class NclamVirusScanService(IOptions<NclamOptions> opts) : IVirusScanService
{
    public async Task<ScanResult> ScanAsync(Stream source, CancellationToken ct)
    {
        var client = new ClamClient(opts.Value.Host, opts.Value.Port) { MaxStreamSize = opts.Value.MaxBytes };
        var result = await client.SendAndScanFileAsync(source, ct).ConfigureAwait(false);
        return result.Result switch
        {
            ClamScanResults.Clean                  => new(ScanOutcome.Clean),
            ClamScanResults.VirusDetected          => new(ScanOutcome.Infected, result.InfectedFiles?.FirstOrDefault()?.VirusName),
            _                                      => new(ScanOutcome.Error),
        };
    }
}
```

## 12. Read path: serving files

Private files require an ABAC check (`keycloak-patterns` §6) — the endpoint loads the `Upload` aggregate, authorizes `CanReadUpload`, then issues a short-TTL signed URL. Public files have no ABAC; they are served via CDN with content-addressed keys.

```csharp
public sealed class GetUploadUrlEndpoint(IFileStorageService storage, IAuthorizationService authz, IUploadsReadService reads)
    : Endpoint<Request, Response>
{
    public override void Configure() { Get("/api/v1/uploads/{UploadId}/url"); Policies("uploads.read"); }
    public override async Task HandleAsync(Request req, CancellationToken ct)
    {
        var upload = await reads.GetByIdAsync(req.UploadId, ct);
        if (upload is null) { await this.ToHttpResultAsync<Response>(Error.NotFound("Upload.NotFound"), ct); return; }
        var ok = await authz.AuthorizeAsync(HttpContext.User, upload, "CanReadUpload");
        if (!ok.Succeeded) { await this.ToHttpResultAsync<Response>(Error.Forbidden("Upload.NoAccess"), ct); return; }
        // BUCKET: private — owner-scoped signed URL, TTL ≤ 1h
        var url = await storage.GetSignedReadUrlAsync(Bucket.Private, upload.FinalKey!, TimeSpan.FromMinutes(15), ct);
        await this.ToHttpResultAsync(ErrorOrFactory.From(new Response(url, DateTimeOffset.UtcNow.AddMinutes(15))), r => r, ct);
    }
}
```

## 13. Cleanup, orphans, retention

- Orphan quarantine files (uploaded but never `complete`d): purged by a recurring job after 24h — see `workflow-and-jobs-patterns` (Phase 4e placeholder).
- Rejected uploads: deleted from quarantine immediately by the saga; aggregate retained for audit.
- Deleted aggregates: tombstone for 30d, then blob deletion in `private`/`public` via a recurring job.
- Physical-delete via bucket lifecycle policies OR via the cleanup job — never inline in a request handler.

## 14. Anti-patterns

- Raw S3 SDK / `IAmazonS3` injected into app code — use `IFileStorageService`.
- Raw `Image.Load` / `ImageSharp` API in app code — use `IImageProcessor`.
- Raw `ClamClient` in app code — use `IVirusScanService`.
- Reading + scanning + processing in a single handler — use the saga; each step is its own handler.
- Serving from the `quarantine` bucket under any condition — always wait for scan-clean.
- Streaming uploads through the app process — use presigned URLs; client uploads direct to SeaweedFS.
- Storing EXIF in public images.
- Regenerating image variants on read — do it at upload time.
- Hardcoded bucket names in app code — use the `Bucket` enum.
- Signed-URL TTL > 1h for private files.
- Treating the saga as a transaction — it isn't; each handler is its own tx + outbox commit.

## 15. Comment markers emitted by this skill

- `// UPLOAD-STATE:` — annotates a state transition on the `Upload` aggregate.
- `// BUCKET:` — annotates a bucket choice (`quarantine` / `private` / `public`).

Inherits `// SAGA-STATE:` from `wolverine-patterns` and `// OUTBOX:` for outbox-bound publishes. Canonical marker index: `backend-feature-patterns §10`.

## 16. Testing

Integration tests use `Testcontainers` for both SeaweedFS and ClamAV. The ClamAV container is seeded with the EICAR test signature so an infected-path test exercises the real scanner.

```csharp
[Fact]
public async Task Quarantined_clean_upload_reaches_Available()
{
    var uploadId = Guid.NewGuid();
    await fixture.UploadCleanBlobAsync(uploadId);
    await bus.InvokeAsync(new UploadCompletedCommand(uploadId, checksum: "abc"));
    await fixture.WaitForSagaCompleteAsync(uploadId, TimeSpan.FromSeconds(20));
    Assert.Equal(UploadStatus.Available, (await fixture.GetUploadAsync(uploadId)).Status);
}
```

See `wolverine-patterns` §10 for saga-test harness shape.

## 17. References

- `wolverine-patterns §4, §6, §7` — outbox, integration events, sagas.
- `persistence-patterns §3, §5` — `Upload` aggregate write repo + `[Transactional]` outbox binding.
- `fastendpoints-patterns §3, §6` — presigned endpoint + idempotency-key contract.
- `backend-feature-patterns §3, §9` — handler shape and repository boundary.
- `keycloak-patterns §5, §6` — RBAC policy `uploads.create` + ABAC `CanReadUpload`.
- `hybridcache-patterns §4` — thumbnail URL caching.
- `integration-adapter-patterns` — scanner / storage adapter authoring with resilience.
- `workflow-and-jobs-patterns` — orphan-cleanup recurring job (Phase 4e placeholder).
- `observability-backend` — health probes for ClamAV + SeaweedFS (Phase 5 placeholder).
- `.specify/memory/system-context.md` — project bucket names + CDN config.

---
name: auth-patterns
description: "Load when: implementing or reviewing authentication, authorization, Keycloak integration, RBAC policies, or ABAC resource handlers in C# .NET 10. Loaded by: sk.architecture, sk.implement (backend), sk.security-audit."
---

# Auth Patterns (Keycloak + RBAC + ABAC)

## Purpose
Production patterns for identity and access control in .NET 10 ASP.NET Core services. Keycloak is the sole identity provider — it handles authentication, token issuance, MFA, OTP, and role assignment. The C# application is responsible for all access control decisions: role-based (RBAC) for coarse-grained permission checks, and attribute-based (ABAC) for fine-grained resource-level decisions.

**Division of responsibility:**
| Concern | Owner |
|---|---|
| Authentication (who are you?) | Keycloak |
| Role assignment and management | Keycloak realm |
| Session lifecycle | Keycloak (internal Infinispan) |
| RBAC enforcement (can you access this area?) | ASP.NET Core policy middleware |
| ABAC enforcement (can you act on this specific resource?) | C# authorization handlers |

**The application is fully stateless with respect to auth.** No session table. No token cache. No refresh logic. Every request carries a JWT; the middleware validates it on the spot against Keycloak's JWKS endpoint. That's it.

---

## Core Rules

### Keycloak JWT Validation
* Validate all requests using ASP.NET Core JWT Bearer middleware against Keycloak's JWKS endpoint. No custom token parsing.
* Keycloak auto-rotates signing keys — the middleware must fetch JWKS dynamically, not cache a static public key.
* Required configuration: `Authority` (realm URL), `Audience` (client ID). Both validated on every token.
* Token claims to extract and trust: `sub` (user ID — immutable), `email`, `preferred_username`, `realm_access.roles`, `tenant_id`, `user_type`, any other custom mapped claims.
* Custom Keycloak claims are added via Protocol Mappers in the realm — never computed in application code.

```csharp
// Program.cs
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.Authority = builder.Configuration["Keycloak:Authority"];
        // e.g. https://auth.example.com/realms/directory-prod
        options.Audience  = builder.Configuration["Keycloak:ClientId"];
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer           = true,
            ValidateAudience         = true,
            ValidateLifetime         = true,
            RoleClaimType            = "realm_access.roles",
            NameClaimType            = "preferred_username",
        };
        options.MapInboundClaims = false; // preserve Keycloak claim names as-is
    });
```

### Claims Principal — What the App Sees
* Extend `ClaimsPrincipal` with typed extension methods. Never read raw claim strings in business code.
* All claim access goes through a single `ClaimsPrincipalExtensions` class — one place to update if Keycloak claim names change.

```csharp
public static class ClaimsPrincipalExtensions
{
    public static Guid GetUserId(this ClaimsPrincipal user)
        => Guid.Parse(user.FindFirstValue("sub")
            ?? throw new UnauthorizedAccessException("sub claim missing"));

    public static string GetEmail(this ClaimsPrincipal user)
        => user.FindFirstValue("email") ?? throw new UnauthorizedAccessException("email claim missing");

    public static Guid GetTenantId(this ClaimsPrincipal user)
        => Guid.Parse(user.FindFirstValue("tenant_id")
            ?? throw new UnauthorizedAccessException("tenant_id claim missing"));

    public static string GetUserType(this ClaimsPrincipal user)
        => user.FindFirstValue("user_type") ?? "customer";
    // user_type values: "customer" | "vendor" | "admin" — set in Keycloak via protocol mapper

    public static bool IsInRole(this ClaimsPrincipal user, string role)
        => user.HasClaim("realm_access.roles", role);

    public static bool HasAnyRole(this ClaimsPrincipal user, params string[] roles)
        => roles.Any(r => user.HasClaim("realm_access.roles", r));
}
```

### Stateless Validation — No Session, No Cache
* The application stores **nothing** auth-related. No session table. No token cache. No Redis for auth.
* Every request: client sends `Authorization: Bearer {jwt}` → ASP.NET Core JWT Bearer middleware validates signature + expiry + audience against Keycloak JWKS → populates `HttpContext.User` → handler runs.
* Token refresh is the **client's responsibility** entirely. The backend never refreshes, never stores, never tracks tokens.
* JWKS keys are fetched from Keycloak on startup and refreshed automatically by the middleware when a new `kid` (key ID) is seen in a token header — no manual key management required.

---

## RBAC — Role-Based Access Control

Keycloak assigns roles in `realm_access.roles`. The application defines named policies that map to one or more roles. Controllers and route handlers reference policies — never raw role strings.

### Policy Registration
```csharp
builder.Services.AddAuthorization(options =>
{
    // Coarse-grained area access
    options.AddPolicy("RequireAdmin",
        p => p.RequireClaim("realm_access.roles", "admin"));

    options.AddPolicy("RequireVendor",
        p => p.RequireClaim("realm_access.roles", "vendor", "admin")); // admin can do anything a vendor can

    options.AddPolicy("RequireVerifiedVendor", p => p
        .RequireClaim("realm_access.roles", "vendor", "admin")
        .RequireClaim("user_type", "vendor")
        .RequireClaim("vendor_verified", "true")); // custom Keycloak claim set after verification

    options.AddPolicy("RequireAuthenticated",
        p => p.RequireAuthenticatedUser());
});
```

### Controller Usage
```csharp
[ApiController]
[Route("api/v1/listings")]
[Authorize(Policy = "RequireAuthenticated")]  // baseline: any logged-in user
public class ListingsController(ISender mediator) : ControllerBase
{
    [HttpPost]
    [Authorize(Policy = "RequireVerifiedVendor")]  // tighter: only verified vendors create
    public async Task<ActionResult<Guid>> Create(CreateListingRequest req, CancellationToken ct)
        => (await mediator.Send(req.ToCommand(User), ct)).ToActionResult(this);

    [HttpGet("{id}")]
    // No additional policy — any authenticated user can view
    public async Task<ActionResult<ListingDetailDto>> GetById(Guid id, CancellationToken ct)
        => (await mediator.Send(new GetListingQuery(id, User), ct)).ToActionResult(this);
}
```

---

## ABAC — Attribute-Based Access Control

RBAC answers "can this role access this area?". ABAC answers "can *this specific user* act on *this specific resource* given its current state?". ABAC is enforced in application command/query handlers — not at the route level.

**ABAC applies equally to reads and writes.** "Can this user *view* this draft listing?", "Can this vendor *see* another vendor's booking?", "Can this user *download* this private file?" are all ABAC questions. A `IQueryHandler<...>` that returns a single resource (or a filtered collection scoped to the caller) must run the same `IAuthorizationService.AuthorizeAsync(user, resource, policy)` check before returning the DTO — never assume "it's just a read, RBAC at the route is enough." Cross-ownership data leaks happen on the read side just as easily as on the write side.

For collection queries, ABAC is enforced by **scoping the query** itself (e.g., `WHERE owner_id = @callerId`) rather than per-row authorization after the fact — but the scoping predicate is still derived from the caller's attributes (resolved via `IUserContext`), and the choice of predicate is an authorization decision that lives in the query handler.

### The Three Attribute Sources
| Source | Examples |
|---|---|
| **Subject** (from Keycloak token) | `sub`, `tenant_id`, `user_type`, `subscription_tier`, `vendor_verified` |
| **Resource** (from domain entity) | `listing.OwnerId`, `listing.TenantId`, `listing.Status`, `listing.Region` |
| **Environment** | `DateTime.UtcNow`, feature flags, IP address, request context |

### IAuthorizationRequirement + IAuthorizationHandler Pattern
```csharp
// 1. Define the requirement (what must be true)
public class ResourceOwnerRequirement : IAuthorizationRequirement { }

public class SameTenantRequirement : IAuthorizationRequirement { }

public class EditableStatusRequirement : IAuthorizationRequirement
{
    public static readonly string[] EditableStatuses = ["pending", "active", "inactive"];
}

// 2. Implement handlers that evaluate subject + resource attributes
public class ListingOwnerHandler(ILogger<ListingOwnerHandler> logger)
    : AuthorizationHandler<ResourceOwnerRequirement, Listing>
{
    protected override Task HandleRequirementAsync(
        AuthorizationHandlerContext ctx,
        ResourceOwnerRequirement requirement,
        Listing listing)
    {
        var userId = ctx.User.GetUserId();

        if (listing.OwnerId == userId || ctx.User.IsInRole("admin"))
        {
            ctx.Succeed(requirement);
        }
        else
        {
            logger.LogWarning("User {UserId} denied ownership access to listing {ListingId}",
                userId, listing.Id);
        }
        return Task.CompletedTask;
    }
}

public class ListingTenantHandler
    : AuthorizationHandler<SameTenantRequirement, Listing>
{
    protected override Task HandleRequirementAsync(
        AuthorizationHandlerContext ctx,
        SameTenantRequirement requirement,
        Listing listing)
    {
        if (listing.TenantId == ctx.User.GetTenantId())
            ctx.Succeed(requirement);
        return Task.CompletedTask;
    }
}

public class ListingEditableStatusHandler
    : AuthorizationHandler<EditableStatusRequirement, Listing>
{
    protected override Task HandleRequirementAsync(
        AuthorizationHandlerContext ctx,
        EditableStatusRequirement requirement,
        Listing listing)
    {
        if (EditableStatusRequirement.EditableStatuses.Contains(listing.Status))
            ctx.Succeed(requirement);
        return Task.CompletedTask;
    }
}
```

### Policy Composition for ABAC
```csharp
// Register resource-based policies (evaluated against a resource instance)
builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("CanEditListing", p => p
        .AddRequirements(
            new ResourceOwnerRequirement(),     // must own the listing OR be admin
            new SameTenantRequirement(),        // must be in the same tenant
            new EditableStatusRequirement()));  // listing must be in an editable state
});

// Register handlers
builder.Services.AddScoped<IAuthorizationHandler, ListingOwnerHandler>();
builder.Services.AddScoped<IAuthorizationHandler, ListingTenantHandler>();
builder.Services.AddScoped<IAuthorizationHandler, ListingEditableStatusHandler>();
```

### ABAC in Query Handlers (Reads Are Not Exempt)
```csharp
public class GetListingDetailHandler(
    IListingReadRepository reads,
    IAuthorizationService authz,
    IUserContext user)
    : IQueryHandler<GetListingDetailQuery, ListingDetailDto>
{
    public async Task<Result<ListingDetailDto>> Handle(GetListingDetailQuery q, CancellationToken ct)
    {
        var dto = await reads.GetDetailAsync(q.ListingId, ct);
        if (dto is null)
            return Result.Failure<ListingDetailDto>(new NotFoundError("Listing not found"));

        // ABAC on the read: a draft listing is only visible to its owner / admins
        var authResult = await authz.AuthorizeAsync(user.Principal, dto, "CanViewListing");
        if (!authResult.Succeeded)
            return Result.Failure<ListingDetailDto>(new NotFoundError("Listing not found"));
            // Return NotFound (not Forbidden) to avoid leaking existence of unauthorized resources

        return Result.Success(dto);
    }
}
```

For collection queries, scope the SQL/ES query by the caller's attributes — never fetch all rows and filter in memory:

```csharp
// In the read repository — scoping predicate is derived from IUserContext
public Task<IReadOnlyList<ListingSummaryDto>> ListMineAsync(CancellationToken ct)
    => connection.QueryAsync<ListingSummaryDto>(
        "SELECT ... FROM listings WHERE owner_id = @ownerId AND deleted_at IS NULL",
        new { ownerId = user.UserId });
```

### ABAC in Command Handlers (Where It Belongs)
```csharp
public class UpdateListingHandler(
    IListingRepository repo,
    IAuthorizationService authz,
    IUnitOfWork uow)
    : IRequestHandler<UpdateListingCommand, Result>
{
    public async Task<Result> Handle(UpdateListingCommand cmd, CancellationToken ct)
    {
        // 1. Fetch the resource
        var listing = await repo.GetByIdAsync(cmd.ListingId, ct);
        if (listing is null)
            return Result.Failure(new NotFoundError("Listing not found"));

        // 2. ABAC: evaluate all requirements against the real resource
        var authResult = await authz.AuthorizeAsync(cmd.User, listing, "CanEditListing");
        if (!authResult.Succeeded)
            return Result.Failure(new ForbiddenError("You cannot edit this listing"));

        // 3. Proceed with domain operation
        listing.Update(cmd.Title, cmd.Price, cmd.Description);
        await uow.CommitAsync(ct);

        return Result.Success();
    }
}
```

### When RBAC and ABAC Work Together
```
Request arrives
    → RBAC (middleware): Is this role allowed to reach this endpoint at all?
        No  → 403 immediately, no DB hit
        Yes → Handler runs
            → ABAC (handler): Does this user's attributes satisfy the resource policy?
                No  → Result.Failure(ForbiddenError) → 403
                Yes → Domain operation executes
```

Never rely on RBAC alone for data mutations. Always apply ABAC in handlers to prevent cross-ownership attacks (e.g., a vendor modifying another vendor's listing within the same role).

---

## Multi-Tenancy

```csharp
// EF Core global query filter — applied to all queries automatically
protected override void OnModelCreating(ModelBuilder mb)
{
    mb.Entity<Listing>().HasQueryFilter(l =>
        l.TenantId == _tenantContext.TenantId && !l.IsDeleted);
}

// ITenantContext populated from token claim in middleware
public class TenantContextMiddleware(RequestDelegate next)
{
    public async Task InvokeAsync(HttpContext ctx, ITenantContext tenantCtx)
    {
        if (ctx.User.Identity?.IsAuthenticated == true)
            tenantCtx.TenantId = ctx.User.GetTenantId();
        await next(ctx);
    }
}
```

* The EF Core global filter is a safety net. ABAC `SameTenantRequirement` provides explicit enforcement.
* Both layers are required — defence in depth.

---

## Service-to-Service (M2M)

```csharp
// Keycloak Client Credentials grant for backend-to-backend calls
public class KeycloakM2MTokenService(IHttpClientFactory factory, IOptions<KeycloakOptions> opts, IMemoryCache cache)
{
    public async Task<string> GetAccessTokenAsync(CancellationToken ct)
    {
        const string cacheKey = "keycloak_m2m_token";
        if (cache.TryGetValue(cacheKey, out string? token)) return token!;

        using var client = factory.CreateClient("keycloak");
        var response = await client.PostAsync("/realms/directory/protocol/openid-connect/token",
            new FormUrlEncodedContent(new Dictionary<string, string>
            {
                ["grant_type"]    = "client_credentials",
                ["client_id"]     = opts.Value.ServiceClientId,
                ["client_secret"] = opts.Value.ServiceClientSecret,
            }), ct);

        var result = await response.Content.ReadFromJsonAsync<TokenResponse>(ct);
        cache.Set(cacheKey, result!.AccessToken,
            TimeSpan.FromSeconds(result.ExpiresIn - 30)); // refresh 30s before expiry
        return result.AccessToken;
    }
}
```

* One Keycloak service account per service with minimal scopes — no shared credentials.
* Never use user tokens for M2M calls. Never use the admin client secret outside infrastructure tooling.

---

## Dual-Caller Support — Direct Client vs. BFF

Services accept calls from two sources. Neither changes how RBAC or ABAC behaves — both operate on resolved user identity regardless of how it arrived.

| Call source | Token presented | User identity source |
|---|---|---|
| Direct client | User JWT (`Authorization: Bearer {user_jwt}`) | Claims in the validated JWT |
| Via BFF | M2M token (`Authorization: Bearer {m2m_token}`) | Propagated headers (`X-User-Id`, `X-Tenant-Id`, `X-User-Roles`) |

### Detecting the Caller

Keycloak sets `preferred_username` to `service-account-{client_id}` on all M2M (client credentials) tokens. This is reliable and requires no extra configuration.

```csharp
// Add to ClaimsPrincipalExtensions
public static bool IsM2MClient(this ClaimsPrincipal user)
    => user.FindFirstValue("preferred_username")
           ?.StartsWith("service-account-", StringComparison.OrdinalIgnoreCase) == true;
```

### Stripping Spoofed Headers from Direct Callers

Propagated context headers must **only** be accepted from verified M2M callers. A direct client must never be able to inject these headers and impersonate another user.

```csharp
// Register early in the pipeline — before any handler reads these headers
app.Use(async (ctx, next) =>
{
    if (!ctx.User.IsM2MClient())
    {
        // Direct caller: strip propagated headers — they are internal-only
        ctx.Request.Headers.Remove("X-User-Id");
        ctx.Request.Headers.Remove("X-Tenant-Id");
        ctx.Request.Headers.Remove("X-User-Roles");
    }
    await next(ctx);
});
```

### Synthetic Principal for RBAC Transparency

Route-level `[Authorize]` policies evaluate `ClaimsPrincipal.HasClaim("realm_access.roles", ...)`. When the BFF presents an M2M token, those claims reflect the BFF service account's roles — not the propagated user's roles. To make RBAC work correctly in both flows without duplicating policies, replace the principal for M2M calls with a synthetic one built from propagated headers:

```csharp
public class PropagatedUserContextMiddleware(RequestDelegate next)
{
    public async Task InvokeAsync(HttpContext ctx)
    {
        // Only act after JWT Bearer middleware has authenticated the caller
        if (ctx.User.Identity?.IsAuthenticated == true && ctx.User.IsM2MClient())
        {
            var userId   = ctx.Request.Headers["X-User-Id"].ToString();
            var tenantId = ctx.Request.Headers["X-Tenant-Id"].ToString();
            var roles    = ctx.Request.Headers["X-User-Roles"].ToString()
                .Split(',', StringSplitOptions.RemoveEmptyEntries);

            // Build a synthetic principal that mirrors what a direct user JWT would produce.
            // This makes RBAC policies evaluate correctly against the propagated user's roles.
            var claims = new List<Claim>
            {
                new("sub",                userId),
                new("tenant_id",          tenantId),
                new("preferred_username", $"service-account-bff"), // preserves IsM2MClient() = true
            };
            claims.AddRange(roles.Select(r => new Claim("realm_access.roles", r)));

            ctx.User = new ClaimsPrincipal(new ClaimsIdentity(claims, "BffPropagated"));
        }

        await next(ctx);
    }
}
```

Register the middleware in the correct order:

```csharp
app.UseAuthentication();                   // 1. JWT Bearer validates token, populates ctx.User
app.Use(StripSpoofedHeadersMiddleware);    // 2. Remove propagated headers from non-M2M callers
app.UseMiddleware<PropagatedUserContextMiddleware>(); // 3. Replace ctx.User for M2M callers
app.UseAuthorization();                    // 4. RBAC policies now evaluate correctly for both flows
```

After step 3, `[Authorize(Policy = "RequireVendor")]` on a route works correctly whether the caller is a direct user or the BFF — the resolved principal always carries the actual user's roles.

### IUserContext — Unified Identity for Handlers

ABAC handlers and application services should use `IUserContext` rather than reading `ClaimsPrincipal` directly. After `PropagatedUserContextMiddleware` runs, `ClaimsPrincipal` is already correct for both flows — `IUserContext` wraps it cleanly:

```csharp
public interface IUserContext
{
    Guid     UserId   { get; }
    Guid     TenantId { get; }
    string[] Roles    { get; }
    bool     IsViaM2M { get; } // true when called through BFF — useful for audit logging
}

public class HttpUserContext(IHttpContextAccessor accessor) : IUserContext
{
    private ClaimsPrincipal User =>
        accessor.HttpContext?.User ?? throw new InvalidOperationException("No active HTTP context");

    public Guid     UserId   => User.GetUserId();
    public Guid     TenantId => User.GetTenantId();
    public string[] Roles    => User.FindAll("realm_access.roles").Select(c => c.Value).ToArray();
    public bool     IsViaM2M => User.IsM2MClient();
}
```

Register:
```csharp
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<IUserContext, HttpUserContext>();
```

Use in handlers:
```csharp
public class GetMyListingsHandler(IListingRepository repo, IUserContext userCtx)
    : IRequestHandler<GetMyListingsQuery, IReadOnlyList<ListingSummary>>
{
    public async Task<IReadOnlyList<ListingSummary>> Handle(
        GetMyListingsQuery query, CancellationToken ct)
        => await repo.GetByOwnerAsync(userCtx.UserId, userCtx.TenantId, ct);
}
```

ABAC handlers continue to work without modification — `IAuthorizationHandler<TRequirement, TResource>` receives `AuthorizationHandlerContext.User`, which is now always the resolved user principal regardless of call source.

---

## Token Revocation Strategy — Short Lifetime (Chosen)

The app is stateless: it cannot invalidate tokens. If a user's role is revoked in Keycloak, the old token remains valid until expiry. Mitigation: keep access token lifetime short so the window of exposure is small.

**Keycloak realm settings (configure in realm, not in code):**
* Access token lifespan: **5 minutes**
* Refresh token lifespan: **30 minutes** (or session max, whichever is shorter)
* Clients handle refresh silently via Keycloak SDK — no user impact

**Why this works for this application:**
* Not time-critical — a 5-minute lag on role revocation is acceptable
* Simpler than token introspection (no Keycloak round-trip per request, no added latency)
* No infrastructure dependency on Keycloak being up per request — JWKS keys are cached by the middleware

**What this does NOT protect against:**
* A compromised token is valid for up to 5 minutes after discovery. If immediate revocation is ever needed (e.g., suspected account takeover), the only remedy is to rotate the Keycloak realm signing key — this invalidates all outstanding tokens immediately. Document this as the incident response procedure.

**If requirements change and immediate revocation is needed:** switch to Keycloak Token Introspection (`/protocol/openid-connect/token/introspect`) as a drop-in replacement for local JWKS validation. This is an ADR-level change — do not implement without explicit decision.

---

## Security Non-Negotiables
* `MapInboundClaims = false` — required to preserve Keycloak claim names without ASP.NET's automatic remapping.
* No tokens, secrets, or claim values in logs. Redact `Authorization` headers in logging middleware.
* All cookies: `Secure`, `HttpOnly`, `SameSite=Strict`.
* HTTPS only. No HTTP fallback in production.
* Keycloak client secrets rotated every 90 days minimum. Alert on upcoming expiry.
* Admin endpoints (`/admin/**`, Hangfire dashboard, health details) require `RequireAdmin` policy. No exceptions.
* Access token lifespan set to 5 minutes in Keycloak realm — never increase without an ADR.

---

## When to Use
* Any backend service requiring authentication or access control
* Defining new RBAC policies for a new surface or role
* Implementing ABAC handlers for a new resource type (Listing, Booking, Review, etc.)
* `sk.security-audit` — authorization coverage review
* `sk.architecture` — access control design for a new service

## When NOT to Use
* Keycloak realm/client configuration (done in Keycloak admin console or Terraform/IaC)
* Frontend auth flows — NextAuth v5 in Next.js (see `nextjs-patterns`), Keycloak JS SDK in admin SPA (see `react-admin-patterns`), Expo auth in mobile (see `react-native-patterns`)
* Designing the Keycloak realm structure, authentication flows, or MFA policy — those are infrastructure decisions, not application code

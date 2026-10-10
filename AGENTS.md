# AGENTS.md

Repository-specific notes for agents working in the Vedora revival.

## What this is

Vedora is a Roblox revival that runs **2021 only**. The public domain is
`https://vedora.xyz` (`www.vedora.xyz` is kept as an alias). The `.NET`
solution lives in `Roblox/Roblox.sln`.

## Layout

- `Roblox/` - .NET backend (website, api proxy, extracted services).
- `Roblox/Vedora.RccServiceArbiter` - RCC arbiter. Launches
  `RCCService/RCCService2021/RCCService.exe` for both game servers and renders.
- `RCCService/RCCService2021` - the bundled 2021 RCCService install (committed, game servers + renders).
- `frontend/` - Next.js web frontend (2021 theme).
- `api/` - database migrations and legacy public assets.
- `admin/` - Svelte admin panel.
- `game-server/`, `game-renderer/` - Lua RCC scripts (legacy 2016 paths remain
  in a few files; leave them unless explicitly asked).
- `vedora.bat` - one-click Windows launcher. `run.bat`/`start.bat` wrap it.

## Build and test

```bash
cd Roblox
dotnet build Roblox.sln -v q
dotnet test Roblox.sln
```

Unit/integration suites and their infrastructure needs:

- `Roblox.UnitTest`, `Roblox.Libraries.UnitTest`, `Roblox.Services.Api.Tests`,
  `Roblox.ApiProxy.Tests`, `Roblox.Web.Infrastructure.Tests`,
  `Vedora.RccServiceArbiter.Tests`, `Roblox.Rendering.Test`,
  `Roblox.Metrics.Tests` - no external dependencies.
- `Roblox.Services.Admin.Tests`, `Roblox.Services.Avatar.Tests`,
  `Roblox.Services.Users.Tests` - no external dependencies.
- `Roblox.IntegrationTest` - needs Postgres at host `postgres` with
  `Database=roblox_integration_test; Username=roblox_integration_test_user;
  Password=docker`. These fail outside the Docker network; that is expected.

`Roblox.Services.Avatar.Tests` / `Roblox.Services.Api.Tests` contain
route-matrix tests that assert every controller route is listed in a matrix.
When you add or change a controller route, update the matching route case file
(e.g. `AvatarRouteCase.cs`, `AuthenticationRouteTests.cs`,
`UniversesRouteTests.cs`) or the matrix test fails.

## Conventions

- 2021-only: `AllowedGameYears` (Games.cs), the `asset_place` year default, the
  arbiter `GameServerYear`/`Render:DefaultYear`, and frontend year selectors are
  all pinned to 2021. Do not reintroduce other years: game servers and renders
  both run `RCCService2021`.
- The RCC arbiter resolves relative paths via
  `Vedora.RccServiceArbiter/Configuration/RccPathResolver.cs` so it works
  regardless of the working directory.
- The arbiter must not carry a `Postgres` or `Redis` key in its
  `appsettings.json`. It serves renders only and never touches the database, but
  `RobloxServiceInfrastructure.Initialize` opens a synchronous Npgsql connection
  at startup whenever `Postgres` is set. A slow or unreachable host then crashes
  the whole arbiter with `NpgsqlException: Timeout during reading attempt` before
  it can serve anything. The arbiter test fixture already empties both keys for
  the same reason — keep them out of the shipped config too.
- RCC launch flags come from configuration (built by
  `Processes/RccLaunchArguments.cs`, `{port}` = allocated SOAP port). Game
  servers use `Arbiter:GameServerLaunchArguments` (RCCService2021) and pass
  `-SettingsFile "DevSettingsFile.json"`, which sets
  `DebugCrashOnFailToLoadClientSettings: false` so RCC does not crash when it
  cannot fetch Roblox client settings over the network. Keep that flag false;
  do not hardcode the command line again. Renders use
  `Arbiter:Render:LaunchArguments`, which drives the same RCCService2021 build,
  so it needs the same 2021 flags
  (`-Console -Verbose -SettingsFile "DevSettingsFile.json" -port {port}`).
- `Arbiter:SoapServiceUrl` must stay `roblox.com`; RCCService dispatches SOAP
  in the `http://roblox.com/` WSDL namespace. Changing it makes RCC return
  HTTP 500 for every SOAP call. The bundled `RCCService2021/RCCService.exe` was
  rebranded from its original `pekora.zip` domain to `vedora.xyz`; the only
  strings left as `roblox.com` in that binary are the three SOAP service URLs
  (`http://roblox.com/RCCServiceSoap[12]?` and the single-arg service URL) that
  must match this namespace.
- `RCCService/RCCService2021/AppSettings.xml` `<BaseUrl>` points at
  `https://vedora.xyz`. The RCC binary reads its base URL from the
  `AppSettings.xml` beside it, and the relocatable asset URLs hardcoded in the
  2021 Lua scripts (Package.lua, Model.lua) point at `roblox.com` to match the
  bundled build.
- Renders do **not** use the JSON in `RenderScripts/Modern`. RCC loads a
  Lua script named after the thumbnail `Type` from
  `RCCService/RCCService2021/internalscripts/thumbnails/<Type>.lua` and passes
  the arbiter's `Arguments` as `...`. The bundled 2021 build ships the full
  modern script set (`Image.lua`, `AnimationSilhouette.lua`, `PlaceValidation.lua`,
  `modules/`), so renders run on 2021 too. If a
  `Type` has no matching `.lua`, that render fails with `Failed to open script
  file` and the website shows the generic "3D Render not available" message. Add
  a script for any new `Type`, and run `RCCService/diagnose-render.bat`
  (arbiter up) to see the real RCC error surface. The
  `EveryRenderKindHasThumbnailScript` test fails if a render kind has no script.
- `Avatar` (2D body shot) and `Avatar3D` both use `Type=Avatar_R15_Action`; only
  the output format differs (`PNG` vs `OBJ`/`obj`). Modifying the avatar render
  path therefore affects 2D and 3D together.
- The `Avatar3D` OBJ token is case-sensitive per build and picked from
  `Arbiter:Render:DefaultYear` in `RenderScriptCatalog.ObjFormatToken()`: the
  RCCService2021 render build only matches lowercase `obj`, while older builds
  (e.g. 2020) expect uppercase `OBJ` (`exportScene` when
  `fileType == "OBJ"`). A
  wrong token matches neither the OBJ path nor the `JPG`/`JPEG`/`TGA`/`PNG`
  encoders, so RCC returns no data and `thumbnail_3d_url` stays `NULL` while 2D
  renders still work.
- Avatar thumbnails honour `IsCdnEnabled`: with the CDN **on** they go to R2 and
  are linked with `R2StorageService.GetPublicUrl`; with it **off** (the local
  Windows setup) `Avatar.cs` writes them to `Directories__Thumbnails` and links
  them under `/images/thumbnails/...`, which `ThumbnailMiddleware` serves from
  that same directory. Keep both branches in sync — writing only to R2 while the
  CDN is disabled leaves every render returning an empty result even though the
  arbiter reported success.
- `ThumbnailMiddleware` derives the `Content-Type` from the file extension. The
  3D render JSON must be served as `application/json`, otherwise axios fails to
  parse the response and the client reports "3D Render not available".
- The thumbnail/group/admin image *URL builders* (`ThumbnailsService.GetThumbnailUrl`,
  `GroupsService.GetGroupIconUrl`, `AdminApiService.GetImageUrl`) must also honour
  `IsCdnEnabled`. When the CDN is off they return a root-relative `/images/...`
  path so the request stays on the current origin. Building an absolute
  `CdnBaseUrl` (e.g. `http://localhost:5200`) makes the browser fetch a second
  origin that may not be reachable or routed, so renders 404 even though the file
  exists on disk.
- `Roblox/Roblox.ApiProxy/appsettings.json` only routes the public host
  `vedora.xyz` (and `www.`) to the website cluster. `docker-compose.yml` adds a
  `website-localhost-route` for `localhost`/`127.0.0.1`, because `vedora.bat`
  prints `http://localhost:5200` and `FrontendProxy__PublicHosts` lists
  localhost. Without that route every page, `/img` and `/images/...` request on
  localhost returns 404. Keep the localhost website route in sync with the
  `*-apisite-route` host lists.
- `Roblox/Roblox.ApiProxy/appsettings.json` is committed (routes for
  `*.vedora.xyz`). Keep secrets in server-local `appsettings.Production.json`.
- Internal services build a request context in `ProxyForwardedAuthMiddleware`
  and hash the caller IP, which requires `RobloxIpHasher` to be initialized
  first. That call lives in `UseRobloxServiceDefaults`, so it runs for every
  exposure. If a new service bypasses that extension and hashes an IP, requests
  fail with "IP hash setup is not initialized" and the endpoint returns 500.
- The api proxy only forwards its internal auth/identity headers for paths
  listed in `InternalServiceRoutes`. Any `/apisite/<service>/` route that is
  missing reaches its service with no session and returns 401. When you add an
  apisite route, add the matching `InternalServiceRoutes` entry and the
  `ApiProxyUsersConfigurationTests` prefix assertion.
- Do not restyle the frontend. Branding/domain replacements must not change
  layouts, CSS, or component structure.
- `Roblox.ApiProxy` must call `app.UseWebSockets()` before
  `FrontendProxyMiddleware`. The Next.js dev HMR channel (`/_next/webpack-hmr`)
  is a WebSocket; without the middleware YARP cannot tunnel the upgrade and logs
  a repeating 502 (`The response ended prematurely`). Normal page/API traffic is
  unaffected by the middleware.
- `FrontendProxyMiddleware` must forward upgrades with its
  `UpgradeRequestConfig` (no `ActivityTimeout`). The normal `RequestConfig`
  cancels the response copy after 100s of inactivity, which kills an idle HMR
  socket and logs `UpgradeResponseCanceled` for `/_next/webpack-hmr`. Also keep
  `/_next/` under `IsFrontendPublicAsset` so the HMR handshake does not require a
  session; redirecting it to `/` breaks the upgrade and forces a full reload.

## Gotchas

- The `/admin` SPA and the `/v1` admin API are served by `Roblox.ApiProxy`
  (see `AdminFrontendMiddleware`), so `OwnerUserId` must be set on the
  `api-proxy` service, not just `roblox-website`/`users-service`/`admin-service`.
  If it is missing, every `IsStaffAsync` check fails and `/admin` bounces to
  `/home`. The SPA also defaults its API origin to `https://admin.vedora.xyz/v1/`;
  the middleware injects `window.ADMIN_API_BASE_URL = window.location.origin + '/v1/'`
  into `index.html` so a local install talks to itself. `admin-host-route` matches
  `localhost`/`127.0.0.1` in dev. `AdminTwoFactor:Required=false` (dev compose only)
  skips the staff TOTP prompt because a fresh install has no TOTP device enrolled
  and there is no setup UI; production keeps 2FA required.
- Legacy bundles in `api/public/js/*.js` were previously corrupted by a bad
  domain search/replace. The correct namespace is `Roblox.CatalogShared` /
  `Roblox.CatalogValues` (see `api/public/js/46776eac503b939a2fd9146d77d735a3.js`).
  Beware of blind domain substitutions in minified JS.
- `Roblox/Roblox.Website/Controllers/RobloxApi/Asset.cs` serves `FixJitter`
  models; they are copied to the output/publish dir from `Roblox/FixJitter`.
- Vedora is 2021-only for gameplay. Game servers always launch
  `RCCService/RCCService2021/RCCService.exe` (arbiter `RccServiceRoot=RCCService`,
  `Arbiter:GameServerYear=2021`). Renders use the same build via
  `Arbiter:Render:DefaultYear=2021` (see the render conventions above). The
  website year (`WebsiteYear`) is a legacy per-user theme switch; `Users.GetYear`
  defaults every account to `Year2021`, so it does not select another RCC build.
- The ASP.NET DataProtection key ring is persisted through
  `AddVedoraDataProtection` (`Roblox.Web.Infrastructure/Extensions`), configured
  by `DataProtection:KeysDirectory` / `DataProtection:ApplicationName`. Every
  .NET service must share one directory and application name or antiforgery
  tokens/cookies fail to decrypt ("key was not found in the key ring"). The dev
  and prod compose files both set these and mount a shared volume.
- The `economy` bridge network in this sandbox has no egress, so the in-compose
  `dotnet-build`/`dotnet-watch` restore hangs on `api.nuget.org`. To build or
  test here, run the SDK image with `--network host`, e.g.
  `docker run --rm --network host -v $PWD:/srv/app -w /srv/app/Roblox -v vedora-dev_dotnet_cache:/root/.nuget mcr.microsoft.com/dotnet/sdk:10.0 dotnet test …`.
- The same missing egress makes `db-migrate` stall: `npm install` builds
  `argon2` via `node-pre-gyp`, which downloads its prebuilt binary from GitHub.
  The registry itself is reachable and `knex`/`pg` install first, so migrations
  can be run in place once they are present:
  `docker exec -e DB_HOST=postgres -e DB_USER=roblox -e DB_PASS=roblox_dev_pass -e DB_NAME=economy vedora-dev-db-migrate-1 npx knex migrate:latest`.
  Start the .NET services only after migrations finish, or the website's
  `RunDevelopmentBootstrapAsync` logs `relation "user" does not exist`.
- `R2StorageService`'s constructor throws when `R2AccountId` is unset
  (`ServiceURL is not a valid URL: https://.r2.cloudflarestorage.com`). Never
  build it unconditionally: guard with `Configuration.IsCdnEnabled` so
  CDN-disabled (local) installs fall back to the local thumbnails directory.

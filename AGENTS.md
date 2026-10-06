# AGENTS.md

Repository-specific notes for agents working in the Vedora revival.

## What this is

Vedora is a Roblox revival that runs **2021 only**. The public domain is
`https://vedora.xyz` (`www.vedora.xyz` is kept as an alias). The `.NET`
solution lives in `Roblox/Roblox.sln`.

## Layout

- `Roblox/` - .NET backend (website, api proxy, extracted services).
- `Roblox/Vedora.RccServiceArbiter` - RCC arbiter. Launches
  `RCCService/RCCService2021/RCCService.exe` for game servers and renders.
- `RCCService/RCCService2021` - the bundled 2021 RCCService install (committed).
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
  arbiter `GameServerYear`/`Render.DefaultYear`, and frontend year selectors are
  all pinned to 2021. Do not reintroduce other years.
- The RCC arbiter resolves relative paths via
  `Vedora.RccServiceArbiter/Configuration/RccPathResolver.cs` so it works
  regardless of the working directory.
- `Roblox/Roblox.ApiProxy/appsettings.json` is committed (routes for
  `*.vedora.xyz`). Keep secrets in server-local `appsettings.Production.json`.
- Do not restyle the frontend. Branding/domain replacements must not change
  layouts, CSS, or component structure.

## Gotchas

- Legacy bundles in `api/public/js/*.js` were previously corrupted by a bad
  domain search/replace. The correct namespace is `Roblox.CatalogShared` /
  `Roblox.CatalogValues` (see `api/public/js/46776eac503b939a2fd9146d77d735a3.js`).
  Beware of blind `pekora.zip`/`vedora.xyz` substitutions in minified JS.
- `Roblox/Roblox.Website/Controllers/RobloxApi/Asset.cs` serves `FixJitter`
  models; they are copied to the output/publish dir from `Roblox/FixJitter`.

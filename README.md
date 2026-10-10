# Vedora

Vedora is a Roblox revival that runs **2021 only**. Game servers use the bundled
`RCCService2021` build; thumbnails/renders use the `RCCService2020` build (the
build Vedora renders with, since it ships the full modern thumbnail scripts).

> [!CAUTION]
> Some parts of the source code are AI-generated (or vibecoded). Use at your own risk.

## Layout

- `Roblox/` - .NET backend (website, api proxy, extracted services).
- `Roblox/Vedora.RccServiceArbiter` - the RCC arbiter. It launches
  `RCCService/RCCService2021/RCCService.exe` for game servers and
  `RCCService/RCCService2020/RCCService.exe` for renders.
- `RCCService/RCCService2021` - the 2021 RCCService install (game servers).
- `RCCService/RCCService2020` - the 2020 RCCService install (renders/thumbnails).
- `frontend/` - Next.js web frontend (the 2021 theme).
- `api/` - database migrations and legacy public assets.
- `admin/` - Svelte admin panel.
- `AssetValidationServiceV2/` - Go asset validation service.

## Quick start

Run `vedora.bat` from the repository root. It installs dependencies and starts
every component:

- the Docker stack (Postgres, Redis, migrations, the .NET services, the
  frontend, the admin panel, the asset validation service)
- the RCC arbiter, which launches `RCCService2021` for game servers and
  `RCCService2020` for renders

The first run builds the Docker images and the .NET projects, so it can take a
few minutes. Run `vedora.bat down` to stop the Docker stack, then close the
arbiter window to stop the arbiter. `run.bat` and `start.bat` are thin wrappers
around the same launcher.

Requirements:

- Windows with Docker Desktop (the database and Redis run in containers).
- .NET SDK 10.
- Node.js 20+ (used inside the Docker stack).
- Go (for the asset validation service).

## Configuration

- Website/services: environment variables are read directly (see
  `docker-compose.yml` and `.env.prod.example`).
- Frontend: copy `frontend/config.docker-dev.json` to `frontend/config.json`, or
  run `node frontend/util/create_config.js`.
- Arbiter: `Roblox/Vedora.RccServiceArbiter/appsettings.json` holds the local
  development defaults. `ArbiterOptions.cs` documents every key. Production
  values come from environment variables such as `Arbiter__BaseUrl` and
  `Render__BaseUrl`.

The public domain defaults to `https://vedora.xyz`.

### RCCService launch arguments

The arbiter starts `RCCService.exe` with launch flags from configuration
(`{port}` is replaced with the allocated SOAP port):

- Game servers use `Arbiter:GameServerLaunchArguments`, which drives the
  `RCCService2021` build. The default is:

  ```
  -Console -Verbose -SettingsFile "DevSettingsFile.json" -port {port}
  ```

  `-SettingsFile` loads `DevSettingsFile.json` from the RCCService2021 folder.
  That file sets `DebugCrashOnFailToLoadClientSettings: false`, so RCC keeps
  running if it cannot fetch Roblox's client settings over the network. With the
  upstream `true` value RCC crashes with `RBXCRASH:
  LoadClientSettingsFailure (HttpError: ConnectFail)` before it opens its port.

- Renders use `Arbiter:Render:LaunchArguments`, which drives the
  `RCCService2020` build. The default mirrors the flags Vedora's render batch
  files use:

  ```
  -console -verbose -port {port}
  ```

  `-SettingsFile` is not passed here because the RCCService2020 install has no
  `DevSettingsFile.json`.

If your build needs the port differently, change the matching configuration
value instead of the code.

RCC reads its base URL from the `AppSettings.xml` next to the running binary
(`RCCService/RCCService2021/AppSettings.xml` for game servers,
`RCCService/RCCService2020/AppSettings.xml` for renders). Both point at
`<BaseUrl>https://vedora.xyz</BaseUrl>`, so settings and assets resolve
against the Vedora domain instead of `localhost:2015`.

`Arbiter:SoapServiceUrl` must stay `roblox.com`. RCCService dispatches SOAP
methods in its WSDL namespace `http://roblox.com/`; pointing this at another
domain makes RCC answer every SOAP call with HTTP 500 and the arbiter rejects
the worker.

If RCC never becomes ready, run `RCCService\diagnose-rcc.bat` from the
repository root. It launches RCCService directly and reports the TCP port it
actually opens, so you can compare it with the port range in
`Arbiter:Ports:Rcc`.


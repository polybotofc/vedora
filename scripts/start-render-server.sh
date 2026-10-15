#!/bin/sh
# Starts the Vedora RCC arbiter (the render server) on 0.0.0.0:3521.
#
# The arbiter is a host process, not a Compose service. Every dev-stack service
# reaches it through Render__BaseUrl=http://host.docker.internal:3521, so:
#   * it must bind 0.0.0.0, because a container cannot reach the host's 127.0.0.1;
#   * the port must stay 3521 to match Render__BaseUrl in docker-compose.yml.
#
# Usage:
#   scripts/start-render-server.sh            # bind 0.0.0.0:3521
#   RENDER_PORT=3600 scripts/start-render-server.sh
set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PORT=${RENDER_PORT:-3521}
PROJECT="$ROOT/Roblox/Vedora.RccServiceArbiter/Vedora.RccServiceArbiter.csproj"

# The arbiter reads appsettings.json (BaseUrl, RCCService paths, Render:DefaultYear),
# which only load for the Development environment.
export ASPNETCORE_ENVIRONMENT=Development

port_in_use() {
    if command -v ss >/dev/null 2>&1; then
        ss -ltn 2>/dev/null | awk '{print $4}' | grep -qE "[:.]${PORT}\$"
    elif command -v netstat >/dev/null 2>&1; then
        netstat -ltn 2>/dev/null | awk '{print $4}' | grep -qE "[:.]${PORT}\$"
    else
        return 1
    fi
}

echo "=========================================================="
echo "  Vedora RCC arbiter (render server)"
echo "  Bind:  0.0.0.0:${PORT}"
echo "  Root:  ${ROOT}"
echo "=========================================================="
echo

if port_in_use; then
    echo "[..] Port ${PORT} is already in use - an arbiter is probably running."
    echo "     Check:  ss -ltnp | grep ${PORT}   (or: netstat -ltnp | grep ${PORT})"
    exit 0
fi

if ! command -v dotnet >/dev/null 2>&1; then
    echo "[ERROR] dotnet was not found in PATH. Install the .NET SDK 10 and retry." >&2
    exit 1
fi

echo "[..] Starting arbiter (Ctrl+C to stop)..."
exec dotnet run --project "$PROJECT" --configuration Release --urls "http://0.0.0.0:${PORT}"

#!/bin/sh

set -eu

# The dev compose runs the stock mcr.microsoft.com/dotnet/aspnet:10.0 image
# directly (no Dockerfile), so two runtime dependencies are missing:
#
#  * libgssapi_krb5-2: Npgsql's GSSAPI path P/Invokes libgssapi_krb5.so.2, and
#    without it every service that opens a Postgres connection crashes at
#    startup with "libgssapi_krb5.so.2: cannot open shared object file".
#  * ffmpeg/ffprobe: audio and video upload validation (and audio->MP3/WAV
#    conversion) shell out to these through FFMpegCore/FFProbe. Without them
#    every audio/video upload fails validation and is rejected.
#
# The production image installs both in Roblox/Dockerfile.dotnet-service.
missing=''
if ! ldconfig -p | grep -q 'libgssapi_krb5\.so\.2'; then missing="$missing libgssapi-krb5-2"; fi
if ! command -v ffmpeg >/dev/null 2>&1 || ! command -v ffprobe >/dev/null 2>&1; then missing="$missing ffmpeg"; fi

if [ -n "$missing" ]; then
  echo "[dotnet] Installing missing runtime dependencies:$missing"
  apt-get update -qq
  # shellcheck disable=SC2086
  apt-get install -y --no-install-recommends $missing
  rm -rf /var/lib/apt/lists/*
fi

exec "$@"

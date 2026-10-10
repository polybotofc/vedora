#!/bin/sh

set -u

# The dev stack runs services directly on the stock mcr.microsoft.com/dotnet/aspnet
# image (no Dockerfile), so two runtime dependencies are missing:
#
#  * libgssapi-krb5-2: Npgsql's GSSAPI path P/Invokes libgssapi_krb5.so.2, and
#    without it a service that opens a Postgres connection can crash with
#    "libgssapi_krb5.so.2: cannot open shared object file".
#  * ffmpeg/ffprobe: audio and video upload validation (and audio -> MP3/WAV
#    conversion) shell out to these through FFMpegCore/FFProbe. Without them
#    every audio/video upload fails validation and is rejected.
#
# The production image installs both in Roblox/Dockerfile.dotnet-service. These
# installs are idempotent and skipped once the packages are present, so they are
# a no-op on an image that already provides them.
missing=''
if ! ldconfig -p | grep -q 'libgssapi_krb5\.so\.2'; then missing="$missing libgssapi-krb5-2"; fi
if ! command -v ffmpeg >/dev/null 2>&1 || ! command -v ffprobe >/dev/null 2>&1; then missing="$missing ffmpeg"; fi

if [ -n "$missing" ] && command -v apt-get >/dev/null 2>&1; then
  echo "[dotnet] Installing missing runtime dependencies:$missing"
  if apt-get update -qq && apt-get install -y --no-install-recommends $missing; then
    rm -rf /var/lib/apt/lists/*
  else
    echo "[dotnet] WARNING: could not install runtime dependencies:$missing" >&2
  fi
fi

assembly="${1:?service assembly name is required}"
shift

artifacts_root=/tmp/vedora-artifacts
dll="$artifacts_root/bin/$assembly/debug/$assembly.dll"
stamp="$artifacts_root/run-stamps/$assembly"
child_pid=''
stopping=0

stop_child() {
  stopping=1
  if [ -n "$child_pid" ] && kill -0 "$child_pid" 2>/dev/null; then
    kill -TERM "$child_pid" 2>/dev/null || true
    wait "$child_pid" 2>/dev/null || true
  fi
}

trap stop_child INT TERM

while [ "$stopping" -eq 0 ]; do
  while [ ! -f "$dll" ] || [ ! -f "$stamp" ]; do
    echo "[$assembly] Waiting for shared build output."
    sleep 1
  done

  observed_stamp="$(stat -c '%y' "$stamp")"
  echo "[$assembly] Starting $dll."
  dotnet "$dll" "$@" &
  child_pid=$!

  while kill -0 "$child_pid" 2>/dev/null; do
    sleep 1
    current_stamp="$(stat -c '%y' "$stamp" 2>/dev/null || true)"
    if [ "$current_stamp" != "$observed_stamp" ]; then
      echo "[$assembly] New build detected; restarting."
      kill -TERM "$child_pid" 2>/dev/null || true
      break
    fi
  done

  wait "$child_pid" 2>/dev/null || true
  child_pid=''
  if [ "$stopping" -eq 0 ]; then
    sleep 1
  fi
done

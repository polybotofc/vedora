#!/bin/sh

set -eu

# The dev compose runs the stock mcr.microsoft.com/dotnet/aspnet:10.0 image
# directly (no Dockerfile), so the runtime Kerberos library that Npgsql's
# GSSAPI path needs is not present. Without it every service that opens a
# Postgres connection crashes at startup with
# "libgssapi_krb5.so.2: cannot open shared object file".
# The production image installs this in Roblox/Dockerfile.dotnet-service.
if ! ldconfig -p | grep -q 'libgssapi_krb5\.so\.2'; then
  echo '[dotnet] Installing libgssapi-krb5-2 (missing Kerberos runtime).'
  apt-get update -qq
  apt-get install -y --no-install-recommends libgssapi-krb5-2
  rm -rf /var/lib/apt/lists/*
fi

exec "$@"

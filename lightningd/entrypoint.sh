#!/bin/sh
set -e

cp -u /testnet-config ${LIGHTNINGD_DATA}/testnet-config
cp -u /regtest-config ${LIGHTNINGD_DATA}/regtest-config
cp -u /config ${LIGHTNINGD_DATA}/config

# this is kept for backward compatibility purposes
export GREENLIGHT_VERSION=$(lightningd --version)
export VLS_CLN_VERSION=$(lightningd --version)

if [ $(echo "$1" | cut -c1) = "-" ]; then
  echo "$0: assuming arguments for lightningd"

  set -- lightningd "$@"
fi

echo
exec "$@"

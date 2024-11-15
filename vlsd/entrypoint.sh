#!/bin/sh
set -e
mkdir -p /home/vls/.lightning-signer/bitcoin/
cp /node.seed /home/vls/.lightning-signer/bitcoin/
cp /vlsd2.toml $VLSD_DATA/
sed -i "1s/^/network = \"$VLS_NETWORK\"\n/" $VLSD_DATA/vlsd2.toml

TXOO_PUBLIC_KEY=${TXOO_PUBLIC_KEY:=$(curl -s --retry 5 --retry-all-errors --fail http://txoo-server:80/config | grep public_key | cut -d ' ' -f 2)}

test -n "$TXOO_PUBLIC_KEY" || (echo "TXOO_PUBLIC_KEY build arg not set" && false)

if [ $(echo "$1" | cut -c1) = "-" ]; then
  echo "$0: assuming arguments for vlsd2"

  set -- vlsd2 "$@"
fi

if [ $(echo "$1" | cut -c1) = "-" ] || [ "$1" = "vlsd2" ]; then
  echo "$0: setting config to $VLSD_DATA/vlsd2.toml"

  echo "$0: using $TXOO_PUBLIC_KEY as trusted oracle pubkey"
  set -- "$@" --config=$VLSD_DATA/vlsd2.toml -t=$TXOO_PUBLIC_KEY
fi

echo
exec "$@"

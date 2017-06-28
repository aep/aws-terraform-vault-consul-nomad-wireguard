#!/bin/sh

eval "$(jq -r '@sh "SEED=\(.seed)"')"

#terraforms base64 is broken. need to use hex

priv=$(echo -n $SEED | xxd -r -p | base64)
pub=$(echo -n $priv | wg pubkey)

cat - <<EOF
{
    "priv" : "$priv",
    "pub" : "$pub"
}
EOF


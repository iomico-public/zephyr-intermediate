#!/bin/sh
# Generate a fresh pair of signing keys in secure-boot-app/keys/, overwriting any old ones.
# The device does not trust them: images signed with these keys are rejected.
set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
KEY_DIR="${SCRIPT_DIR}/../keys"
KEY_TYPE="${KEY_TYPE:-ecdsa-p256}"

# One key for TF-M's secure image, one for the Zephyr app; conf/own-keys.conf points at both.
KEY_S="${KEY_DIR}/root-EC-P256.pem"
KEY_NS="${KEY_DIR}/root-EC-P256_1.pem"

mkdir -p "${KEY_DIR}"

for key in "${KEY_S}" "${KEY_NS}"; do
    rm -f "${key}"
    imgtool keygen -k "${key}" -t "${KEY_TYPE}"

    # imgtool writes PKCS#8 ("BEGIN PRIVATE KEY"); convert to the EC format ("BEGIN EC PRIVATE KEY").
    openssl ec -in "${key}" -out "${key}" 2>/dev/null

    # Private key: readable by the owner only.
    chmod 600 "${key}"

    # Short hash of the public key, to tell key pairs apart.
    fingerprint=$(imgtool getpub -k "${key}" 2>/dev/null | sha256sum | cut -c1-16)
    format=$(head -1 "${key}" | tr -d '-')
    echo "generated ${key}  (${format}, pubkey ${fingerprint})"
done

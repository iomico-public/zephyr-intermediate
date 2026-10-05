#!/bin/sh
set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT=$(cd "${SCRIPT_DIR}/.." && pwd)
DEV="${SCRIPT_DIR}/dev.sh"
SCRIPTS="./scripts"
BOARD="mps2/an521/cpu0/ns"
APP="app/upgrade_probe"
SAMPLE="../zephyr/samples/tfm_integration/psa_protected_storage"

SAMPLE_HEX="build-psa/zephyr/tfm_merged.hex"
UNTRUSTED_KEY_HEX="build-keys/zephyr/tfm_merged.hex"
STAGED_HEX="out/noimageok.hex"

# Scenario: a correctly signed image boots.
success() {
    build_sample
    boot "${SAMPLE_HEX}"
}

# Scenario: one flipped byte in the app, BL2 rejects it.
tamper() {
    build_sample
    hexlab tamper "${SAMPLE_HEX}" out/tampered.hex
    boot out/tampered.hex
}

# Scenario: app signed with a key the device does not trust, BL2 rejects it.
wrong_key() {
    build_with_untrusted_key
    boot "${UNTRUSTED_KEY_HEX}"
}

# Scenario: upgrade staged without image_ok, BL2 keeps the old image.
upgrade_ignored() {
    stage_upgrade
    boot "${STAGED_HEX}"
}

# Scenario: same upgrade with image_ok set, BL2 swaps it in.
upgrade_applied() {
    stage_upgrade
    hexlab set-image-ok "${STAGED_HEX}" out/upgrade.hex
    boot out/upgrade.hex
}

# Build the upstream TF-M sample with the default keys.
build_sample() {
    already_built "${SAMPLE_HEX}" && return 0
    west_build build-psa "${SAMPLE}"
}

# Generate fresh keys and build the app signed with them.
build_with_untrusted_key() {
    already_built "${UNTRUSTED_KEY_HEX}" && return 0
    run "${DEV}" "${SCRIPTS}/gen-keys.sh"
    west_build build-keys "${APP}" -- -DEXTRA_CONF_FILE=/opt/zephyr-ws/secure-boot-app/conf/own-keys.conf
}

# Build the app as version $1.
build_version() {
    already_built "build-upg-v$1/zephyr/tfm_merged.hex" && return 0
    west_build "build-upg-v$1" "${APP}" -- "-DAPP_VERSION=$1"
}

# Put a signed v2 app into v1's secondary slot.
stage_upgrade() {
    already_built "${STAGED_HEX}" && return 0
    build_version 1
    build_version 2
    hexlab stage-upgrade build-upg-v1/zephyr/tfm_merged.hex build-upg-v2/zephyr/zephyr_ns_signed.hex "${STAGED_HEX}"
}

# Print a command, then run it.
run() {
    echo
    echo "+ $*"
    "$@"
}

# True if $1 exists and FORCE is not set.
already_built() {
    [ -z "${FORCE:-}" ] && [ -r "${PROJECT}/$1" ]
}

# Pristine west build into directory $1.
west_build() {
    dir="$1"
    shift
    run "${DEV}" west build -d "${dir}" -p always -b "${BOARD}" "$@"
}

# Run hexlab.py inside the container.
hexlab() {
    run "${DEV}" "${SCRIPTS}/hexlab.py" "$@"
}

# Boot a .hex in QEMU inside the container.
boot() {
    run "${DEV}" "${SCRIPTS}/qemu.sh" "$1"
}

# Print the scenario list and exit.
usage() {
    cat >&2 <<EOF
usage: $0 <scenario>

  success           valid signature boots
  tamper            one flipped byte in the NS payload is rejected
  wrong-key         image signed with an untrusted key is rejected
  upgrade-ignored   staged upgrade without image_ok is silently skipped
  upgrade-applied   same image with image_ok is swapped in
  all               every scenario in order

FORCE=1 rebuilds even if the artifact already exists.
EOF
    exit 1
}

[ "$#" -eq 1 ] || usage

case "$1" in
    success)          success ;;
    tamper)           tamper ;;
    wrong-key)        wrong_key ;;
    upgrade-ignored)  upgrade_ignored ;;
    upgrade-applied)  upgrade_applied ;;
    all)              success; tamper; wrong_key; upgrade_ignored; upgrade_applied ;;
    *)                usage ;;
esac

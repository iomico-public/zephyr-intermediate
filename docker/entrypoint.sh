#!/bin/sh
set -e

if [ -r /opt/zephyr-ws/zephyr/SDK_VERSION ] && [ -r "${ZEPHYR_SDK_INSTALL_DIR}/sdk_version" ]; then
    want=$(cat /opt/zephyr-ws/zephyr/SDK_VERSION)
    have=$(cat "${ZEPHYR_SDK_INSTALL_DIR}/sdk_version")
    if [ "${want}" != "${have}" ]; then
        echo "WARNING: zephyr tree wants SDK ${want}, image has ${have}." >&2
        echo "         Rebuild: docker build --build-arg SDK_VERSION=${want} ..." >&2
    fi
fi

exec "$@"

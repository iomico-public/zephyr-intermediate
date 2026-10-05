#!/bin/bash
# Boot one .hex file on an emulated AN521 board and show its UART output.
set -eu

if [ "$#" -ne 1 ]; then
    echo "usage: $0 <hex>" >&2
    exit 1
fi

HEX="$1"
TIMEOUT="${TIMEOUT:-25}"

if [ ! -r "${HEX}" ]; then
    echo "error: cannot read ${HEX}" >&2
    exit 1
fi

# The Zephyr SDK ships its own QEMU, in one of two places depending on the SDK layout.
SDK_BIN="x86_64-pokysdk-linux/usr/bin/qemu-system-arm"
QEMU="${ZEPHYR_SDK_INSTALL_DIR}/sysroots/${SDK_BIN}"
if [ ! -x "${QEMU}" ]; then
    QEMU="${ZEPHYR_SDK_INSTALL_DIR}/hosttools/sysroots/${SDK_BIN}"
fi
if [ ! -x "${QEMU}" ]; then
    echo "error: qemu-system-arm not found under ${ZEPHYR_SDK_INSTALL_DIR}" >&2
    exit 1
fi

QEMU_ARGS=(
    -machine mps2-an521            # Arm MPS2 board, AN521 image: Cortex-M33 with TrustZone
    -cpu cortex-m33                # the core BL2, TF-M and Zephyr all run on
    -m 16                          # 16 MB of RAM
    -nographic                     # no window: the board's UART prints to this terminal
    -vga none                      # no display device
    -device loader,file="${HEX}"   # write the .hex into flash, at the addresses it contains
)

# The AN521 has no power-off, so QEMU runs until the timeout stops it.
status=0
timeout --foreground "${TIMEOUT}" "${QEMU}" "${QEMU_ARGS[@]}" || status=$?

# 124 means the timeout stopped QEMU: a normal end of run.
if [ "${status}" -eq 124 ]; then
    status=0
fi

exit "${status}"

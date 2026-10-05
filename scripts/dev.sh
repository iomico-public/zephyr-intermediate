#!/bin/sh
# Run a command inside the Zephyr SDK container, with this project mounted at
# /opt/zephyr-ws/secure-boot-app. With no command, open a shell.
set -eu

PROJECT=$(cd "$(dirname "$0")/.." && pwd)
IMAGE="${IMAGE:-zephyr-sb:3.7.2}"

# Fail with the build command instead of letting docker try to pull the image.
if ! docker image inspect "${IMAGE}" >/dev/null 2>&1; then
    echo "error: docker image ${IMAGE} not found, build it with:" >&2
    echo "  docker build --build-arg UID=$(id -u) --build-arg GID=$(id -g) -t ${IMAGE} ${PROJECT}/docker" >&2
    exit 1
fi

mkdir -p "${PROJECT}/out"

# Interactive terminal only when run by hand, not from a script or a pipe.
if [ -t 0 ] && [ -t 1 ]; then
    TTY_FLAGS="-it"
else
    TTY_FLAGS=""
fi

# No command given -> open a shell.
if [ "$#" -eq 0 ]; then
    set -- /bin/bash
fi

exec docker run --rm ${TTY_FLAGS} \
    --env TIMEOUT \
    --volume "${PROJECT}:/opt/zephyr-ws/secure-boot-app" \
    --workdir /opt/zephyr-ws/secure-boot-app \
    "${IMAGE}" \
    "$@"

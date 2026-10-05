FROM ubuntu:22.04

ARG SDK_VERSION=0.16.9
ARG SDK_TOOLCHAIN=arm-zephyr-eabi
ARG UID=1000
ARG GID=1000

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      ccache \
      cmake \
      curl \
      device-tree-compiler \
      file \
      gcc \
      git \
      gperf \
      make \
      ninja-build \
      python3-dev \
      python3-pip \
      python3-venv \
      wget \
      xz-utils \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt
RUN base="https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${SDK_VERSION}" \
    && tarball="zephyr-sdk-${SDK_VERSION}_linux-x86_64_minimal.tar.xz" \
    && curl -fsSL -O "${base}/${tarball}" \
    && curl -fsSL -O "${base}/sha256.sum" \
    && grep "${tarball}" sha256.sum | sha256sum -c - \
    && tar xf "${tarball}" \
    && rm "${tarball}" sha256.sum \
    && cd "zephyr-sdk-${SDK_VERSION}" \
    && ./setup.sh -t "${SDK_TOOLCHAIN}" -h

ENV ZEPHYR_SDK_INSTALL_DIR=/opt/zephyr-sdk-${SDK_VERSION}
ENV ZEPHYR_TOOLCHAIN_VARIANT=zephyr

RUN python3 -m venv /opt/venv
ENV PATH=/opt/venv/bin:$PATH

COPY requirements/ /tmp/requirements/
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir \
        -r /tmp/requirements/requirements-base.txt \
        -r /tmp/requirements/requirements-build-test.txt \
        -r /tmp/requirements/requirements-run-test.txt \
        -r /tmp/requirements/mcuboot.txt \
        -r /tmp/requirements/tfm.txt \
    && rm -rf /tmp/requirements

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh \
    && groupadd -g ${GID} dev \
    && useradd -u ${UID} -g ${GID} -m -s /bin/bash dev

RUN mkdir /opt/zephyr-ws && chown dev:dev /opt/zephyr-ws

USER dev
COPY --chown=dev:dev west.yml /opt/zephyr-ws/manifest/west.yml
WORKDIR /opt/zephyr-ws
RUN west init -l manifest && west update --narrow -o=--depth=1
RUN git -C zephyr fetch --depth=1 zephyrproject-rtos tag v3.7.2

WORKDIR /opt/zephyr-ws/app

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/bin/bash"]

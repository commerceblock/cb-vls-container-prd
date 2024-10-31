# build stage for core lightning and its plugins
FROM --platform=${TARGETPLATFORM:-${BUILDPLATFORM:-linux/amd64}} alpine:3.18 as builder

ARG TARGETPLATFORM

WORKDIR /build

RUN apk update && \
    apk add \
      alpine-sdk \
      autoconf \
      automake \
      ca-certificates \
      cargo \
      gettext \
      git \
      gmp-dev \
      jq \
      libsodium \
      libtool \
      net-tools \
      postgresql-dev \
      py3-mako \
      py3-pip \
      python3 \
      python3-dev \
      sqlite-dev \
      sqlite-static \
      zlib-dev \
      zlib-static \
      linux-headers

RUN pip3 install grpcio-tools

ARG CORE_LIGHTNING_GIT_HASH \
    CORE_LIGHTNING_REPO
RUN git clone --recursive $CORE_LIGHTNING_REPO core-lightning
RUN cd core-lightning && \
    git checkout $CORE_LIGHTNING_GIT_HASH && \
    ./configure --enable-static --prefix=/usr && \
    make -j $(nproc) install && \
    make clean

ARG CLN_PLUGINS_GIT_HASH \
    CLN_PLUGINS_REPO
RUN git clone $CLN_PLUGINS_REPO
RUN cd plugins && \
    git checkout $CLN_PLUGINS_GIT_HASH && \
    git submodule update --init --recursive

# Build summars plugin
RUN cd plugins/summars && \
    cargo install --locked --path . --bin summars --profile release --root /usr/local/ && \
    cargo clean

FROM --platform=${TARGETPLATFORM:-${BUILDPLATFORM:-linux/amd64}} alpine:3.18 as clboss_builder

WORKDIR /build

RUN apk update && \
    apk add \
    git \
    autoconf-archive \
    automake \
    bind-tools \
    build-base \
    curl-dev \
    libev-dev \
    libtool \
    pkgconf \
    sqlite-dev

ARG CLBOSS_GIT_HASH \
    CLBOSS_REPO
RUN git clone --recurse-submodules $CLBOSS_REPO clboss
RUN cd clboss && \
    git checkout $CLBOSS_GIT_HASH && \
    autoreconf -i && \
    ./configure --prefix=/usr && \
    make -j $(nproc) && \
    make -j $(nproc) install && \
    make clean

FROM --platform=${TARGETPLATFORM:-${BUILDPLATFORM:-linux/amd64}} alpine:3.18 as vls_builder

WORKDIR /build

RUN apk update && \
    apk add \
    build-base \
    cargo \
    git \
    grpc \
    protobuf \
    protobuf-dev \
    rust

ARG VLS_GIT_HASH \
    VLS_REPO
RUN echo "building remote_hsmd_socket from hash: $VLS_GIT_HASH"
RUN git clone $VLS_REPO vls
RUN cd vls && \
    git checkout $VLS_GIT_HASH && \
    cargo install --locked --path ./vls-proxy --bin remote_hsmd_socket --profile release --root /usr/local/ && \
    cargo clean

# final stage with runtime dependencies and pkgs
FROM --platform=${TARGETPLATFORM:-${BUILDPLATFORM:-linux/amd64}} alpine:3.18 as runner

LABEL maintainer.0="Lakshya Singh (@king-11)" \
  maintainer.1="Dev Random (@devrandom01)"

RUN apk update && \
    apk add \
      python3 \
      py3-pip \
      postgresql \
      bitcoin-cli \
      pkgconf \
      build-base \
      bind-tools \
      libev-dev \
      curl-dev \
      sqlite-dev \
      tini \
      python3-dev \
      libffi-dev

ARG LIGHTNINGD_UID=101 \
    LIGHTNINGD_USER=lightning
ARG LIGHTNINGD_HOME=/home/${LIGHTNINGD_USER}
ENV LIGHTNINGD_DATA=${LIGHTNINGD_HOME}/.lightning \
    LIGHTNINGD_RPC_PORT=9835 \
    LIGHTNINGD_PORT=9735 \
    BITCOIND_HOME=/root/.bitcoin

RUN mkdir -p /usr/local/src/plugins

COPY --from=builder /usr/bin/lightningd /usr/bin/lightning-cli /usr/bin/lightning-hsmtool /usr/bin/
COPY --from=builder /usr/libexec/c-lightning /usr/libexec/c-lightning
COPY --from=builder /usr/share/man/man8 /usr/share/man/man8
COPY --from=builder /usr/share/doc/c-lightning /usr/share/doc/c-lightning
COPY --from=clboss_builder /usr/bin/clboss /usr/bin/clboss
COPY --from=builder /build/plugins/monitor/monitor.py /usr/local/src/plugins/monitor.py
COPY --from=builder /usr/local/bin/summars /usr/local/src/plugins/summars
COPY --from=vls_builder /usr/local/bin/remote_hsmd_socket /usr/libexec/c-lightning/remote_hsmd_socket
COPY --from=builder /build/core-lightning/plugins/clnrest/requirements.txt /usr/local/src/plugins/clnrest_requirements.txt

RUN addgroup -S ${LIGHTNINGD_USER} && adduser -S ${LIGHTNINGD_USER} -G ${LIGHTNINGD_USER} && \
    mkdir -p ${LIGHTNINGD_DATA} && \
    chown -R ${LIGHTNINGD_USER}:${LIGHTNINGD_USER} ${LIGHTNINGD_DATA}

COPY bitcoin.conf ${BITCOIND_HOME}/bitcoin.conf

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

COPY healthcheck.sh /healthcheck.sh
RUN chmod +x /healthcheck.sh

VOLUME ["${LIGHTNINGD_DATA}"]

RUN mkdir -p ${BITCOIND_HOME} && \
    chown -R ${LIGHTNINGD_USER}:${LIGHTNINGD_USER} ${BITCOIND_HOME}

COPY bitcoin.conf ${BITCOIND_HOME}/bitcoin.conf
COPY config /config
COPY testnet-config /testnet-config
COPY regtest-config /regtest-config

USER ${LIGHTNINGD_USER}

RUN pip3 install \
      pyln-client \
      requests \
      packaging

RUN pip3 install -r /usr/local/src/plugins/clnrest_requirements.txt

HEALTHCHECK --interval=5s --timeout=10s --start-period=5s \
    CMD ["/healthcheck.sh"]

ENTRYPOINT ["/sbin/tini", "--", "/entrypoint.sh"]
CMD ["lightningd"]

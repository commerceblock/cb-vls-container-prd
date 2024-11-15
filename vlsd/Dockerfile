FROM --platform=${TARGETPLATFORM:-${BUILDPLATFORM:-linux/amd64}} alpine:3.18 as builder

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
RUN echo "building vlsd from hash: $VLS_GIT_HASH"
RUN git clone $VLS_REPO vls
RUN cd vls && \
    git checkout $VLS_GIT_HASH && \
    cargo install --locked --path ./vls-proxy --bin vlsd2 --profile release --root /usr/local/ && \
    cargo install --locked --path ./vls-cli --profile release --root /usr/local/ && \
    cargo clean

FROM --platform=${TARGETPLATFORM:-${BUILDPLATFORM:-linux/amd64}} alpine:3.18 as runner

ARG VLSD_UID=100 \
    VLSD_GID=101 \
    VLSD_USER=vls
ARG VLSD_HOME=/home/${VLSD_USER}
ARG TXOO_PUBLIC_KEY
ENV TXOO_PUBLIC_KEY=${TXOO_PUBLIC_KEY}

LABEL maintainer.0="Lakshya Singh (@king-11)" \
  maintainer.1="Dev Random (@devrandom01)"

RUN addgroup ${VLSD_USER} --gid ${VLSD_GID} --system
RUN adduser --uid ${VLSD_UID} --system ${VLSD_USER} --ingroup ${VLSD_USER}

RUN apk update && \
  apk add \
  build-base \
  curl-dev \
  curl \
  protobuf \
  bind-tools \
  tini

COPY --from=builder /usr/local/bin/vlsd2 /usr/local/bin/vlsd2
COPY --from=builder /usr/local/bin/vls-cli /usr/local/bin/vls-cli

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

COPY healthcheck.sh /healthcheck.sh
RUN chmod +x /healthcheck.sh

COPY vlsd2.toml /vlsd2.toml
COPY node.seed /node.seed

ENV VLSD_DATA=/home/vls/.lightning-signer
RUN mkdir -p ${VLSD_DATA} && \
    chown ${VLSD_USER}:${VLSD_USER} ${VLSD_DATA}

RUN mkdir -p ${VLSD_HOME}/.txoo

ENV REMOTE_SIGNER_ALLOWLIST=${VLSD_DATA}/ALLOWLIST
RUN touch ${REMOTE_SIGNER_ALLOWLIST}

VOLUME ["${VLSD_DATA}"]

USER ${VLSD_USER}

HEALTHCHECK --interval=10s --timeout=10s --start-period=10s \
    CMD ["/healthcheck.sh"]

ENTRYPOINT ["/sbin/tini", "--", "/entrypoint.sh"]

RUN vlsd2 --git-desc

CMD ["vlsd2"]
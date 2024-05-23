FROM curlimages/curl:7.83.1 AS downloader

ARG TARGETOS
ARG TARGETARCH
ARG KUBECTL_VERSION
ARG KUSTOMIZE_VERSION
ARG HELM_VERSION
ARG JSONNET_VERSION

WORKDIR /downloads

RUN set -ex; \
    curl -fL https://storage.googleapis.com/kubernetes-release/release/v${KUBECTL_VERSION}/bin/${TARGETOS}/${TARGETARCH}/kubectl -o kubectl && \
    chmod +x kubectl

RUN set -ex; \
    curl -fL https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize/v${KUSTOMIZE_VERSION}/kustomize_v${KUSTOMIZE_VERSION}_${TARGETOS}_${TARGETARCH}.tar.gz | tar xz && \
    chmod +x kustomize

RUN set -ex; \
    curl -fL https://get.helm.sh/helm-v${HELM_VERSION}-${TARGETOS}-${TARGETARCH}.tar.gz | tar xz && \
    mv ${TARGETOS}-${TARGETARCH}/helm helm && \
    chmod +x helm

RUN set -ex; \
    if [ "$TARGETARCH" = "amd64" ]; then TARGETARCH="x86_64"; fi && \
    TARGETOS=$(echo $TARGETOS | awk '{print toupper(substr($0,1,1))substr($0,2)}'); \
    curl -fL https://github.com/google/go-jsonnet/releases/download/v${JSONNET_VERSION}/go-jsonnet_${JSONNET_VERSION}_${TARGETOS}_${TARGETARCH}.tar.gz | tar xz && \
    chmod +x jsonnet && \
    chmod +x jsonnetfmt && \
    chmod +x jsonnet-lint && \
    chmod +x jsonnet-deps

FROM golang:1.22.3-alpine3.19 AS builder

RUN set -ex; \
    go install github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb@latest && \
    go install github.com/brancz/gojsontoyaml@latest

# Runtime
FROM alpine:3.19.0 AS runtime

LABEL maintainer="Alexander Puzynia <werwolf.by@gmail.com>"

COPY --from=downloader /downloads/kubectl /usr/local/bin/kubectl
COPY --from=downloader /downloads/kustomize /usr/local/bin/kustomize
COPY --from=downloader /downloads/helm /usr/local/bin/helm
COPY --from=downloader /downloads/jsonnet /usr/local/bin/jsonnet
COPY --from=downloader /downloads/jsonnetfmt /usr/local/bin/jsonnetfmt
COPY --from=downloader /downloads/jsonnet-lint /usr/local/bin/jsonnet-lint
COPY --from=downloader /downloads/jsonnet-deps /usr/local/bin/jsonnet-deps
COPY --from=builder /go/bin/jb /usr/local/bin/jb
COPY --from=builder /go/bin/gojsontoyaml /usr/local/bin/gojsontoyaml

RUN set -ex; \
    apk add --no-cache bash ca-certificates git openssh-client

# Test
FROM runtime AS test

RUN set -ex; kubectl && kustomize && helm && bash --version && git --version && ssh -V && jsonnet --version && jsonnetfmt --version && jsonnet-lint --version && jsonnet-deps --version && jb --version && gojsontoyaml --help
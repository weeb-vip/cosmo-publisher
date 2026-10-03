# cosmo-publisher: everything the schema-publish hook needs, preinstalled.
#
# The hook used to `npm install -g wgc` on every run, which was slow, needed
# registry access from inside the cluster, and floated to whatever wgc was
# latest. That broke on 2026-10-03 when wgc 0.131.2 started sending a 120s
# RPC timeout that our control plane (0.133.1) rejects:
#   ConnectError: [invalid_argument] timeout 120000ms must be <= 80000
# Pin wgc here; bump WGC_VERSION only together with cosmo-controlplane.
FROM node:22-alpine

ARG WGC_VERSION=0.131.1
# Set by semantic-release at build time; purely informational.
ARG VERSION=dev
LABEL org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.source="https://github.com/weeb-vip/cosmo-publisher"

RUN apk add --no-cache curl jq \
    && npm install -g "wgc@${WGC_VERSION}" \
    && npm cache clean --force

COPY publish-subgraph.sh /usr/local/bin/publish-subgraph
RUN chmod +x /usr/local/bin/publish-subgraph

USER node
ENTRYPOINT ["publish-subgraph"]

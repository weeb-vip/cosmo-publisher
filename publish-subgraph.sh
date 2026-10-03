#!/bin/sh
# Fetch a subgraph's SDL by introspection and publish it to Cosmo.
#
# Required:  SUBGRAPH_NAME   name of the subgraph in Cosmo
#            SERVICE_URL     GraphQL endpoint to introspect (`_service { sdl }`)
#            COSMO_API_URL, COSMO_API_KEY   read by wgc itself
# Optional:  ROUTING_URL     URL the router calls (default: SERVICE_URL)
#            COSMO_NAMESPACE Cosmo namespace (default: default)
#            LABELS          space-separated key=value labels
set -eu

: "${SUBGRAPH_NAME:?SUBGRAPH_NAME is required}"
: "${SERVICE_URL:?SERVICE_URL is required}"
: "${COSMO_API_URL:?COSMO_API_URL is required}"
: "${COSMO_API_KEY:?COSMO_API_KEY is required}"
ROUTING_URL="${ROUTING_URL:-$SERVICE_URL}"
COSMO_NAMESPACE="${COSMO_NAMESPACE:-default}"
LABELS="${LABELS:-}"
SCHEMA="${SCHEMA_PATH:-/tmp/schema.graphql}"

echo "fetching SDL for $SUBGRAPH_NAME from $SERVICE_URL"
curl -sf --retry 5 --retry-delay 5 --retry-all-errors -X POST "$SERVICE_URL" \
  -H "Content-Type: application/json" \
  -H "x-is-signature-valid: true" \
  -d '{"query":"query { _service { sdl } }"}' \
  | jq -er '.data._service.sdl' > "$SCHEMA"

# An empty SDL composes into a subgraph with no types and breaks the supergraph
# for every service, not just this one. Fail here instead.
if [ ! -s "$SCHEMA" ]; then
  echo "introspection returned an empty SDL; refusing to publish" >&2
  exit 1
fi

set --
for label in $LABELS; do
  set -- "$@" --label "$label"
done

echo "publishing $SUBGRAPH_NAME (namespace $COSMO_NAMESPACE, labels: ${LABELS:-none})"
wgc subgraph publish "$SUBGRAPH_NAME" \
  --namespace "$COSMO_NAMESPACE" \
  --routing-url "$ROUTING_URL" \
  --schema "$SCHEMA" \
  "$@"

# Labels are not decoration: a federated graph selects its subgraphs by label
# matcher, so a subgraph without them belongs to no graph and never composes.
# `publish` only applies labels when it creates the subgraph, so reassert them
# on every run; `update` is idempotent and cheap.
if [ -n "$LABELS" ]; then
  wgc subgraph update "$SUBGRAPH_NAME" --namespace "$COSMO_NAMESPACE" "$@" \
    || echo "label reassert failed; subgraph may not be in a federated graph" >&2
fi

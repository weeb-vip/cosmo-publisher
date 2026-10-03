# cosmo-publisher

The image behind the `publish-schema` PostSync hook in weeb-argocd's `graphql`
and `graphql-staging` charts. It ships `curl`, `jq` and a **pinned `wgc`**, plus
the `publish-subgraph` entrypoint that introspects a subgraph and publishes it to
Cosmo, so the hook has nothing to install at sync time.

## Entrypoint

`publish-subgraph` is driven by environment variables:

| Variable | Required | Meaning |
| --- | --- | --- |
| `SUBGRAPH_NAME` | yes | Subgraph name in Cosmo |
| `SERVICE_URL` | yes | GraphQL endpoint to introspect (`_service { sdl }`) |
| `COSMO_API_URL`, `COSMO_API_KEY` | yes | Read by `wgc` itself |
| `ROUTING_URL` | no | URL the router calls; defaults to `SERVICE_URL` |
| `COSMO_NAMESPACE` | no | Cosmo namespace; defaults to `default` |
| `LABELS` | no | Space-separated `key=value` labels, reasserted on every run |

It refuses an empty SDL (which would compose into an empty subgraph and break
the whole supergraph) and reasserts labels with `wgc subgraph update`, because
`publish` only applies labels when it creates the subgraph.

## Releasing

1. Bump `VERSION` (and `WGC_VERSION` in the Dockerfile if `wgc` changes).
2. Merge to `main`; CI pushes `harbor.floret.dev/weeb-vip/cosmo-publisher:<VERSION>`.
3. Bump `publishSchema.image.tag` in weeb-argocd `graphql/values.yaml` and
   `graphql-staging/values.yaml`.

`wgc` is pinned on purpose: newer releases can be incompatible with the deployed
`cosmo-controlplane` (0.131.2+ sends a 120s RPC timeout that controlplane 0.133.1
rejects). Upgrade the two together.

## Local build

```sh
docker build --platform linux/amd64 -t harbor.floret.dev/weeb-vip/cosmo-publisher:$(cat VERSION) .
docker run --rm --entrypoint wgc harbor.floret.dev/weeb-vip/cosmo-publisher:$(cat VERSION) --version
```

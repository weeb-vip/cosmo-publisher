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

Releases are cut by semantic-release on every push to `main`, from the PR
titles (the PR title check enforces conventional commits):

- `fix:` → patch, `feat:` → minor, `BREAKING CHANGE` footer → major.
- CI builds the image, pushes `harbor.floret.dev/weeb-vip/cosmo-publisher:<version>`
  and `:latest`, creates the GitHub release, and bumps every
  `tag: X # cosmo-publisher` line in weeb-argocd so the hooks pick it up on
  the next sync.

`wgc` is pinned on purpose: newer releases can be incompatible with the deployed
`cosmo-controlplane` (0.131.2+ sends a 120s RPC timeout that controlplane 0.133.1
rejects). Upgrade the two together, and make that PR a `feat:`.

## Local build

```sh
docker build -t cosmo-publisher:dev .
docker run --rm --entrypoint wgc cosmo-publisher:dev --version
```

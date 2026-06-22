# Flux Configuration
This folder should ideally be separated into its own repository housing the Flux configuration for all clusters or split out into multiple repositories for different teams.

## Layout
```
k8s/
├── apps/
│   └── <cluster>
│       ├── <app>/
│       └── kustomization.yaml
├── clusters/
│   └── <cluster>
│       ├── flux-system/
│       ├── apps.yaml
│       └── kustomization.yaml
└── infrastructure/
        └── kustomization.yaml
```

## Clusters
`clusters/<cluster>` is the main entrypoint for cluster management. It will read in `infrastructure` and all app configurations from `apps/<cluster>`.
> **Bootstrapping**
>
> `clusters/<cluster>` will be bootstrapped with the cluster-specific configuration by Flux after cluster creation. This will add the `flux-system` namespace and Flux components to the cluster.

## Infrastructure
`infrastructure` should add general infrastructure configuration such as networking, monitoring, and logging.

## Apps
`apps/<cluster>` should add cluster-specific applications and configurations. `uptest` is included by default to provide a way of testing the cluster configuration but can be removed if not needed.

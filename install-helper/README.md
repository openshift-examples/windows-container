# Windows container dev preview installation helper [![Docker Repository on Quay](https://quay.io/repository/openshift-examples/windows-container-install-helper/status "Docker Repository on Quay")](https://quay.io/repository/openshift-examples/windows-container-install-helper)

## Build

```bash
podman build -t quay.io/openshift-examples/windows-container-install-helper:latest .
```

## Push

```bash
podman push quay.io/openshift-examples/windows-container-install-helper:latest
```

## Run

```bash
podman run -ti -v ~/.aws/:/root/.aws:z -v $(pwd)/:/work:z quay.io/openshift-examples/windows-container-install-helper:latest
```
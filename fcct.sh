podman run --interactive -v .:/data:z --rm quay.io/coreos/butane:release -d /data  --pretty --strict < router.bu > router.ign
podman run --interactive -v .:/data:z --rm quay.io/coreos/butane:release -d /data  --pretty --strict < config.bu > config.ign

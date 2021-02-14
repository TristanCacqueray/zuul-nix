# zuul-nix

Nix package for zuul

## Overview and scope

Using nix to setup Zuul enables:

- Full control over the requirements, from the libc to the python interpreter
- Reproducable build
- Integration test vm

## Usage

Build vm:

```
nix-build vm.nix -A vm --arg configuration ./configuration.nix
```

Run vm:

```
QEMU_OPTS=-nographic QEMU_NET_OPTS=hostfwd=tcp::2221-:22 ./result/bin/run-vm1-vm
```

Ssh vm:

```
ssh root@localhost -p 2221 -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no
```


Build container:

```
nix-build ./container.nix
podman load -i ./result
```

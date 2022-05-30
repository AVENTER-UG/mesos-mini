# Mesos Mini

This repository will build a mesos-mini docker image to run Apache Mesos for development on a local system.

## How to use

To use the container, use the following command (works on both Mac and Linux, does work under windows only with a systemd workaround)

```bash
docker run --rm --name mesos --privileged=true -p 5050:5050 -p 5051:5051 -it avhost/mesos-mini:1.11.x /lib/systemd/systemd
```

or

```bash
docker run  --rm --name mesos --privileged=true --net host -it avhost/mesos-mini:1.11.x /lib/systemd/systemd
```

These mesos-mini have a configured docker overlay network called "mini" with the subnet "10.32.0.0/24".

```bash
docker exec -it mesos /bin/bash
```


```bash
docker network ls

NETWORK ID          NAME                DRIVER              SCOPE
f900fd5ccfa5        bridge              bridge              local
b1d30e4614a0        host                host                local
1a38cad453a3        mini                bridge              local
d2beaa9f939b        none                null                local
```

The Mesos master can be reached at 127.0.0.1:5050.


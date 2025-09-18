FROM ubuntu:noble

LABEL maintainer="Andreas Peters <support@aventer.biz>"
LABEL org.opencontainers.image.title="mesos-mini" 
LABEL org.opencontainers.image.description="A mini instance of Apache Mesos/ClusterD"
LABEL org.opencontainers.image.vendor="AVENTER UG (haftungsbeschränkt)"
LABEL org.opencontainers.image.source="https://github.com/AVENTER-UG/mesos-mini"

RUN apt update && apt install -y iptables iproute2 systemd wget curl procps openjdk-11-jre
RUN update-alternatives --set iptables /usr/sbin/iptables-legacy

# Prepare systemd environment.
ENV container=docker

RUN (cd /lib/systemd/system/sysinit.target.wants/; for i in *; do [ $i == systemd-tmpfiles-setup.service ] || rm -f $i; done); \
    rm -f /lib/systemd/system/multi-user.target.wants/*; \
    rm -f /etc/systemd/system/*.wants/*; \
    rm -f /lib/systemd/system/local-fs.target.wants/*; \
    rm -f /lib/systemd/system/sockets.target.wants/*udev*; \
    rm -f /lib/systemd/system/sockets.target.wants/*initctl*; \
    rm -f /lib/systemd/system/basic.target.wants/*; \
    rm -f /lib/systemd/system/anaconda.target.wants/*; \
    rm -rf /lib/systemd/system/default.target; \
    ln -sf /lib/systemd/system/multi-user.target /lib/systemd/system/default.target

RUN for service in\
    console-getty.service\
    dbus.service\
    dbus.socket\
    dev-hugepages.mount\
    getty.target\
    sys-fs-fuse-connections.mount\
    systemd-logind.service\
    systemd-remount-fs.service\
    systemd-vconsole-setup.service\
    ; do systemctl mask $service; done

# Prepare Docker environment.
ARG DOCKER_URL=https://download.docker.com/linux/static/stable/${MARCH}/docker-20.10.15.tgz

RUN export ARCH=`dpkg --print-architecture` && \
    export MARCH=`uname -m` && \
    echo $ARCH && \
    echo $MARCH && \
    wget -O /mesos.deb http://rpm.aventer.biz/Ubuntu/noble/pool/main/a/aventer-mesos/aventer-mesos_1.11.0-0.7.1.ubuntu2404_${ARCH}.deb && \
    wget -O /zookeeper.deb http://rpm.aventer.biz/Ubuntu/noble/pool/main/z/zookeeper/zookeeper_3.9.4-0.1_${ARCH}.deb && \
    wget -O /docker.tgz https://download.docker.com/linux/static/stable/${MARCH}/docker-20.10.15.tgz && \
    wget -O /cni.tgz https://github.com/containernetworking/plugins/releases/download/v1.1.1/cni-plugins-linux-${ARCH}-v1.1.1.tgz && \
    apt install -y /mesos.deb /zookeeper.deb && \
    rm /mesos.deb /zookeeper.deb


RUN mkdir -p /etc/docker && \
    touch /etc/docker/env && \
    tar -xzvf /docker.tgz -C /usr/local/bin --strip 1 && \
    rm -rf /docker.tgz && \
    groupadd docker

COPY docker.service /usr/lib/systemd/system/docker.service
#COPY docker_env.sh /etc/docker/env.sh
COPY docker_daemon.json /etc/docker/daemon.json
COPY docker-network.sh /usr/bin/docker-network.sh
COPY docker-network.service /etc/systemd/system/docker-network.service
#COPY weave.service /etc/systemd/system/weave.service

# Prepare Mesos environment.
RUN chmod +x /usr/bin/mesos-init-wrapper && \
    rm -f /etc/mesos-master/work_dir && \
    rm -rf /etc/mesos-agent* && \
    mkdir -p /etc/mesos/resource_providers && \
    mkdir -p /etc/mesos/cni && \
    mkdir -p /usr/libexec/mesos/cni && \
    mkdir -p /etc/cni/conf.d/ && \
    mkdir -p /opt/cni/bin && \
    echo "zk://localhost:2181/mesos" > /etc/mesos/zk && \
    echo "server.0=localhost:2888:3888" >> /etc/zookeeper/conf/zoo.cfg && \
    echo "admin.enableServer=false" >> /etc/zookeeper/conf/zoo.cfg

COPY mesos/master_environment /etc/default/mesos-master
COPY mesos/agent_environment /etc/default/mesos-agent
COPY mesos/modules /etc/mesos/modules

RUN tar -xvf /cni.tgz --directory /opt/cni/bin/ && \
    rm /cni.tgz

COPY mesos/ucr-default-bridge.json /etc/mesos/cni/

RUN curl -L https://raw.githubusercontent.com/AVENTER-UG/weave/refs/heads/master/weave -o /usr/local/bin/weave
RUN chmod a+x /usr/local/bin/weave
COPY weave.service /usr/lib/systemd/system/weave.service


RUN systemctl enable docker zookeeper mesos-agent mesos-master docker-network 
RUN apt update && apt install -y libunwind8

# Prepare entrypoint.
COPY entrypoint.sh /

CMD ["/entrypoint.sh"]

STOPSIGNAL SIGRTMIN+3

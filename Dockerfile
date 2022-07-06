FROM debian:11

RUN apt update && apt install -y iptables iproute2 systemd wget curl procps containernetworking-plugins
RUN update-alternatives --set iptables /usr/sbin/iptables-legacy

# Prepare systemd environment.
ENV container docker

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
ARG DOCKER_URL=https://download.docker.com/linux/static/stable/x86_64/docker-20.10.15.tgz
#ARG MESOS_URL=http://rpm.aventer.biz/AlmaLinux/8/x86_64/mesos-1.11.1-0.1.el8.x86_64.rpm

#RUN curl -s $MESOS_URL -o /mesos.rpm && \
RUN wget -O /mesos.deb http://rpm.aventer.biz/Debian/pool/main/a/aventer-mesos/aventer-mesos_1.11.0-0.2.0.debian11_amd64.deb
RUN wget -O /zookeeper.deb http://rpm.aventer.biz/Debian/pool/main/z/zookeeper/zookeeper_3.8.0-0.1_amd64.deb
RUN apt install -y /mesos.deb /zookeeper.deb

RUN mkdir -p /etc/docker && \
    touch /etc/docker/env && \
    curl -s $DOCKER_URL -o /docker.tgz && \
    tar -xzvf /docker.tgz -C /usr/local/bin --strip 1 && \
    rm -f /docker.tgz

RUN groupadd docker

COPY docker.service /usr/lib/systemd/system/docker.service
#COPY docker_env.sh /etc/docker/env.sh
COPY docker_daemon.json /etc/docker/daemon.json
COPY docker-network.sh /usr/bin/docker-network.sh
COPY docker-network.service /etc/systemd/system/docker-network.service
#COPY weave.service /etc/systemd/system/weave.service

# Prepare Mesos environment.
RUN chmod +x /usr/bin/mesos-init-wrapper && \
    rm -f /etc/mesos-master/work_dir && \
    rm -rf /etc/mesos-slave* && \
    mkdir -p /etc/mesos/resource_providers && \
    mkdir -p /etc/mesos/cni && \
    mkdir -p /usr/libexec/mesos/cni && \
    echo "zk://localhost:2181/mesos" > /etc/mesos/zk && \
    echo "server.0=localhost:2888:3888" >> /etc/zookeeper/conf/zoo.cfg && \
    echo "admin.enableServer=false" >> /etc/zookeeper/conf/zoo.cfg

COPY mesos/master_environment /etc/default/mesos-master
COPY mesos/agent_environment /etc/default/mesos-agent
COPY mesos/modules /etc/mesos/modules


COPY mesos/ucr-default-bridge.json /etc/mesos/cni/

RUN curl -L git.io/weave -o /usr/local/bin/weave
RUN chmod a+x /usr/local/bin/weave
COPY weave.service /usr/lib/systemd/system/weave.service

RUN systemctl enable docker zookeeper mesos-slave mesos-master docker-network 

# Prepare entrypoint.
COPY entrypoint.sh /

CMD ["/entrypoint.sh"]

STOPSIGNAL SIGRTMIN+3

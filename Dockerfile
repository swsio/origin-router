ARG OKD_VER=v3.11.0
ARG HAPROXY_RPM_VER=2.0.14
ARG HAPROXY_RPM_RELEASE=1
ARG HAPROXY_PATCH_VER=2.0.14

FROM centos:7 AS RPM

ARG HAPROXY_RPM_VER
ARG HAPROXY_RPM_RELEASE
ARG HAPROXY_PATCH_VER

RUN curl -sfLJO https://ftp.redhat.com/redhat/linux/enterprise/7Server/en/RHOSE/SRPMS/haproxy-${HAPROXY_RPM_VER}-${HAPROXY_RPM_RELEASE}.el7.src.rpm

RUN yum groupinstall -y 'Development Tools'
RUN yum install -y epel-release
RUN yum install -y rpm-build rpmdevtools openssl11-devel
RUN yum-builddep -y haproxy-*.el7.src.rpm
RUN rpm -i haproxy-*.el7.src.rpm

WORKDIR /root/rpmbuild/SPECS

# FOR haproxy 2.0 testing only
RUN sed -i "s/${HAPROXY_RPM_VER}/${HAPROXY_PATCH_VER}/g" haproxy.spec
RUN sed -i 's/1.8\/src/2.0\/src/' haproxy.spec
RUN sed -i "s/${HAPROXY_RPM_RELEASE}%{?dist}/1%{?dist}/" haproxy.spec
RUN sed -i 's/linux2628/linux-glibc/' haproxy.spec
RUN sed -i '/Patch0/d' haproxy.spec
RUN sed -i '/patch0/d' haproxy.spec

# OpenSSL
RUN sed -i 's/USE_OPENSSL=1/USE_OPENSSL=1 SSL_INC=\/usr\/include\/openssl11\/ SSL_LIB=\/usr\/lib64\/openssl11\//' haproxy.spec

RUN spectool -g -R haproxy.spec

RUN rpmbuild -ba haproxy.spec

FROM openshift/origin-haproxy-router:${OKD_VER} AS PATCH

USER 0

RUN yum install -y patch
COPY patches/*.patch /tmp/

RUN for patch in /tmp/*.patch; do echo $patch; patch -u -l -f /var/lib/haproxy/conf/haproxy-config.template "${patch}"; done

FROM openshift/origin-haproxy-router:${OKD_VER}

COPY --from=RPM /root/rpmbuild/RPMS/x86_64/haproxy*.rpm /tmp/

USER 0

RUN yum update -y \
    && yum install -y epel-release && yum install -y openssl11-libs \
    && yum localinstall -y /tmp/haproxy*.rpm && rm -f tmp/haproxy*.rpm \
    && setcap 'cap_net_bind_service=ep' /usr/sbin/haproxy

COPY --from=PATCH /var/lib/haproxy/conf/haproxy-config.template /var/lib/haproxy/conf/haproxy-config-agileio.template

USER 1001

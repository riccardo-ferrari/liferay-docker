FROM azul/zulu-openjdk:8u212

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        p7zip-full \
        unzip \
        curl \
        nano \
        git \
        python \
        ant \
	vpnc \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ENV WORKSPACE_DIR=/opt/workspace
ENV CACHE_DIR=/opt/cache
ENV P7Z_OPTS='-md1024m'
ENV GRADLE_CMD="./gradlew"
ENV GRADLE_OPTS_CUSTOM="--parallel"
ENV GRADLE_TASKS="clean deploy"
ENV VPNC_GATEWAY=vpn-1.lax.liferay.com
ENV VPNC_ID=group-employee
ENV VPNC_SECRET=r3m3mb3r

RUN mkdir -p  /usr/lib/jvm/java//bin/ && \
	ln -s `which java` /usr/lib/jvm/java//bin/java

VOLUME /opt/workspace
VOLUME /opt/cache

ADD *.sh /usr/local/bin/

ENTRYPOINT ["/bin/bash"]

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
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ENV WORKSPACE_DIR=/opt/workspace
ENV CACHE_DIR=/opt/cache
ENV P7Z_OPTS='-md1024m'
ENV GRADLE_CMD="./gradlew"
ENV GRADLE_OPTS_CUSTOM="--parallel"
ENV GRADLE_TASKS="deploy"

VOLUME /opt/workspace
VOLUME /opt/cache

ADD *.sh /usr/local/bin/

ENTRYPOINT ["/bin/bash"]
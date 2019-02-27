FROM alpine:3.8
MAINTAINER Frank Celler <info@arangodb.com>

ENV ARANGO_VERSION 3.4.3
ENV ARANGO_URL https://download.arangodb.com/arangodb34/DEBIAN/amd64
ENV ARANGO_PACKAGE arangodb3-client_${ARANGO_VERSION}-1_amd64.deb
ENV ARANGO_PACKAGE_URL ${ARANGO_URL}/${ARANGO_PACKAGE}
ENV ARANGO_SIGNATURE_URL ${ARANGO_PACKAGE_URL}.asc

RUN apk add --no-cache gnupg pwgen nodejs npm binutils && \
    npm install -g foxx-cli && \
    rm -rf /root/.npm

RUN gpg --batch --keyserver hkps://hkps.pool.sks-keyservers.net --recv-keys CD8CB0F1E0AD5B52E93F41E7EA93F5E56E751E9B

# see
#   https://docs.arangodb.com/latest/Manual/Administration/Configuration/Endpoint.html
#   https://docs.arangodb.com/latest/Manual/Administration/Configuration/Logging.html

RUN cd /tmp                                && \
    wget ${ARANGO_SIGNATURE_URL}           && \
    wget ${ARANGO_PACKAGE_URL}             && \
    gpg --verify ${ARANGO_PACKAGE}.asc     && \
    ar x ${ARANGO_PACKAGE} data.tar.gz     && \
    tar -C / -x -z -f data.tar.gz          && \
    rm -f ${ARANGO_PACKAGE}* data.tar.gz

VOLUME ["/backup"]

COPY scripts/backup.sh /backup.sh

ENTRYPOINT ["/backup.sh"]

CMD ["help"]

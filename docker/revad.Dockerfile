FROM ubuntu:22.04

# keys for oci taken from:
# https://github.com/opencontainers/image-spec/blob/main/annotations.md#pre-defined-annotation-keys
LABEL org.opencontainers.image.licenses=MIT
LABEL org.opencontainers.image.title="Pondersource Revad Image"
LABEL org.opencontainers.image.source="https://github.com/pondersource/dev-stock"
LABEL org.opencontainers.image.authors="Mohammad Mahdi Baghbani Pourvahid"

# set timezone.
ENV TZ=UTC
RUN ln --symbolic --no-dereference --force /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

ENV DEBIAN_FRONTEND noninteractive

RUN apt update --yes

# install dependencies.
RUN apt install --yes               \
    git                             \
    vim                             \
    curl                            \
    wget                            \
    openssl                         \ 
    build-essential                 \
    ca-certificates                  

# install Go compiler.
ARG GO_VERSION=20.4
RUN wget https://go.dev/dl/go1.${GO_VERSION}.linux-amd64.tar.gz
RUN tar --directory=/usr/local --extract --gzip --file=go1.${GO_VERSION}.linux-amd64.tar.gz

# update path to include GO bin directory.
ENV PATH="${PATH}:/usr/local/go/bin"

# fetch revad from source.
ARG REPO_REVA=https://github.com/cs3org/reva
ARG BRANCH_REVA=sciencemesh-dev
# CACHEBUST forces docker to clone fresh source codes from git.
# example: docker build -t your-image --build-arg CACHEBUST="$(date +%s)" .
# $RANDOM returns random number each time.
ARG CACHEBUST="$(echo $RANDOM)"
RUN git clone                   \
    --depth 1                   \
    --branch ${BRANCH_REVA}     \
    ${REPO_REVA}                \
    reva

WORKDIR /reva

# build revad from source.
RUN go mod vendor
SHELL ["/bin/bash", "-c"]
# only build reva and revad, leave out test and lint and docs.
RUN make revad reva

COPY ./revad /etc/revad
WORKDIR /etc/revad

# Trust all the certificates:
COPY ./tls /tls
RUN ln --symbolic --force /tls/*.crt /usr/local/share/ca-certificates
RUN update-ca-certificates

# create link for all the tls certificates in the revad tls directory.
RUN mkdir --parents /etc/revad/tls
RUN ln --symbolic --force /tls/*.crt /etc/revad/tls
RUN ln --symbolic --force /tls/*.key /etc/revad/tls

RUN mkdir --parents /var/tmp/reva/

# see https://github.com/golang/go/issues/22846#issuecomment-380809416
RUN echo "hosts: files dns" > /etc/nsswitch.conf
CMD echo "127.0.0.1 $HOST.docker" >> /etc/hosts && /reva/cmd/revad/revad -c /etc/revad/$HOST.toml

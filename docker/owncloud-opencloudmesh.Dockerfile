FROM pondersource/dev-stock-php-base

# keys for oci taken from:
# https://github.com/opencontainers/image-spec/blob/main/annotations.md#pre-defined-annotation-keys
LABEL org.opencontainers.image.licenses=MIT
LABEL org.opencontainers.image.title="Pondersource ownCloud OpenCloudMesh Image"
LABEL org.opencontainers.image.source="https://github.com/pondersource/dev-stock"
LABEL org.opencontainers.image.authors="Mohammad Mahdi Baghbani Pourvahid"

RUN rm --recursive --force /var/www/html
USER www-data

ARG REPO_OWNCLOUD=https://github.com/pondersource/core.git
ARG BRANCH_OWNCLOUD=accept-ocm-to-groups
# CACHEBUST forces docker to clone fresh source codes from git.
# example: docker build -t your-image --build-arg CACHEBUST="$(date +%s)" .
# $RANDOM returns random number each time.
ARG CACHEBUST="$(echo $RANDOM)"
RUN git clone                       \
    --depth 1                       \
    --recursive                     \
    --shallow-submodules            \
    --branch ${BRANCH_OWNCLOUD}     \
    ${REPO_OWNCLOUD}                \
    html

USER root
WORKDIR /var/www/html

# switch php version for ownCloud.
RUN switch-php.sh 7.4

RUN curl --silent --show-error https://getcomposer.org/installer -o /root/composer-setup.php
RUN php /root/composer-setup.php --install-dir=/usr/local/bin --filename=composer

# install nodejs and yarn.
RUN curl --silent --location https://deb.nodesource.com/setup_18.x | bash -
RUN apt install nodejs
RUN npm install --global yarn

USER www-data

RUN composer install --no-dev
RUN make install-nodejs-deps

ENV PHP_MEMORY_LIMIT="512M"

USER www-data
# this file can be overrided in docker run or docker compose.yaml. 
# example: docker run --volume new-init.sh:/init.sh:ro
COPY ./scripts/init-owncloud.sh /oc-init.sh
RUN mkdir --parents data ; touch data/owncloud.log

ARG REPO_CUSTOM_GROUPS=https://github.com/owncloud/customgroups
ARG BRANCH_CUSTOM_GROUPS=master

ARG REPO_OCM=https://github.com/pondersource/oc-opencloudmesh
ARG BRANCH_OCM=main
# CACHEBUST forces docker to clone fresh source codes from git.
# example: docker build -t your-image --build-arg CACHEBUST="$(date +%s)" .
# $RANDOM returns random number each time.
ARG CACHEBUST="$(echo $RANDOM)"
RUN git clone                           \
    --depth 1                           \
    --branch ${BRANCH_CUSTOM_GROUPS}    \
    ${REPO_CUSTOM_GROUPS}               \
    apps/customgroups

RUN cd apps/customgroups &&             \
    composer install --no-dev &&        \
    yarn install &&                     \
    yarn build  

RUN git clone                           \
    --depth 1                           \
    --branch ${BRANCH_OCM}              \
    ${REPO_OCM}                         \
    apps/oc-opencloudmesh

RUN cd apps && ln --symbolic oc-opencloudmesh/opencloudmesh

# this file can be overrided in docker run or docker compose.yaml. 
# example: docker run --volume new-init.sh:/init.sh:ro
COPY ./scripts/init-owncloud-opencloudmesh.sh /init.sh

USER root
CMD /usr/sbin/apache2ctl -DFOREGROUND & tail --follow /var/log/apache2/access.log & tail --follow /var/log/apache2/error.log & tail --follow data/owncloud.log
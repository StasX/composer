# Composer runs as a CLI command; there is no persistent service to health-check.
# trivy:ignore:AVD-DS-0026
FROM php:8.5-cli-alpine3.24
RUN apk upgrade --no-cache
COPY . /
RUN sh prepare-php.sh
RUN addgroup -S -g 1000 composer \
    && adduser -S -D -u 1000 -G composer -h /home/composer composer \
    && chown -R composer:composer /backend
ENV HOME=/backend
WORKDIR /backend
USER composer

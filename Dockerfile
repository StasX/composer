FROM php:8.5-cli-alpine3.24
RUN apk upgrade --no-cache
COPY . .
RUN sh prepare-php.sh

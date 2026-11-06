#!/bin/sh
set -eu

# Use the same PHP minor version as the application image.
php -r 'exit(PHP_MAJOR_VERSION === 8 && PHP_MINOR_VERSION === 5 ? 0 : 1);'
apk add --no-cache bash curl git unzip
apk add --no-cache --virtual .ci-build-deps $PHPIZE_DEPS libxml2-dev oniguruma-dev
extensions=''
for extension in pdo_mysql mbstring dom xml xmlwriter; do
    if ! php -r "exit(extension_loaded('$extension') ? 0 : 1);"; then
        extensions="$extensions $extension"
    fi
done
if [ -n "$extensions" ]; then
    docker-php-ext-install $extensions
fi
pecl install pcov
docker-php-ext-enable pcov
# Keep libraries needed by any compiled extensions after removing build tools.
apk add --no-cache libxml2 oniguruma
apk del .ci-build-deps
printf 'memory_limit=512M\n' > "$PHP_INI_DIR/conf.d/ci.ini"

expected_signature="$(curl -fsSL https://composer.github.io/installer.sig)"
curl -fsSL https://getcomposer.org/installer -o /tmp/composer-setup.php
actual_signature="$(php -r "echo hash_file('sha384', '/tmp/composer-setup.php');")"
if [ "$expected_signature" != "$actual_signature" ]; then
    echo 'Composer installer signature mismatch' >&2
    exit 1
fi
php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer --2 --quiet
mkdir -p backend/storage/logs

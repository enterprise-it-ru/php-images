# syntax=docker/dockerfile:1

# Версия PHP и релиз Debian передаются при сборке, список комбинаций — в versions.json
ARG PHP_VERSION=8.3
ARG DEBIAN_RELEASE=trixie

FROM php:${PHP_VERSION}-fpm-${DEBIAN_RELEASE}

# Зафиксированный релиз установщика: состав образа не меняется от выхода его новых версий
ARG IPE_VERSION=2.12.2
ADD --chmod=0755 https://github.com/mlocati/docker-php-extension-installer/releases/download/${IPE_VERSION}/install-php-extensions /usr/local/bin/

# Включены по умолчанию
ARG EXTENSIONS="apcu bcmath bz2 calendar exif gd gmp igbinary imagick intl mysqli opcache pcntl pdo_mysql pdo_pgsql pgsql redis soap sockets xsl zip"
# Установлены, но выключены. Проект включает нужные через docker-php-ext-enable, доступ в сеть для этого не нужен
ARG OPTIONAL_EXTENSIONS="xdebug pcov mongodb amqp memcached"

# Пакеты снятых с поддержки релизов Debian (например, bullseye) остаются только на archive.debian.org
ARG DEBIAN_MIRROR=""
RUN if [ -n "$DEBIAN_MIRROR" ]; then \
        for file in /etc/apt/sources.list /etc/apt/sources.list.d/*; do \
            if [ -f "$file" ]; then sed -i "s|http://deb.debian.org|$DEBIAN_MIRROR|g" "$file"; fi; \
        done; \
    fi

# git и unzip нужны composer для установки пакетов из исходников и быстрой распаковки архивов
RUN apt-get update \
    && apt-get install -y --no-install-recommends git unzip \
    && rm -rf /var/lib/apt/lists/*

# Списки расширений сохраняются в образе: по ним работает smoke-тест, и их можно посмотреть в готовом образе.
# Расширения, которые загружаются после своих зависимостей (например, memcached после igbinary),
# установщик включает через xx-php-ext-*.ini, остальные — через docker-php-ext-*.ini
RUN set -eu; \
    mkdir -p /usr/local/share/php-extensions; \
    printf '%s\n' $EXTENSIONS > /usr/local/share/php-extensions/enabled; \
    printf '%s\n' $OPTIONAL_EXTENSIONS > /usr/local/share/php-extensions/optional; \
    install-php-extensions $EXTENSIONS $OPTIONAL_EXTENSIONS @composer; \
    for ext in $OPTIONAL_EXTENSIONS; do rm "$PHP_INI_DIR"/conf.d/*-php-ext-"$ext".ini; done

#!/usr/bin/env bash
# Проверяет собранный образ: включённые расширения загружены, дополнительные выключены и включаются без ошибок
set -euo pipefail

image=${1:?"Использование: $0 <образ>"}

script=$(cat <<'SH'
# opcache регистрируется под именем "Zend OPcache"
is_loaded() {
    name=$1
    [ "$name" = opcache ] && name='Zend OPcache'
    php -r 'exit(extension_loaded($argv[1]) ? 0 : 1);' "$name"
}

# PHP не должен выводить предупреждения при запуске, например о повторной загрузке модуля
assert_clean_startup() {
    if php -v 2>&1 | grep -qiE 'warning|error'; then
        php -v
        echo "PHP выводит предупреждения при запуске" >&2
        exit 1
    fi
}

php -v
assert_clean_startup

for ext in $(cat /usr/local/share/php-extensions/enabled); do
    is_loaded "$ext" || { echo "Расширение $ext не загружено" >&2; exit 1; }
done

php -r '$gd = gd_info(); exit($gd["FreeType Support"] && $gd["JPEG Support"] && $gd["PNG Support"] && $gd["WebP Support"] ? 0 : 1);' \
    || { echo "gd собран без поддержки FreeType, JPEG, PNG или WebP" >&2; exit 1; }

for ext in $(cat /usr/local/share/php-extensions/optional); do
    if is_loaded "$ext"; then
        echo "Расширение $ext должно быть выключено по умолчанию" >&2
        exit 1
    fi
    docker-php-ext-enable "$ext"
    is_loaded "$ext" || { echo "Расширение $ext не включается через docker-php-ext-enable" >&2; exit 1; }
done
assert_clean_startup

php -m
php-fpm -t
COMPOSER_ALLOW_SUPERUSER=1 composer --version
git --version
echo "Образ прошёл проверку"
SH
)

docker run --rm "$image" sh -euc "$script"

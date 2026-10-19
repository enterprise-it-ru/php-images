# Локальная сборка и проверка одной версии: make test PHP=8.5
PHP ?= 8.3
DEBIAN ?= $(shell jq -r --arg php '$(PHP)' '.[] | select(.php == $$php) | .debian' versions.json)
DEBIAN_MIRROR ?= $(shell jq -r --arg php '$(PHP)' '.[] | select(.php == $$php) | .debian_mirror // ""' versions.json)
IMAGE ?= php-images:$(PHP)-fpm

.PHONY: build test

build:
	@test -n "$(DEBIAN)" || { echo "Версии PHP $(PHP) нет в versions.json"; exit 1; }
	docker build --build-arg PHP_VERSION=$(PHP) --build-arg DEBIAN_RELEASE=$(DEBIAN) --build-arg DEBIAN_MIRROR=$(DEBIAN_MIRROR) -t $(IMAGE) .

test: build
	./tests/smoke.sh $(IMAGE)

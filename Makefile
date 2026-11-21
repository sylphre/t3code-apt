# Copyright (C) 2014-2026 Laurier Sylph. All rights reserved.

SHELL := /bin/bash
ROOT := $(CURDIR)
PORT ?= 8080

.DEFAULT_GOAL := help
.PHONY: help key fetch verify index sign check hint deploy all serve clean

help:
	@printf '%s\n' \
	  'T3 Code APT archive' \
	  '' \
	  '  make key                 create the archive signing key' \
	  '  make fetch VERSION=x.y.z download and verify upstream .debs' \
	  '  make verify              re-check pool against pinned hashes' \
	  '  make index               rebuild Packages/Release/InRelease' \
	  '  make sign                re-sign the current Release file' \
	  '  make check               validate the signed archive' \
	  '  make hint                print the client setup snippet' \
	  '  make deploy DEST=...     rsync the archive to a static host' \
	  '  make all VERSION=x.y.z   fetch, index, check' \
	  '  make serve               serve the repo root on PORT ($(PORT))' \
	  '  make clean               remove generated dists metadata'

key:
	@scripts/keygen.sh

fetch:
	@scripts/fetch.sh "$(VERSION)"

verify:
	@scripts/verify.sh

index:
	@scripts/index.sh

sign:
	@test -f dists/stable/Release || { echo 'no Release; run make index' >&2; exit 1; }
	@source scripts/lib.sh && gpg --batch --quiet --yes --local-user "$$KEY_UID" \
	  --digest-algo SHA256 --clearsign -o "$(ROOT)/dists/stable/InRelease" \
	  "$(ROOT)/dists/stable/Release" && \
	  gpg --batch --quiet --yes --local-user "$$KEY_UID" --digest-algo SHA256 \
	  --armor --detach-sign -o "$(ROOT)/dists/stable/Release.gpg" \
	  "$(ROOT)/dists/stable/Release"

check:
	@scripts/check.sh

hint:
	@scripts/install-hint.sh

deploy:
	@scripts/deploy.sh "$(DEST)"

all: verify index check

serve:
	@printf 'serving %s at http://127.0.0.1:%s/\n' "$(ROOT)" "$(PORT)" >&2
	@cd "$(ROOT)" && python3 -m http.server "$(PORT)" --bind 127.0.0.1

clean:
	@rm -rf dists/stable/main

# Orchestration for the Event-B / B-method Ubuntu/Debian package registry.
#
# Common targets:
#   make build-<pkg>     build the .deb(s) for one package into build/
#   make build-all       build every package
#   make source-<pkg>    build a source package (.dsc/.changes) for PPA upload
#   make repo            assemble a signed APT repository under repo/
#   make lint            run lintian on everything in build/
#   make clean           remove build/, repo/ and downloads/

SHELL := /bin/bash

PKGS := eventb-to-txt evbt eventb-checker eventb-animate tlc4b b2program \
        prob2-ui prob rodin rodin-rc atelier-b rossi

# Note: per-package targets (build-%, source-%) are intentionally NOT listed as
# .PHONY -- GNU make skips pattern-rule matching for phony targets.
.PHONY: all build-all source-all repo lint clean list

all: build-all

list:
	@printf '%s\n' $(PKGS)

build-%:
	scripts/build-deb.sh "$*"

source-%:
	BUILD_SOURCE=1 BUILD_BINARY=0 scripts/build-deb.sh "$*"

build-all:
	@set -e; for p in $(PKGS); do echo "=== building $$p ==="; scripts/build-deb.sh "$$p"; done

source-all:
	@set -e; for p in $(PKGS); do echo "=== source $$p ==="; BUILD_SOURCE=1 BUILD_BINARY=0 scripts/build-deb.sh "$$p"; done

repo:
	scripts/make-repo.sh

lint:
	@shopt -s nullglob; debs=(build/*.deb); \
	if [ $${#debs[@]} -eq 0 ]; then echo "no .deb files in build/"; exit 0; fi; \
	lintian --no-tag-display-limit $${debs[@]} || true

clean:
	rm -rf build repo downloads

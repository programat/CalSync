#!/usr/bin/make -f

.DEFAULT_GOAL := help

ENV ?= local
APP_NAME := CalSync
RUN_SCRIPT := ./script/build_and_run.sh
SWIFT ?= swift
SWIFT_PACKAGE_FLAGS ?=
DEVELOPER_DIR ?= $(shell xcode-select -p)
TESTING_FRAMEWORKS_DIR := $(DEVELOPER_DIR)/Library/Developer/Frameworks
SWIFT_TEST_FLAGS := \
	-Xswiftc -Xfrontend \
	-Xswiftc -disable-cross-import-overlays \
	-Xswiftc -F \
	-Xswiftc $(TESTING_FRAMEWORKS_DIR) \
	-Xlinker -F \
	-Xlinker $(TESTING_FRAMEWORKS_DIR) \
	-Xlinker -rpath \
	-Xlinker $(TESTING_FRAMEWORKS_DIR)

COLOUR_GREEN := \033[1;32m
COLOUR_BLUE := \033[1;34m
END_COLOUR := \033[0m

ifeq ($(ENV),prod)
CONFIGURATION := release
else
CONFIGURATION := debug
endif

.PHONY: help build test bundle run debug logs telemetry verify clean reset

help: # show available commands
	@printf "workspace $(COLOUR_BLUE)$(APP_NAME)$(END_COLOUR) Makefile\n"
	@echo "Usage:\n  make $(COLOUR_GREEN)<command>$(END_COLOUR) [ENV=local|prod]\n"
	@echo "Commands:"
	@grep -E '^[a-z0-9][a-z0-9-]*:.*#' $(firstword $(MAKEFILE_LIST)) | while read -r l; do printf "  \033[1;34m$$(echo $$l | cut -f 1 -d':')\033[00m:$$(echo $$l | cut -f 2- -d'#')\n"; done

build: # build the Swift package
	@$(SWIFT) build $(SWIFT_PACKAGE_FLAGS) --configuration $(CONFIGURATION)

test: # run unit and integration-style tests
	@$(SWIFT) test $(SWIFT_PACKAGE_FLAGS) $(SWIFT_TEST_FLAGS)

bundle: # build and stage dist/CalSync.app without launching
	@CONFIGURATION=$(CONFIGURATION) SWIFT="$(SWIFT)" SWIFT_PACKAGE_FLAGS="$(SWIFT_PACKAGE_FLAGS)" $(RUN_SCRIPT) bundle

run: # build, install to ~/Applications, and launch
	@CONFIGURATION=$(CONFIGURATION) SWIFT="$(SWIFT)" SWIFT_PACKAGE_FLAGS="$(SWIFT_PACKAGE_FLAGS)" $(RUN_SCRIPT) run

debug: # build, install, and start lldb
	@CONFIGURATION=debug SWIFT="$(SWIFT)" SWIFT_PACKAGE_FLAGS="$(SWIFT_PACKAGE_FLAGS)" $(RUN_SCRIPT) debug

logs: # launch and stream process logs
	@CONFIGURATION=$(CONFIGURATION) SWIFT="$(SWIFT)" SWIFT_PACKAGE_FLAGS="$(SWIFT_PACKAGE_FLAGS)" $(RUN_SCRIPT) logs

telemetry: # launch and stream CalSync subsystem logs
	@CONFIGURATION=$(CONFIGURATION) SWIFT="$(SWIFT)" SWIFT_PACKAGE_FLAGS="$(SWIFT_PACKAGE_FLAGS)" $(RUN_SCRIPT) telemetry

verify: test bundle # test, stage, and statically verify the app bundle

clean: # remove generated build and distribution outputs
	@rm -rf .build dist

reset: clean # reset this package's local SwiftPM state
	@$(SWIFT) package $(SWIFT_PACKAGE_FLAGS) reset

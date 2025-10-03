SHELL := /bin/bash

FLUTTER ?= flutter
MELOS ?= melos
NPM ?= npm
FORMAT_DIRS := lib packages integration_test test tool

.PHONY: setup flutter-setup functions-install format format-check analyze flutter-test functions-test qa ci clean watch

setup: flutter-setup functions-install

flutter-setup:
	$(FLUTTER) pub get
	$(MELOS) bootstrap

functions-install:
	$(NPM) --prefix functions ci

format:
	$(FLUTTER) format $(FORMAT_DIRS)

format-check:
	$(FLUTTER) format --set-exit-if-changed $(FORMAT_DIRS)

analyze:
	$(MELOS) run analyze

flutter-test:
	$(MELOS) run test

functions-test:
	$(NPM) --prefix functions test

qa: analyze flutter-test functions-test

ci: setup qa

clean:
	$(FLUTTER) clean

watch:
	$(FLUTTER) run --flavor dev --target lib/main_dev.dart

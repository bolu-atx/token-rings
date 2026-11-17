CONFIG ?= debug
APP := dist/TokenRings.app
SOURCES := $(shell find Sources -type f -name '*.swift') Package.swift

.PHONY: all build run test clean

all: run

build: $(APP)

$(APP): $(SOURCES) scripts/build-app.sh
	./scripts/build-app.sh $(CONFIG)

run: build
	open $(APP)

test:
	./scripts/test.sh

clean:
	rm -rf .build dist

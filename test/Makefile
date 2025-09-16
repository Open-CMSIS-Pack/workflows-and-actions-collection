PROGRAM = testapp

.PHONY: all build test format-check coverage-check

all: build

build:
	go build -o build/$(PROGRAM) main.go

test:
	mkdir -p build && go test -v ./... | tee build/test-output.txt

format-check:
	mkdir -p build && gofmt -d . | tee build/format-check.out
	test ! -s build/format-check.out

coverage-check:
	mkdir -p build && go test ./... -coverprofile=build/cover.out

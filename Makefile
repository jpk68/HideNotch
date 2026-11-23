.PHONY: build clean fmt

JOBS ?= $(shell sysctl -n hw.ncpu)

build:
	cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
	cmake --build build --parallel $(JOBS)

clean:
	rm -rf build

fmt:
	clang-format -i --style=WebKit Source/*

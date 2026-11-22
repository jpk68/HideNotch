.PHONY: build clean fmt

build:
	cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
	cmake --build build

clean:
	rm -rf build

fmt:
	clang-format -i --style=WebKit Source/*

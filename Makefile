all: build run

build:
	./build_hot_reload.sh

.PHONY: build run

run:
	./game_hot_reload.bin


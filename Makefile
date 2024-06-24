.DEFAULT_GOAL := init
.PHONY: dev debug release

.DEFAULT: help
help:
	@echo "make dev"
	@echo "	run in dev mode"
	@echo "make debug"
	@echo "	run in debug mode"
	@echo "make release"
	@echo "	run in release mode"

check-odin:
ifeq (, $(shell which odin))
	$(error "Odin not in $(PATH), odin (https://odin-lang.org) is required")
endif

check-pre-commit:
ifeq (, $(shell which pre-commit))
	$(error "pre-commit not in $(PATH), pre-commit (https://pre-commit.com) is required")
endif

init: check-odin check-pre-commit
	pre-commit install

dev:
	./build_hot_reload.sh && ./game.bin

debug:
	odin build main_release -out:game_debug.bin -no-bounds-check -debug && ./game_debug.bin

release:
	odin build main_release -out:game_release.bin -no-bounds-check -o:speed -strict-style -vet-unused -vet-using-stmt -vet-using-param -vet-style -vet-semicolon && ./game.bin

.PHONY: debug hot-reload release

.DEFAULT: help
help:
	@echo "make debug"
	@echo "	run debug"
	@echo "make hot-reload"
	@echo "	run hot-reload"
	@echo "make release"
	@echo "	run release"

check-odin:
ifeq (, $(shell which odin))
	$(error "odin not in $(PATH), odin (https://odin-lang.org/) is required")
endif

debug:
	odin build main_release -out:game_debug.bin -no-bounds-check -debug && ./game_debug.bin

hot-reload:
	./build_hot_reload.sh && ./game.bin

release:
	odin build main_release -out:game_release.bin -no-bounds-check -o:speed -strict-style -vet-unused -vet-using-stmt -vet-using-param -vet-style -vet-semicolon && ./game.bin

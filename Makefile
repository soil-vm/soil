all: assemble disassemble soil-asm soil-c soil-zig

soil-zig: $(shell find zig/src -type f)
	cd zig; zig build -Doptimize=ReleaseFast && cp zig-out/bin/soil-zig ../soil-zig

run-hello:
	cat hello.recipe | ./assemble | ./soil

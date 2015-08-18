L2L_DIR=..

.SILENT:
run: build
	LUA_PATH=$(L2L_DIR)/?.lua lua main.lua

build:
	LUA_PATH=$(L2L_DIR)/?.lua $(L2L_DIR)/l2l main.lsp > main.lua;

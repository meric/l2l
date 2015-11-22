all: check samples test

repl:
	./l2l

check:
	luacheck --no-color --exclude-files l2l/compat.lua sample* \
	  --new-globals TypeException _R _C _D _M symbol resolve -- l2l/*.lua

samples:
	./l2l sample01.lsp
	./l2l sample02.lsp
	./l2l sample03.lsp
	./l2l sample04/main.lsp
	./l2l sample05.lsp

test: tests/*.lsp tests/init.lua *.lua
	lua tests/init.lua

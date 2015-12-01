all: check samples test

repl:
	./bin/l2l

check:
	luacheck --no-color --exclude-files compat.lua sample* \
	  --new-globals TypeException _R _C _D _M symbol resolve -- l2l/*.lua

samples:
	./bin/l2l --enable read_execute sample01.lsp > sample01.lua
	./bin/l2l sample02.lsp > sample02.lua
	./bin/l2l sample02.lsp sample03.lsp > sample03.lua
	./bin/l2l sample04/main.lsp > sample04/main.lua
	./bin/l2l sample05.lsp > sample05.lua

test: tests/*.lsp tests/init.lua *.lua
	lua tests/init.lua

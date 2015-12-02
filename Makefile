all: check samples test

repl:
	./bin/l2l

check:
	luacheck --no-color --exclude-files compat.lua sample* \
	  --new-globals TypeException _R _C _D _M symbol resolve -- l2l/*.lua

samples:
	bash ./bin/build sample04/main.lisp sample0*.lisp

test: tests/*.lisp tests/init.lua *.lua
	lua tests/init.lua

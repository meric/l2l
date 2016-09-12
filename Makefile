# luarocks install --local luacheck
check:
	luacheck --exclude-files l2l/ext/*.lua l2l/lib/*.lua l2l/test.lua -- l2l/

clean:
	rm l2l/ext/*.lua; rm l2l/lib/*.lua

test:
	lua -l luarocks.loader l2l/test.lua

test_luajit:
	luajit -l luarocks.loader l2l/test.lua

count:
	cloc l2l/*.lua l2l/ext/*.lisp l2l/lib/*.lisp

repl:
	bin/l2l -r

# luarocks install --local luacheck
check:
	luacheck --exclude-files l2l/ext/*.lua l2l/lib/*.lua -- l2l/

clean:
	rm l2l/ext/*.lua; rm l2l/lib/*.lua;

test:
	lua l2l/test.lua

count:
	cloc l2l/*.lua

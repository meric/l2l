if _VERSION == "Lua 5.1" then
    -- Lua 5.1 does not have the `unpack` function under `table`.
    table.unpack = unpack

    -- The Lua 5.1 `ipairs` function does not take into account `__ipairs`
    -- metatable method. This is a global `ipairs` override, to implement
    -- `__ipairs` metatable method.

    local _ipairs = ipairs

    function ipairs(iterable)
        if type(iterable) == "table" then
            local metatable = getmetatable(iterable)
            if metatable and metatable.__ipairs then
                return metatable.__ipairs(iterable)
            end
        end
        return _ipairs(iterable)
    end

--[[
The `check_chunk_type` and `load` compatibility functions are credited to
https://github.com/davidm. The code is copied from
https://github.com/davidm/lua-compat-env. Licensed under the same terms as
Lua 5.1/5.2 (MIT license), as follows:

(c) 2012 David Manura.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
]]-- 

    local function check_chunk_type(s, mode)
      local nmode = mode or 'bt' 
      local is_binary = s and #s > 0 and s:byte(1) == 27
      if is_binary and not nmode:match'b' then
        return nil, ("attempt to load a binary chunk (mode is '%s')"
            ):format(mode)
      elseif not is_binary and not nmode:match't' then
        return nil, ("attempt to load a text chunk (mode is '%s')"
            ):format(mode)
      end
      return true
    end

    -- Global `load` implementation, which is absent in Lua 5.1
    function load(ld, source, mode, env)
        local f
        if type(ld) == 'string' then
            local s = ld
            local ok, err = check_chunk_type(s, mode)
            if not ok then return ok, err end
            local err; f, err = loadstring(s, source)
            if not f then return f, err end
        elseif type(ld) == 'function' then
            local ld2 = ld
            if (mode or 'bt') ~= 'bt' then
            local first = ld()
            local ok, err = check_chunk_type(first, mode)
            if not ok then return ok, err end
            ld2 = function()
              if first then
                local chunk=first; first=nil; return chunk
              else return ld() end
            end
            end
            local err; f, err = load(ld2, source);
            if not f then return f, err end
        else
          error(("bad argument #1 to 'load' (function expected, got %s)")
                :format(type(ld)), 2)
        end
        if env then setfenv(f, env) end
        return f
      end
end

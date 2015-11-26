-- Functions useful for inline evaluation.

local module_path = (...):gsub('eval$', '')
local reader = require(module_path .. "reader")
local compiler = require(module_path .. "compiler")

local evaluate = function(str, env)
  -- returns a function, when evaluated, will evaluate each form in `str`.
  return function()
    local ok, stream, obj, form, _ok
    ok, stream = pcall(reader.tofile, str)
    if not ok then
      return nil
    end
    repeat
      ok, form = pcall(reader.read, stream)
      if ok then
        _ok, obj = pcall(compiler.eval, form, stream, env)
        if not _ok then
          error(obj)
        end
      elseif getmetatable(form) ~= reader.EOFException then
        error(form)
      end
    until not ok

    return obj
  end
end

return {
  eval = compiler.eval,
  read = reader.read,
  loadstring = evaluate,
  load = evaluate
}

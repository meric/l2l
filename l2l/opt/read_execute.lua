local reader = require("l2l.reader")
local eval = require("l2l.compiler").eval

function reader.read_execute(stream, byte)
    local obj = reader.read(stream)
    eval(obj, stream)
end

_D["."] = reader.read_execute

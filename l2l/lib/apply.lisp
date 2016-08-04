(fn apply (f ...)
    \local args = {...}
    local last = table.remove(args, select("#", ...))
    for _,v in ipairs(last) do table.insert(args, v) end
    return f(unpack(args)))

\return { apply = apply }

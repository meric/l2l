

local function import(library, ...)
    if type(library) == "string" then
        library = require(library)
    end

    local count = select('#', ...)
    
    if count == 0 then
        for key, value in pairs(library) do
            if not _G[key] then
                _G[key] = value
            end
        end
    else
        local t = {}
        for i=1, count do
            local key = select(i, ...)
            table.insert(t, library[key])
        end
        return unpack(t, 1, count)
    end
    return library
end

return import

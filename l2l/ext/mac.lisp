-- \
-- local utils = require("leftry").utils

-- local function import_macro(invariant, tab, mod, prefix)
--   invariant[tab] = invariant[tab] or {}
--   for k, v in pairs(import(mod)) do
--     local name = k
--     if prefix then
--       name = prefix[1].."."..k
--     end
--     reader.register_T(invariant, name, function(invariant, ...)
--       return v(...)
--     end)
--   end
-- end

-- return {
--   M = import_macro
-- }

#import fn
#import quote
#import local

{ [(\'+)] = \
  (fn (...)
    (local args (setmetatable (table.pack ...) vector))
    (local x 0)
    \
    for i, v in ipairs(args) do
      x = x + v
    end
    return x)}

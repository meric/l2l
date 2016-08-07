#import fn
#import local

{ apply = \
  (fn (f ...)
    (local args (setmetatable (table.pack ...) vector))
    (f (:unpack (args:append (args:pop)))))}

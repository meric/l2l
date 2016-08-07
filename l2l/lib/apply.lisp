#import fn
#import local

{ apply = \
  (fn (f ...)
    (local args (setmetatable (table.pack ...) vector))
    (args:append (args:pop))
    (f (table.unpack args 1 \#args)))}

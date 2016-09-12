@import fn
@import local

{ apply = \
  (fn (f ...)
    (local args (vector ...))
    (f (:unpack (args:append (args:pop)))))}

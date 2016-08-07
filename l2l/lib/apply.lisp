#import fn
#import local

{ apply = \
  (fn (f ...)
    (local args (vector.pack ...))
    (f (:unpack (args:append (args:pop)))))}

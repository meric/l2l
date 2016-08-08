#import fn
#import quote
#import local

{
  [(\'+)] = \
    (fn (...)
      (local args (vector ...))
      (local x 0)
      \
      for i, v in ipairs(args) do
        x = x + v
      end
      return x),
  [(\'*)] = \
    (fn (...)
      (local args (vector ...))
      (local x 1)
      \
      for i, v in ipairs(args) do
        x = x * v
      end
      return x),
  [(\'and)] = \
    (fn (...)
      (local args (vector ...))
      (local x true)
      \
      for i, v in ipairs(args) do
        x = x and v
      end
      return x),
  [(\'or)] = \
    (fn (...)
      (local args (vector ...))
      (local x false)
      \
      for i, v in ipairs(args) do
        x = x or v
      end
      return x)
}

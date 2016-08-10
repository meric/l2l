#import fn
#import quote
#import local
#import cond
#import do

(fn + (...)
  (local args (vector ...))
  (local x 0)
  \
  for i, v in ipairs(args) do
    x = x + v
  end
  return x)

(fn .. (...)
  (local args (vector ...))
  (local x "")
  \
  for i, v in ipairs(args) do
    x = x .. v
  end
  return x)

(fn * (...)
  (local args (vector ...))
  (local x 1)
  \
  for i, v in ipairs(args) do
    x = x * v
  end
  return x)

{
  [(\'+)] = (\+),
  [(\'..)] = (\..),
  [(\'-)] = \
    (fn (a ...)
      (cond
        \not a 0
        \not ... \-a
        \a - \(+ ...))),
  [(\'*)] = (\*),
  [(\'/)] = \
    (fn (a ...)
      (cond
        \not a 0
        \not ... \1/a
        \a / \(* ...))),
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
      return x),
  [(\'not)] = \
    (fn (a)
      \not a),
  [(\'%)] = \
    (fn (a b)
      \(a % b)),
  [(\'length)] = \
    (fn (a)
      \#a)
}

@import fn
@import quote
@import local
@import cond
@import do

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
  [(\'+):mangle()] = (\+),
  [(\'..):mangle()] = (\..),
  [(\'-):mangle()] = \
    (fn (a ...)
      (cond
        \not a 0
        \not ... \-a
        \a - \(+ ...))),
  [(\'*):mangle()] = (\*),
  [(\'/):mangle()] = \
    (fn (a ...)
      (cond
        \not a 0
        \not ... \1/a
        \a / \(* ...))),
  [(\'and):mangle()] = \
    (fn (...)
      (local args (vector ...))
      (local x true)
      \
      for i, v in ipairs(args) do
        x = x and v
      end
      return x),
  [(\'or):mangle()] = \
    (fn (...)
      (local args (vector ...))
      (local x false)
      \
      for i, v in ipairs(args) do
        x = x or v
      end
      return x),
  [(\'<):mangle()] = \
    (fn (a ...)
      (local args (vector ...))
      (local x true)
      \
      for i, v in ipairs(args) do
        x = x and a < v
        a = v
        if not x then
          return false
        end
      end
      return x),
  [(\'>):mangle()] = \
    (fn (a ...)
      (local args (vector ...))
      (local x true)
      \
      for i, v in ipairs(args) do
        x = x and a > v
        a = v
        if not x then
          return false
        end
      end
      return x),
  [(\'>=):mangle()] = \
    (fn (a ...)
      (local args (vector ...))
      (local x true)
      \
      for i, v in ipairs(args) do
        x = x and a >= v
        a = v
        if not x then
          return false
        end
      end
      return x),
  [(\'<=):mangle()] = \
    (fn (a ...)
      (local args (vector ...))
      (local x true)
      \
      for i, v in ipairs(args) do
        x = x and a <= v
        a = v
        if not x then
          return false
        end
      end
      return x),
  [(\'==):mangle()] = \
    (fn (a ...)
      (local args (vector ...))
      (local x true)
      \
      for i, v in ipairs(args) do
        x = x and a == v
        a = v
        if not x then
          return false
        end
      end
      return x),
  [(\'not):mangle()] = \
    (fn (a)
      \not a),
  [(\'%):mangle()] = \
    (fn (a b)
      \(a % b))
}

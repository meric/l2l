-- (local x (require y))

(fn + (...)
  \local args = {...}
  local x = 0
  for i, v in ipairs(args) do
    x = x + v
  end
  return x)

\return {
  [(\'+):hash()] = \+
}

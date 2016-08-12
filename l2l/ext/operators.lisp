@import quasiquote
@import quote
@import fn
@import cond

\--[[
Usage:
  (+ 1 2 3 4)
]]
(fn .. (a ...)
  (cond
    \not a ""
    ... `\(\,a .. \,(.. ...))
    \a == symbol("..."); '\(\..)(...)
    a))

(fn + (a ...)
  (cond
    \not a 0
    ... `\(\,a + \,(+ ...))
    \a == symbol("..."); '\(\+)(...)
    a))

(fn - (a ...)
  (cond
    \not a 0
    ... `\(\,a - \,(+ ...))
    \a == symbol("..."); '\(\-)(...)
    `\-\,a))

(fn * (a ...)
  (cond
    \not a 1
    ... `\(\,a * \,(* ...))
    \a == symbol("..."); '\(\*)(...)
    a))

(fn / (a ...)
  (cond
    \not a 1
    ... `\(\,a / \,(* ...))
    \a == symbol("..."); '\(\/)(...)
    `\(1/\,a)))

(fn and (a ...)
  (cond
    \not a true
    ... `\(\,a and \,(and ...))
    \a == symbol("..."); '\(\and)(...)
    a))

(fn or (a ...)
  (cond
    \not a false
    ... `\(\,a or \,(or ...))
    \a == symbol("..."); '\(\or)(...)
    a))

(fn not (a)
  `\not \,a)

(fn % (a b)
  `\(\,a % \,b))

(fn length (a)
  `\#\,a)

(fn < (a b ...)
  (cond
    \a == nil true
    \(a == symbol("...") and not b); '\((\<)(b, ...))
    \b == nil true
    \(b == symbol("...")); '\((\<)(...))
    \(not ...); `\(\,a < \,b)
    ... (and (< a b) (< b ...))
    true))

(fn > (a b ...)
  (cond
    \a == nil true
    \(a == symbol("...") and not b); '\((\>)(b, ...))
    \b == nil true
    \(b == symbol("...")); '\((\>)(...))
    \(not ...); `\(\,a > \,b)
    ... (and (> a b) (> b ...))
    true))

(fn <= (a b ...)
  (cond
    \a == nil true
    \(a == symbol("...") and not b); '\((\<=)(b, ...))
    \b == nil true
    \(b == symbol("...")); '\((\<=)(...))
    \(not ...); `\(\,a <= \,b)
    ... (and (<= a b) (<= b ...))
    true))

(fn >= (a b ...)
  (cond
    \a == nil true
    \(a == symbol("...") and not b); '\((\>=)(b, ...))
    \b == nil true
    \(b == symbol("...")); '\((\>=)(...))
    \(not ...); `\(\,a >= \,b)
    ... (and (>= a b) (>= b ...))
    true))

(fn == (a b ...)
  (cond
    \a == nil true
    \(a == symbol("...") and not b); '\((\==)(b, ...))
    \b == nil true
    \(b == symbol("...")); '\((\==)(...))
    \(not ...); `\(\,a == \,b)
    ... (and (== a b) (== b ...))
    true))

{
  macro = {
    [(\'..)]= \..,
    [(\'+)]= \+,
    [(\'-)]= \-,
    [(\'*)]= \*,
    [(\'/)]= \/,
    [(\'<)]= \<,
    [(\'>)]= \>,
    [(\'>=)]= \>=,
    [(\'<=)]= \<=,
    [(\'==)]= \==,
    [(\'and)]= \and,
    [(\'or)]= \or,
    [(\'not)]= \not,
    [(\'%)]= \%,
    [(\'length)]= \length,
  }
}

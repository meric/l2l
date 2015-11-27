;; recursive macro

(defmacro toobj (key value ...)
  (id (show key) value (if ... (toobj ...) nil)))

(print (toobj __tostring 5 __todict 6 what 8))

; compiled to (print "__tostring" 5 "__todict" 6 "what" 8)

;; recursive macro

#.(do
  (defmacro object (...)
    `{,(unpack
      (foreach
        (=> (obj i)
          (if (== (% i 2) 1)
            (show obj)
            obj))
        (vector ...)))}))

(print (object __tostring 5 __todict 6 what 8))

; compiled to print(dict("__tostring", 5, "__todict", 6, "what", 8))

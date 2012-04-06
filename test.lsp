; Example 1: Function declaration
(print "\n--- Example 1 ---\n")
(defun ! (n) 
  (cond ((== n 0) 1)
        ((== n 1) 1)
        (true (* n (! (- n 1))))))

(print (! 100))

(defun Σ () (print "ΣΣΣ"))

; Example 2: Acccessing functions from Lua environment
(print "\n--- Example 2 ---\n")
(set hello-world "hello gibberish world")
(print (string.gsub hello-world "gibberish " ""))

; Example 3: Quasiquote and unquote
(print "\n--- Example 3 ---\n")
(map print `(1 2 3 ,(map (lambda (x) (* x 5)) '(1 2 3))))
; Note: prints all numbers only for lua 5.2. only 5.2 supports __ipairs override

; Example 4: Let
(print "\n--- Example 4 ---\n")
(let (a (+ 1 2) 
      b (+ 3 4))
  (print a)
  (print b))

; Example 5: Accessor method
(print "\n--- Example 5 ---\n")
(.write {"write" (lambda (self x) (print x))} "hello-world")

; Example 6: Anonymous function
(print "\n--- Example 6 ---\n")
(print ((lambda (x y) (+ x y)) 10 20))

; Example 7: Directive (The '#' prefix)
(print "\n--- Example 7 ---\n")
; The following line will run as soon as it is parsed, no code will be generated
; It will add a new "--" operator that will be effective immediately
#(set -- (Operator (lambda (str) (.. "-- " (tostring str))))) 

; Adds a lua comment to lua executable, using operator we defined.
(-- "This is a comment") ; Will appear in `out.lua`

; Example 8: Define a do block
#(print "\n--- Example 8 ---\n")
; E.g. (do (print 1) (print 2)) will execute (print 1) and (print 2) in sequence
#(set do (Operator (lambda (...) 
      (.. "(function()\n" 
            (indent (compile [...])) 
          "\nend)()"))))
(print "\n--- Example 8 ---\n")
(print "\n--- Did you see what was printed while compiling? ---\n")
(do
  (print 1)
  (print 2))

; We can now make this program be interpreted by wrapping code in "#(do ...)"!

#(do
  (print "I am running this line in the compilation step!")
  (print "This too!")
  (print (.. "1 + 1 = " (+ 1 1) "!"))
  (print "Okay that's enough."))

; We've had enough, so let's delete our do Operator
#(set do nil)

; Uncommenting the following will result in an error when compiling
; #(do (print 1))

; Example 9: Vector
(print "\n--- Example 9 ---\n")
(let (a (* 7 8))
  (map print [1 2 a 4]))

; Example 10: Dictionary
(print "\n--- Example 10 ---\n")
(let (dict {"a" "b" 1 2 "3" 4})
  (print dict["a"] "b")
  (print dict.a "b")
  (print dict[1] 2)
  (print dict.3 4))




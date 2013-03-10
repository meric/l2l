

; Example 1: Function declaration
(print "\n--- Example 1 ---\n")
(defun ! (n) 
  (cond ((== n 0) 1)
        ((== n 1) 1)
        (true (* n (! (- n 1))))))
(print (! 100))
; Output:
; --- Example 1 ---
;
; 9.3326215443944e+157

; Example 2: Unicode Symbols
(print "\n--- Example 2 ---\n")
(defun Σ () (print "ΣΣΣ"))
(Σ)

; Output:
; --- Example 2 ---
;
; ΣΣΣ

; Example 3: Acccessing functions from Lua environment
(print "\n--- Example 3 ---\n")
(set hello-world "hello gibberish world")
; This lisp does not support multiple return, so calls to Lua functions with 
; multiple return must be wrapped with [ and ] to save all the results into an 
; array.
(print (table.concat [ (string.gsub hello-world "gibberish " "") ] " "))

; Output:
; --- Example 3 ---
;
; hello world

; Example 4: Quasiquote and unquote
(print "\n--- Example 4 ---\n")
(map print `(1 2 3 ,(map (lambda (x) (* x 5)) '(1 2 3))))
; Note: prints all numbers only for lua 5.2. only 5.2 supports __ipairs override

; Output:
; --- Example 4 ---
;
; 1
; 2
; 3
; (5 10 15)

; Example 5: Let
(print "\n--- Example 5 ---\n")
(let (a (+ 1 2) 
      b (+ 3 4))
  (print a)
  (print b))

; Output:
; --- Example 5 ---
;
; 3
; 7

; Example 6: Accessor method
(print "\n--- Example 6 ---\n")
(.write {"write" (lambda (self x) (print x))} "hello-world")

; Output:
; --- Example 6 ---
;
; hello-world

; Example 7: Anonymous function
(print "\n--- Example 7 ---\n")
(print ((lambda (x y) (+ x y)) 10 20))

; Output:
; --- Example 7 ---
;
; 30

; Example 8: Vector
(print "\n--- Example 8 ---\n")
(let (a (* 7 8))
  (map print [1 2 a 4]))

; Output:
; --- Example 8 ---
;
; 1
; 2
; 56
; 4

; Example 9: Dictionary
(print "\n--- Example 9 ---\n")
(let (dict {"a" "b" 1 2 "3" 4})
  (print dict["a"] "b")
  (print dict.a "b")
  (print dict[1] 2)
  (print dict.3 4))

; Output:
; --- Example 9 ---
;
; b b
; b b
; 2 2
; 4 4

; Example 10: Directive (The '#.' prefix)
(print "\n--- Example 10 ---\n")
; The following line will run as soon as it's parsed, no code will be generated
; It will add a new "--" operator that will be effective immediately
#.(set -- (Operator (lambda (str) 
  (table.insert (.peek META.block) (.. "\n-- " (tostring str)))))) 

; Adds a lua comment to lua executable, using operator we defined.
(-- "This is a comment") ; Will appear in `out.lua`

; Output:
; --- Example 10 ---
;

; Example 11: Define a do block
#.(print "\n--- Example 11 ---\n")
; E.g. (do (print 1) (print 2)) will execute (print 1) and (print 2) in sequence
#.(set do (Operator (lambda (...) 
  (table.insert (.peek META.block) (genblock [...] (gensym "do"))))))

; We can now make this program be interpreted by wrapping code in "#(do ...)"!

#.(do
  (print "I am running this line in the compilation step!")
  (print "This too!")
  (print (.. "1 + 1 = " (+ 1 1) "!"))
  (print "Okay that's enough."))

; Compiler Output:
; --- Example 11 ---

; I am running this line in the compilation step!
; This too!
; 1 + 1 = 2!
; Okay that's enough.

(print "\n--- Example 11 ---\n")
(print "\n--- Did you see what was printed while compiling? ---\n")
(do
  (print 1)
  (print 2))

; Output:
; --- Example 11 ---
;
;
; --- Did you see what was printed while compiling? ---
;
; 1
; 2

; We've had enough, so let's delete our do Operator
#.(set do nil)

; Uncommenting the following will result in an error when compiling
; #.(do (print 1))

; Example 12: Macro
(print "\n--- Example 12 ---\n")

(defmacro if (condition action otherwise)
  `(cond
    (,condition ,action)
    (true ,otherwise)))

(let (a 2)
  (if (== a "1") (print "a == 1") 
    (if (== a 2) (print "a == 2") (print "a != 2"))))

#.(print "\n--- Example 12 ---\n")

(defmacro GAMMA () '(+ 1 2))
(defmacro BETA () '(.. (tostring (GAMMA)) "4"))
(defmacro ALPHA () '(BETA))

; Macros are compiler-time constructs. They are not visible during run-time.
; So if we want to view their expansion, we must do it during compile-time too.
#.(print (macroexpand '(ALPHA)))
(print (ALPHA))

; Output:
; --- Example 12 ---
;
; a == 2
; 34

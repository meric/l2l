; Run using `./l2l sample03.lisp | lua`

;; executes sample02 during compilation time, 
;; and makes available sample02 during evaluation time.
;; Useful if sample02 has a combination of macros and exported functions.
(import sample02) 

(print (sum '(1 3 5 7)))

(if1 1 (print 1) (print 0))

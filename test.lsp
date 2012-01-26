(label a 5)
(print a)
(print (* a 5))

(label double (lambda (x) (* x 2)))
(print (double a))

(print (eval (quote (double (+ 1 2)))))

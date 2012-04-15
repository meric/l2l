(defmacro if (condition action otherwise)
  `(cond
    (,condition ,action)
    (true ,otherwise)))

(defun sum (list)
  (if list (+ (car list) (sum (cdr list))) 0))




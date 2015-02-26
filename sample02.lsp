(defmacro if1 (condition action otherwise)
  `(cond
    ,condition ,action
    ,otherwise))

(defun sum (l)
  (if l (+ (car l) (sum (cdr l))) 0))


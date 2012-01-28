(defun caar (a) (car (car a)))
(defun cadr (a) (car (cdr a)))

(assert (not '()))

(defun ! (n) 
  (cond ((eq n 0) 1)
        ((eq n 1) 1)
        ('t (* n (! (- n 1))))))

(print (! 100))


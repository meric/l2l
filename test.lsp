(defun ! (n) 
  (cond ((eq n 0) 1)
        ((eq n 1) 1)
        ('t (* n (! (- n 1))))))

(print (! 100))

(print (string.gsub "hello gibberish world" "gibberish " ""))


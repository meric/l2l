(defun ! (n) 
  (cond ((eq n 0) 1)
        ((eq n 1) 1)
        (true (* n (! (- n 1))))))

(print (! 100))

(set hello-world "hello gibberish world")
(print (string.gsub hello-world "gibberish " ""))

(map print `(1 2 3)) 
; prints all numbers only for lua 5.2, only 5.2 supports __ipairs override.

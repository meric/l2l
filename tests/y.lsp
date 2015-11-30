(let (Y (lambda (h)
          ((lambda (x) (x x))
           (lambda (g)
             (h (lambda (x) ((g g) x))))))
      fac (Y
           (lambda (f)
             (lambda (x)
               (if (< x 2)
                   1
                 (* x (f (- x 1)))))))
      fib (Y
           (lambda (f)
             (lambda (x)
               (if (< x 2)
                   x
                 (+ (f (- x 1)) (f (- x 2))))))))
  (id fac fib))

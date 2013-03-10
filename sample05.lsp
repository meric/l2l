; http://en.wikipedia.org/wiki/Binomial_options_pricing_model
  
(defun tree (i u n) 
  (let (d (/ 1 u))
    (cond 
      ((> n 0)
        `(,i 
          ,(tree (* i u) u (- n 1))
          ,(tree (* i d) u (- n 1))))
      (true nil))))

(defun at (tree)
  (car tree))

(defun up (tree)
  (cond 
    ((cdr tree) (car (cdr tree)))
    (true nil)))

(defun down (tree)
  (cond 
    ((== (cdr tree) nil) nil)
    ((cdr (cdr tree)) (car (cdr (cdr tree))))
    (true nil)))

(defun draw-row (tree)
  (cond 
    ((== tree nil) "")
    (true
      (..
        (tostring (at tree))
        "\t- "
        (draw-row (up tree))))))

(defun draw (tree indent)
  (cond 
    ((== tree nil) "")
    (true (..
      (draw-row tree)
      "\n"
      (draw (down tree))))))

(let 
  (
    ;; years
    period 0.5                                      
    count(period) 2 
    ;; standard deviation
    volatility 0.32                    
    ;; up factor             
    u (math.exp (* volatility (math.sqrt period)))  
    ;; down factor
    d (/ 1 u)                   
    ;; Rf per period                    
    r (math.exp (* 0.5 0.1))     
    ;; dollars after 6 months                   
    dividend 1 
    PV(dividend) (/ dividend r)
    price_0 70
    ;; initial price without dividend
    price_0-PV(dividend) (- price_0 PV(dividend))
    p0 price_0-PV(dividend)
  )

  (print (draw (tree p0 u 3)))
  (print '(1 2 3 4)))

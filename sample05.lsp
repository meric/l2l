; http://en.wikipedia.org/wiki/Binomial_options_pricing_model
  
(defun tree (i u n) 
  (let (d (/ 1 u))
    (cond 
      (> n 0)
        `(,i 
          ,(tree (* i u) u (- n 1))
          ,(tree (* i d) u (- n 1)))
      nil)))

(defun at (tree)
  (car tree))

(defun up (tree)
  (cond 
    (cdr tree) (car (cdr tree))
    nil))

(defun down (tree)
  (cond 
    (== (cdr tree) nil) nil
    (cdr (cdr tree)) (car (cdr (cdr tree)))
    nil))

(defun draw-row (tree)
  (cond 
    (== tree nil) ""
    (..
      (tostring (at tree))
      "\t- "
      (draw-row (up tree)))))

(defun draw (tree indent)
  (cond 
    (== tree nil) ""
    (..
      (draw-row tree)
      "\n"
      (draw (down tree)))))

(let 
  (
    ;; years
    period 0.5                                      
    count_period 2 
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
    PV_dividend_ (/ dividend r)
    price_0 70
    ;; initial price without dividend
    price_0-PV_dividend_ (- price_0 PV_dividend_)
    p0 price_0-PV_dividend_
  )

  (print (draw (tree p0 u 3)))
  (print '(1 2 3 4)))

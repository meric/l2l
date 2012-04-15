; Example demonstrating importing functions from another file

(set stat (require "sample02"))

(print (stat.sum '(1 3 5 7)))

(if 1 (print 1) (print 0)) ; `if` was imported from sample02
; Macros are global scope, unfortunately...




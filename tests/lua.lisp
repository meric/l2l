(let (
  tests [
    `(,true "(<- () return nil)")
    `(,true "(<- () return nil;)")
    `(,true "(<- () return(nil))")
    `(,true "(<- () return not(nil))")
    `(,true "(<- () return not (nil))")
    `(,false "(<- () returnnot nil)")
    `(,true "(<- () while(nil)do end)")
    `(,true "(<- () while nil do end)")
    `(,false "(<- () while nildo end)")
    `(,false "(<- () whilenil do end)")
    `(,true "(<- () while nil do return;end)")
    `(,true "(<- () while nil do return nil;end)")
    `(,true "(<- () while nil do return(nil);end)")
    `(,true "(<- () while nil do return(nil)end)")
    `(,true "(<- () while nil do return(nil) end)")
    `(,true "(<- () while nil do return end)")
    `(,true "(<- () while nil do return nil end)")
    `(,true "(<- () while nil do return false,(nil) end)")
    `(,true "(<- () while true do return false end)")
    `(,true "(<- () while nil do return 123 end)")
    `(,true "(<- () while 124 do return -123 end)")
    `(,true "(<- () while nil do return -1.23 end)")
    `(,true "(<- () while nil do return 1.23, true end)")
    `(,true "(<- () while nil do return not 1.23, not true end);")
    `(,true "(<- () while nil do return not 1.23, not true end; 
                while nil do return not 1.23, not true end; 
                while nil do return not 1.23, not true end; 
                while nil do return not 1.23, not true end;);")
    `(,true "(<- ()
      while nil do return -1.23 end;
      while nil do return -1.23 end;
      return;)")
    `(,true "(<- () return a)")
    `(,true "(<- () return (a), nil)")
    `(,true "(<- () return a.b.c().d.e.f )")
    `(,true "(<- () return (a), b)")
    `(,true "(<- () return(a))")
    `(,true "(<- () return a.b)")
    `(,true "(<- () return (a.b), nil)")
    `(,true "(<- () return (a).b, nil)")
    `(,true "(<- () return (a))")
    `(,true "(<- () (a)(b) )")
    `(,true "(<- () return (a)(b) )")
    `(,true "(<- () return a(b)  )")
    `(,true "(<- () return a(b)(c)   )")
    `(,true "(<- () return (a)(b))")
    `(,true "(<- () return a(b), nil)")
    `(,true "(<- () return a(b)(c), nil)")
    `(,true "(<- () return a[b][c]   )")
    `(,true "(<- () return a[d](e)   )")
    `(,true "(<- () a[d](e)   )")
    `(,true "(<- () return (e)[f]   )")
    `(,true "(<- () return f(e, f)   )")
    `(,true "(<- () return f(e, f(d))   )")
    `(,true "(<- () return f(a)(b)(c)(d)   )")
    `(,true "(<- () return f()[d]   )")
    `(,true "(<- () return f()[d](e)[f].g   )")
    `(,true "(<- () return ((((((f(a))))))) )")
    `(,true "(<- () return f:x():t()[d]   )")
  ]
  reader (require "l2l.reader2"))

  (foreach
    (=> (test)
      (let (
          expected (car test)
          text (cadr test)
          (ok value rest) (pcall reader.read nil (finalize (tolist text))))
        (if (~= ok expected)
          (print "failed" text (if ok "==" "=>") value)
          (id "ok" text (if ok "==" "=>") (if ok (car value) "<Error as expected>")))
        ))
    tests))

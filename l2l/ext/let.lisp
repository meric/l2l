#import fn
#import quote
#import quasiquote

(fn compile_local_stat (invariant cdr output)
  \local var, val = list.unpack(cdr)

  print(">>", \`\(x + \,\y)) -- need to sub var in

  \'\local x)

(fn compile_local_exp (invariant cdr output)
  (print ">>" cdr)
  
  '\print(1))

\return {
  lua = {
    [symbol("let"):hash()] = {
        expize=compile_local_exp,
        statize=compile_local_stat
    }
  }
}
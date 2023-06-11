local lust = require "lust"
-- operations
assert(lust.eval("(+ 1 2)") == 3)
assert(lust.eval("(+ 1 2 3)") == 6)
assert(lust.eval("(+ 1 2 3 4)") == 10)
assert(lust.eval("(- 1)") == -1)
assert(lust.eval("(- 1 2)") == -1)
assert(lust.eval("(- 1 2 3)") == -4)
assert(lust.eval("(* 2 2)") == 4)
assert(lust.eval("(* 2 4)") == 8)
assert(lust.eval("(* 2 2 2)") == 8)
-- arguments
assert(lust.eval("&1", 2, 1) == 2)
assert(lust.eval("&2", 1, 2) == 2)
assert(lust.eval("&(+ 1 1)", 1, 2) == 2)
-- closures
assert(lust.eval("(do #(+ &1 &2) 2 3)") == 5)
assert(lust.eval("(do #(+ &1 &2 &2) 2 3)") == 8)
assert(lust.eval("(do #(+ &1 &1) 2 3)") == 4)
-- ?
assert(lust.eval("(? true 5 10)") == 5)
assert(lust.eval("(? false 5 10)") == 10)
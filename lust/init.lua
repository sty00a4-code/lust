local lust = {}
lust.scanner = require "lust.scanner"
lust.compiler = require "lust.compiler"
lust.evaluator = require "lust.evaluator"
---@param code string
function lust.eval(code, ...)
    local args = {...}
    local nodes, err = lust.scanner.scan(nil, code) if err then return nil, err end
    if not nodes then return end
    local closures, constants = lust.compiler.compile(nodes) if err then return nil, err end
    local value value, err = lust.evaluator.eval(closures, constants, args) if err then return nil, err end
    if value then return value:unwrap() end
end
return lust
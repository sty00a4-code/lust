local position = require "lust.position"
local Error = position.Error
local compiler = require "lust.compiler"
local ByteCode = compiler.ByteCode

local Value = {
    mt = {
        __name = "value"
    }
}
---@param type "null"|"boolean"|"number"|"string"|"table"|"closure"|"key"|"function"
---@param value any
---@return Value
function Value.new(type, value)
    ---@class Value
    return setmetatable({
        type = type,
        value = value,

        from = Value.from,
        unwrap = Value.unwrap,
        copy = Value.copy,
        tostring = Value.tostring,
    }, Value.mt)
end
---@param value any
---@return Value
function Value.from(value)
    if value == nil then
        return Value.new("null", nil)
    elseif type(value) == "boolean" then
        return Value.new("boolean", value)
    elseif type(value) == "number" then
        return Value.new("number", value)
    elseif type(value) == "string" then
        return Value.new("string", value)
    elseif type(value) == "table" then
        local table = {}
        for key, v in pairs(value) do
            table[key] = Value.from(v)
        end
        return Value.new("table", table)
    elseif type(value) == "function" then
        return Value.new("function", value)
    else
        error("unknown value type")
    end
end
---@param self Value
---@return any
function Value:unwrap()
    if self.type == "null" then
        return nil
    elseif self.type == "boolean" then
        return self.value
    elseif self.type == "number" then
        return self.value
    elseif self.type == "string" then
        return self.value
    elseif self.type == "table" then
        local table = {}
        for key, value in pairs(self.value) do
            table[key] = value:unwrap()
        end
        return table
    elseif self.type == "closure" then
        return setmetatable({ addr = self.value }, { __name = "closure" })
    elseif self.type == "key" then
        return setmetatable({ key = self.value }, { __name = "key" })
    elseif self.type == "function" then
        return self.value
    else
        error("unknown value type")
    end
end
---@param self Value
---@return Value
function Value:copy()
    if self.type == "table" then
        local value = {}
        for key, v in pairs(self.value) do
            value[key] = v:copy()
        end
        return Value.new("table", value)
    else
        return Value.new(self.type, self.value)
    end
end

---@param self Value
---@return string
function Value:tostring()
    if self.type == "null" then
        return "null"
    elseif self.type == "boolean" then
        return tostring(self.value)
    elseif self.type == "number" then
        return tostring(self.value)
    elseif self.type == "string" then
        return string.format("%q", self.value)
    elseif self.type == "table" then
        local parts = {}
        for key, value in pairs(self.value) do
            parts[#parts + 1] = string.format("[%s] = %s", Value.new("string", key):tostring(), Value.new("table", value):tostring())
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    elseif self.type == "closure" then
        return ("closure(%s)"):format(self.value)
    elseif self.type == "function" then
        return tostring(self.value)
    elseif self.type == "key" then
        return "@" .. self.value
    else
        error(("unknown value type: %q"):format(self.type))
    end
end

local Evaluator = {
    mt = {
        __name = "evaluator",
    },
}
---@param closures table<integer, table<integer, integer>>
---@param constants Constants
---@param args table<integer, Value>
---@return Evaluator
function Evaluator.new(closures, constants, args)
    ---@class Evaluator
    return setmetatable({
        closures = closures,
        constants = constants,
        closurePointer = 1,
        pointer = 1,
        ---@type table<integer, integer>
        closurePointerStack = {},
        ---@type table<integer, integer>
        pointerStack = {},
        ---@type table<integer, table<integer, Value>>
        argsStack = { args },
        ---@type table<integer, Value>
        stack = {},
        vars = Evaluator.stdVars,
        error = Evaluator.error,
        next = Evaluator.next,
        pushValue = Evaluator.pushValue,
        popPointers = Evaluator.popPointers,
        pushPointers = Evaluator.pushPointers,
        pushArgs = Evaluator.pushArgs,
        popArgs = Evaluator.popArgs,
        enterClosure = Evaluator.enterClosure,
        arg = Evaluator.arg,
        args = Evaluator.args,
        step = Evaluator.step,
        run = Evaluator.run,
        debug = Evaluator.debug,
    }, Evaluator.mt)
end
---@param self Evaluator
---@param message string
function Evaluator:error(message)
    local closure = self.closures[self.closurePointer]
    local byte = closure[self.pointer - 1]
    --- change later to use position of byte
    local pos = position.Position.new(position.File.new("<todo>"), 1, 1)
    return nil, Error.new(pos, message)
end
---@param self Evaluator
function Evaluator:next()
    local closure = self.closures[self.closurePointer]
    local byte = closure[self.pointer]
    self.pointer = self.pointer + 1
    return byte
end
---@param self Evaluator
function Evaluator:pushValue(value)
    self.stack[#self.stack + 1] = value
end
---@param self Evaluator
function Evaluator:pushPointers()
    self.pointerStack[#self.pointerStack + 1] = self.pointer
    self.closurePointerStack[#self.closurePointerStack + 1] = self.closurePointer
end
---@param self Evaluator
function Evaluator:pushArgs(args)
    self.argsStack[#self.argsStack + 1] = args
end
---@param self Evaluator
function Evaluator:popArgs(args)
    return table.remove(self.argsStack)
end
---@param self Evaluator
function Evaluator:enterClosure(addr)
    self:pushPointers()
    self.closurePointer = addr
    self.pointer = 1
end
---@param self Evaluator
---@param index integer
---@return Value|nil
function Evaluator:arg(index)
    local args = self.argsStack[#self.argsStack]
    return args[index]
end
---@param self Evaluator
---@param startIndex integer
---@return table<integer, Value>
function Evaluator:args(startIndex)
    local args = self.argsStack[#self.argsStack]
    local collectedArgs = {}
    for i = startIndex, #args do
        table.insert(collectedArgs, args[i])
    end
    return collectedArgs
end
---@param self Evaluator
---@return integer, integer
function Evaluator:popPointers()
    return table.remove(self.pointerStack), table.remove(self.closurePointerStack)
end
---@param self Evaluator
function Evaluator:run()
    while true do
        local _, err = self:step() if err then return nil, err end
        if not self.pointer and not self.closurePointer then
            return self.stack[#self.stack]
        end
    end
end
---@param self Evaluator
function Evaluator:step()
    local pos = position.Position.new(position.File.new("<todo>"), 1, 1)
    local instr = self:next()
    if not instr then
        self.pointer, self.closurePointer = self:popPointers()
        self:popArgs()
        return
    end
    if instr == ByteCode.None then
    elseif instr == ByteCode.Null then
        self:pushValue(Value.new("null", nil))
    elseif instr == ByteCode.Number then
        local addr = self:next()
        self:pushValue(Value.new("number", self.constants.number[addr]))
    elseif instr == ByteCode.String then
        local addr = self:next()
        self:pushValue(Value.new("string", self.constants.string[addr]))
    elseif instr == ByteCode.Boolean then
        local value = self:next()
        self:pushValue(Value.new("boolean", value == 1))
    elseif instr == ByteCode.Word then
        local addr = self:next()
        local value = self.vars[self.constants.string[addr]]
        if not value then
            return self:error("unknown variable")
        end
        self.stack[#self.stack + 1] = value
    elseif instr == ByteCode.Eval then
        local count = self:next()
        local args = {}
        for i = count, 1, -1 do
            args[i] = table.remove(self.stack)
        end
        self:pushArgs(args)
        local func = table.remove(self.stack)
        if not func then
            return self:error("cannot call nil")
        end
        if func.type == "closure" then
            self:enterClosure(func.value)
        elseif func.type == "function" then
            local results, keepArgs, err = func.value(self, pos) if err then return nil, err end
            if not keepArgs then self:popArgs() end
            for i = #results, 1, -1 do
                self:pushValue(results[i])
            end
        else
            return self:error("cannot call non-closure or non-function")
        end
    elseif instr == ByteCode.List then
        local count = self:next()
        local t = {}
        for i = count, 1, -1 do
            t[i] = table.remove(self.stack)
        end
        self:pushValue(Value.new("table", t))
    elseif instr == ByteCode.Key then
        local key = table.remove(self.stack)
        self:pushValue(Value.new("key", key))
    elseif instr == ByteCode.Arg then
        local index = table.remove(self.stack) if not index then return self:error("expected argument index") end
        if index.type ~= "number" then
            return self:error("expected argument index to be of type number")
        end
        self:pushValue(self:arg(index.value))
    elseif instr == ByteCode.Closure then
        local addr = self:next()
        self:pushValue(Value.new("closure", addr))
    else
        error("unknown instruction: " .. instr)
    end
end
Evaluator.stdVars = {
    ["true"] = Value.new("boolean", true),
    ["false"] = Value.new("boolean", false),
    ["null"] = Value.new("null", nil),
    ---@param evaluator Evaluator
    ---@param pos Position
    ["+"] = Value.new("function", function(evaluator, pos)
        local a, args = evaluator:arg(1), evaluator:args(2)
        if not a then return nil, Error.new(pos, "expected at least 1 argument") end
        if a.type ~= "number" then return nil, Error.new(pos, "expected &1 to be of type number, got " .. a.type) end
        local res = a:copy()
        for i, arg in ipairs(args) do
            if arg.type ~= "number" then return nil, Error.new(pos, "expected &" .. i + 1 .. " to be of type number, got " .. arg.type) end
            res.value = res.value + arg.value
        end
        return { res }
    end),
    ---@param evaluator Evaluator
    ---@param pos Position
    ["-"] = Value.new("function", function(evaluator, pos)
        local a, args = evaluator:arg(1), evaluator:args(2)
        if not a then return {}, Error.new(pos, "expected at least 1 argument") end
        if a.type ~= "number" then return {}, Error.new(pos, "expected &1 to be of type number, got " .. a.type) end
        local res = a:copy()
        if #args == 0 then
            res.value = -res.value
            return { res }
        end
        for i, arg in ipairs(args) do
            if arg.type ~= "number" then return {}, Error.new(pos, "expected &" .. i + 1 .. " to be of type number, got " .. arg.type) end
            res.value = res.value - arg.value
        end
        return { res }
    end),
    ---@param evaluator Evaluator
    ---@param pos Position
    ["*"] = Value.new("function", function(evaluator, pos)
        local a, args = evaluator:arg(1), evaluator:args(2)
        if not a then return nil, Error.new(pos, "expected at least 1 argument") end
        if a.type ~= "number" then return nil, Error.new(pos, "expected &1 to be of type number, got " .. a.type) end
        local res = a:copy()
        for i, arg in ipairs(args) do
            if arg.type ~= "number" then return nil, Error.new(pos, "expected &" .. i + 1 .. " to be of type number, got " .. arg.type) end
            res.value = res.value * arg.value
        end
        return { res }
    end),
    ---@param evaluator Evaluator
    ---@param pos Position
    ["/"] = Value.new("function", function(evaluator, pos)
        local a, args = evaluator:arg(1), evaluator:args(2)
        if not a then return nil, Error.new(pos, "expected at least 1 argument") end
        if a.type ~= "number" then return nil, Error.new(pos, "expected &1 to be of type number, got " .. a.type) end
        local res = a:copy()
        for i, arg in ipairs(args) do
            if arg.type ~= "number" then return nil, Error.new(pos, "expected &" .. i + 1 .. " to be of type number, got " .. arg.type) end
            res.value = res.value / arg.value
        end
        return { res }
    end),
    ---@param evaluator Evaluator
    ---@param pos Position
    ["^"] = Value.new("function", function(evaluator, pos)
        local a, args = evaluator:arg(1), evaluator:args(2)
        if not a then return nil, Error.new(pos, "expected at least 1 argument") end
        if a.type ~= "number" then return nil, Error.new(pos, "expected &1 to be of type number, got " .. a.type) end
        local res = a:copy()
        for i, arg in ipairs(args) do
            if arg.type ~= "number" then return nil, Error.new(pos, "expected &" .. i + 1 .. " to be of type number, got " .. arg.type) end
            res.value = res.value ^ arg.value
        end
        return { res }
    end),
    ---@param evaluator Evaluator
    ---@param pos Position
    ["%"] = Value.new("function", function(evaluator, pos)
        local a, args = evaluator:arg(1), evaluator:args(2)
        if not a then return nil, Error.new(pos, "expected at least 1 argument") end
        if a.type ~= "number" then return nil, Error.new(pos, "expected &1 to be of type number, got " .. a.type) end
        local res = a:copy()
        for i, arg in ipairs(args) do
            if arg.type ~= "number" then return nil, Error.new(pos, "expected &" .. i + 1 .. " to be of type number, got " .. arg.type) end
            res.value = res.value % arg.value
        end
        return { res }
    end),
    ---@param evaluator Evaluator
    ---@param pos Position
    ["and"] = Value.new("function", function(evaluator, pos)
        local a, args = evaluator:arg(1), evaluator:args(2)
        if not a then return nil, Error.new(pos, "expected at least 1 argument") end
        local res = a:copy()
        for i, arg in ipairs(args) do
            res.value = res.value and arg.value
        end
        return { res }
    end),
    ---@param evaluator Evaluator
    ---@param pos Position
    ["or"] = Value.new("function", function(evaluator, pos)
        local a, args = evaluator:arg(1), evaluator:args(2)
        if not a then return nil, Error.new(pos, "expected at least 1 argument") end
        local res = a:copy()
        for i, arg in ipairs(args) do
            res.value = res.value or arg.value
        end
        return { res }
    end),
    ---@param evaluator Evaluator
    ---@param pos Position
    ["do"] = Value.new("function", function(evaluator, pos)
        local closure, args = evaluator:arg(1), evaluator:args(2)
        if not closure then return nil, Error.new(pos, "expected at least 1 argument") end
        if closure.type ~= "closure" then return nil, Error.new(pos, "expected &1 to be of type closure, got " .. closure.type) end
        evaluator:pushArgs(args)
        evaluator:enterClosure(closure.value)
        return {}, true
    end),
    ---@param evaluator Evaluator
    ---@param pos Position
    ["set"] = Value.new("function", function(evaluator, pos)
        local key, value = evaluator:arg(1), evaluator:arg(2)
        if not key then return nil, Error.new(pos, "expected at least 1 argument") end
        if key.type ~= "key" then return nil, Error.new(pos, "expected &1 to be of type key, got " .. key.type) end
        evaluator.vars[key.value] = value
        return {}
    end),
    ---@param evaluator Evaluator
    ---@param pos Position
    ["get"] = Value.new("function", function(evaluator, pos)
        local key = evaluator:arg(1)
        if not key then return nil, Error.new(pos, "expected at least 1 argument") end
        if key.type ~= "key" then return nil, Error.new(pos, "expected &1 to be of type key, got " .. key.type) end
        return { evaluator.vars[key.value] }
    end),
    ---@param evaluator Evaluator
    ---@param pos Position
    ["?"] = Value.new("function", function(evaluator, pos)
        local cond, case, elseCase = evaluator:arg(1), evaluator:arg(2), evaluator:arg(3)
        if not cond then return nil, Error.new(pos, "expected at least 3 argument") end
        if not case then return nil, Error.new(pos, "expected at least 3 argument") end
        if not elseCase then return nil, Error.new(pos, "expected at least 3 argument") end
        if cond.type ~= "boolean" then return nil, Error.new(pos, "expected &1 to be of type boolean, got " .. cond.type) end
        return { cond.value and case or elseCase }
    end),
}
---@param self Evaluator
function Evaluator:debug(label)
    if not label then label = "DEBUG" end
    local s = "[" .. label .. "]\nstack: "
    local stack = {}
    for i, value in pairs(self.stack) do
        stack[i] = value.type .. "(" .. value:tostring() .. ")"
    end
    s = s .. table.concat(stack, ", ") .. "\n"
    s = s .. "args stack:\n"
    local argsStack = {}
    for i, args in pairs(self.argsStack) do
        local args_ = {}
        for j, value in pairs(args) do
            args_[j] = value.type .. "(" .. value:tostring() .. ")"
        end
        argsStack[i] = "\t" .. tostring(i) .. ": " .. table.concat(args_, ", ")
    end
    s = s .. table.concat(argsStack, "\n") .. "\n"
    s = s .. "vars: "
    local vars = {}
    for key, value in pairs(self.vars) do
        if not Evaluator.stdVars[key] then
            vars[#vars + 1] = key .. ": " .. value.type .. "(" .. value:tostring() .. ")"
        end
    end
    s = s .. table.concat(vars, ", ") .. "\n"
    -- s = s .. "closures:\n"
    -- local closures = {}
    -- for i, closure in pairs(self.closures) do
    --     closures[i] = "\t" .. i .. ": " .. ByteCode.codeToString(closure)
    -- end
    -- s = s .. table.concat(closures, "\n")
    return s
end

return {
    Value = Value,
    Evaluator = Evaluator,
    eval = function(closures, constants, args)
        if args then
            for i, arg in ipairs(args) do
                args[i] = Value.from(arg)
            end
        end
        return Evaluator.new(closures, constants, args):run()
    end,
}
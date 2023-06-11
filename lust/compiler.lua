local ByteCode = {
    None = 0,
    Null = 1,
    Boolean = 2, -- [0 or 1]
    Number = 3, -- [numberAddr]
    String = 4, -- [stringAddr]
    Word = 5, -- [stringAddr]
    Eval = 6, -- [argCount]
    List = 7, -- [argCount]
    Key = 8,
    Arg = 9,
    Closure = 10, -- [closureAddr]
}
function ByteCode.tostring(byte)
    if byte == ByteCode.None then
        return "None"
    elseif byte == ByteCode.Null then
        return "Null"
    elseif byte == ByteCode.Boolean then
        return "Boolean", true
    elseif byte == ByteCode.Number then
        return "Number", true
    elseif byte == ByteCode.String then
        return "String", true
    elseif byte == ByteCode.Word then
        return "Word", true
    elseif byte == ByteCode.Eval then
        return "Eval", true
    elseif byte == ByteCode.List then
        return "List", true
    elseif byte == ByteCode.Key then
        return "Key"
    elseif byte == ByteCode.Arg then
        return "Arg"
    elseif byte == ByteCode.Closure then
        return "Closure", true
    else
        return "Unknown"
    end
end
function ByteCode.codeToString(code)
    local bytes = {}
    local idx = 1
    while idx <= #code do
        bytes[#bytes + 1], nextNumber = ByteCode.tostring(code[idx])
        idx = idx + 1
        if nextNumber then
            bytes[#bytes] = bytes[#bytes] .. "(" .. tostring(code[idx]) .. ")"
            idx = idx + 1
        end
    end
    return table.concat(bytes, ", ")
end

local Compiler = {
    mt = {
        __name = "compiler"
    }
}
function Compiler.new()
    ---@class Compiler
    return setmetatable({
        ---@class Constants
        constants = {
            number = {},
            string = {},
        },
        ---@type table<integer, table<integer, integer>>
        closures = {{}},
        pointer = 1,
        write = Compiler.write,
        number = Compiler.number,
        string = Compiler.string,
        closure = Compiler.closure,
        compileNodes = Compiler.compileNodes,
        compileNode = Compiler.compileNode,
        compile = Compiler.compile,
    }, Compiler.mt)
end
---@param self Compiler
function Compiler:write(bytes)
    for _, byte in ipairs(bytes) do
        self.closures[self.pointer][#self.closures[self.pointer] + 1] = byte
    end
end
---@param self Compiler
function Compiler:number(value)
    local constants = self.constants.number
    local addr = constants[value]
    if not addr then
        addr = #constants + 1
        constants[addr] = value
        constants[value] = addr
    end
    return addr
end
---@param self Compiler
function Compiler:string(value)
    local constants = self.constants.string
    local addr = constants[value]
    if not addr then
        addr = #constants + 1
        constants[addr] = value
        constants[value] = addr
    end
    return addr
end
---@param self Compiler
---@param node Node
function Compiler:closure(node)
    local addr = #self.closures + 1
    self.closures[addr] = {}
    local oldPointer = self.pointer
    self.pointer = addr
    self:compileNode(node)
    self.pointer = oldPointer
    return addr
end
---@param self Compiler
function Compiler:compileNodes(nodes)
    for _, node in ipairs(nodes) do
        self:compileNode(node)
    end
end
---@param self Compiler
---@param node Node
function Compiler:compileNode(node)
    local kind = node.kind
    if kind == "null-node" then
        self:write { ByteCode.Null }
    elseif kind == "number-node" then
        self:write { ByteCode.Number, self:number(node.value) }
    elseif kind == "boolean-node" then
        self:write { ByteCode.Boolean, node.value and 1 or 0 }
    elseif kind == "string-node" then
        self:write { ByteCode.String, self:string(node.value) }
    elseif kind == "word-node" then
        self:write { ByteCode.Word, self:string(node.word) }
    elseif kind == "expression-node" then
        self:compileNodes(node.nodes)
        self:write { ByteCode.Eval, #node.nodes - 1 }
    elseif kind == "list-node" then
        self:compileNodes(node.nodes)
        self:write { ByteCode.List, #node.nodes }
    elseif kind == "body-node" then
        self:compileNodes(node.nodes)
        self:write { ByteCode.List, #node.nodes }
    elseif kind == "key-node" then
        self:compileNode(node.node)
        self:write { ByteCode.Key }
    elseif kind == "argument-node" then
        self:compileNode(node.node)
        self:write { ByteCode.Arg }
    elseif kind == "closure-node" then
        self:write { ByteCode.Closure, self:closure(node.node) }
    else
        error("unknown node kind: " .. kind)
    end
end
---@param self Compiler
function Compiler:compile(nodes)
    self:compileNodes(nodes)
    return self.closures, self.constants
end

return {
    ByteCode = ByteCode,
    Compiler = Compiler,
    compile = function(nodes)
        return Compiler.new():compile(nodes)
    end
}
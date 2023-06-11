local position = require "lust.position"
local Position, Error = position.Position, position.Error

local NullNode = {
    mt = {
        __name = "null-node",
        __tostring = function(self)
            return "null"
        end
    }
}
---@param pos Position
---@return NullNode
function NullNode.new(pos)
    ---@class NullNode
    return setmetatable({
        kind = NullNode.mt.__name,
        pos = pos
    }, NullNode.mt)
end
local NumberNode = {
    mt = {
        __name = "number-node",
        __tostring = function(self)
            return tostring(self.value)
        end
    }
}
---@param pos Position
---@param value number
---@return NumberNode
function NumberNode.new(pos, value)
    ---@class NumberNode
    return setmetatable({
        kind = NumberNode.mt.__name,
        pos = pos,
        value = value
    }, NumberNode.mt)
end
local BooleanNode = {
    mt = {
        __name = "boolean-node",
        __tostring = function(self)
            return tostring(self.value)
        end
    }
}
---@param pos Position
---@param value boolean
---@return BooleanNode
function BooleanNode.new(pos, value)
    ---@class BooleanNode
    return setmetatable({
        kind = BooleanNode.mt.__name,
        pos = pos,
        value = value
    }, BooleanNode.mt)
end
local StringNode = {
    mt = {
        __name = "string-node",
        __tostring = function(self)
            return string.format("%q", self.value)
        end
    }
}
---@param pos Position
---@param value string
---@return StringNode
function StringNode.new(pos, value)
    ---@class StringNode
    return setmetatable({
        kind = StringNode.mt.__name,
        pos = pos,
        value = value
    }, StringNode.mt)
end
local WordNode = {
    mt = {
        __name = "word-node",
        __tostring = function(self)
            return self.word
        end
    }
}
---@param pos Position
---@param word string
---@return WordNode
function WordNode.new(pos, word)
    ---@class WordNode
    return setmetatable({
        kind = WordNode.mt.__name,
        pos = pos,
        word = word
    }, WordNode.mt)
end
local ExpressionNode = {
    mt = {
        __name = "expression-node",
        __tostring = function(self)
            local str = "("
            for i, node in ipairs(self.nodes) do
                if i > 1 and i <= #self.nodes then str = str .. " " end
                str = str .. tostring(node)
            end
            return str .. ")"
        end
    }
}
---@param pos Position
---@param nodes Node[]
---@return ExpressionNode
function ExpressionNode.new(pos, nodes)
    ---@class ExpressionNode
    return setmetatable({
        kind = ExpressionNode.mt.__name,
        pos = pos,
        nodes = nodes
    }, ExpressionNode.mt)
end
local ListNode = {
    mt = {
        __name = "list-node",
        __tostring = function(self)
            local str = "["
            for i, node in ipairs(self.nodes) do
                if i > 1 and i <= #self.nodes then str = str .. " " end
                str = str .. tostring(node)
            end
            return str .. "]"
        end
    }
}
---@param pos Position
---@param nodes Node[]
---@return ListNode
function ListNode.new(pos, nodes)
    ---@class ListNode
    return setmetatable({
        kind = ListNode.mt.__name,
        pos = pos,
        nodes = nodes
    }, ListNode.mt)
end
local BodyNode = {
    mt = {
        __name = "body-node",
        __tostring = function(self)
            local str = "{"
            for i, node in ipairs(self.nodes) do
                if i > 1 and i <= #self.nodes then str = str .. " " end
                str = str .. tostring(node)
            end
            return str .. "}"
        end
    }
}
---@param pos Position
---@param nodes Node[]
---@return BodyNode
function BodyNode.new(pos, nodes)
    ---@class BodyNode
    return setmetatable({
        kind = BodyNode.mt.__name,
        pos = pos,
        nodes = nodes
    }, BodyNode.mt)
end
local KeyNode = {
    mt = {
        __name = "key-node",
        __tostring = function(self)
            return "@" .. tostring(self.node)
        end
    }
}
---@param pos Position
---@param node Node
---@return KeyNode
function KeyNode.new(pos, node)
    ---@class KeyNode
    return setmetatable({
        kind = KeyNode.mt.__name,
        pos = pos,
        node = node
    }, KeyNode.mt)
end
local ArgumentNode = {
    mt = {
        __name = "argument-node",
        __tostring = function(self)
            return "&" .. tostring(self.node)
        end
    }
}
---@param pos Position
---@param node Node
---@return ArgumentNode
function ArgumentNode.new(pos, node)
    ---@class ArgumentNode
    return setmetatable({
        kind = ArgumentNode.mt.__name,
        pos = pos,
        node = node
    }, ArgumentNode.mt)
end
local ClosureNode = {
    mt = {
        __name = "closure-node",
        __tostring = function(self)
            return "#" .. tostring(self.node)
        end
    }
}
---@param pos Position
---@param node Node
---@return ClosureNode
function ClosureNode.new(pos, node)
    ---@class ClosureNode
    return setmetatable({
        kind = ClosureNode.mt.__name,
        pos = pos,
        node = node
    }, ClosureNode.mt)
end

---@alias Node NullNode|NumberNode|BooleanNode|StringNode|WordNode|ExpressionNode|ListNode|BodyNode|KeyNode|ArgumentNode|ClosureNode

local Scanner = {
    mt = {
        __name = "scanner"
    }
}
---@param file File
---@param code string
function Scanner.new(file, code)
    ---@class Scanner
    return setmetatable({
        file = file,
        pos = Position.new(file, 1, 1),
        code = code,
        index = 1,

        peek = Scanner.peek,
        next = Scanner.next,
        word = Scanner.word,
        skipWhitespace = Scanner.skipWhitespace,
        readString = Scanner.readString,
        readNumber = Scanner.readNumber,
        readWord = Scanner.readWord,
        readExpression = Scanner.readExpression,
        readList = Scanner.readList,
        readBody = Scanner.readBody,
        readKey = Scanner.readKey,
        readArgument = Scanner.readArgument,
        readClosure = Scanner.readClosure,
        nodes = Scanner.nodes,
        node = Scanner.node,
    }, Scanner.mt)
end
---@return string
function Scanner:peek()
    return self.code:sub(self.index, self.index)
end
---@param self Scanner
---@return string
function Scanner:next()
    local char = self:peek()
    self.index = self.index + 1
    if char == "\n" then
        self.pos.line = self.pos.line + 1
        self.pos.column = 1
    else
        self.pos.column = self.pos.column + 1
    end
    return char
end
---@param self Scanner
---@param char string
---@return boolean
function Scanner:word(char)
    return char ~= "" and char ~= " " and char ~= "\t" and char ~= "\r" and char ~= "\n" and char ~= "(" and char ~= ")" and char ~= "{" and char ~= "}" and char ~= "[" and char ~= "]" and char ~= "\"" and char ~= "'"
end
---@param self Scanner
function Scanner:skipWhitespace()
    local char = self:peek()
    while char == " " or char == "\t" or char == "\r" or char == "\n" do
        self:next()
        char = self:peek()
    end
end
---@param self Scanner
function Scanner:readString()
    local pos = self.pos:copy()
    local char = self:next()
    local str = ""
    while char ~= "\"" do
        if char == "\\" then
            local epos = self.pos:copy()
            pos:extend(self.pos)
            char = self:next()
            if char == "n" then
                str = str .. "\n"
            elseif char == "t" then
                str = str .. "\t"
            elseif char == "\"" then
                str = str .. "\""
            elseif char == "\\" then
                str = str .. "\\"
            else
                return nil, Error.new(epos, "invalid escape sequence")
            end
        else
            str = str .. char
        end
        pos:extend(self.pos)
        char = self:next()
    end
    return StringNode.new(pos, str)
end
---@param self Scanner
function Scanner:readNumber()
    local pos = self.pos:copy()
    local char = self:peek()
    local str = ""
    while char >= "0" and char <= "9" do
        char = self:next()
        str = str .. char
        pos:extend(self.pos)
        char = self:peek()
    end
    if char == "." then
        char = self:next()
        str = str .. char
        pos:extend(self.pos)
        char = self:peek()
        while char >= "0" and char <= "9" do
            char = self:next()
            str = str .. char
            pos:extend(self.pos)
            char = self:peek()
        end
    end
    local value = tonumber(str)
    if value == nil then
        return nil, Error.new(pos, "invalid number")
    end
    return NumberNode.new(pos, value)
end
---@param self Scanner
function Scanner:readWord()
    local pos = self.pos:copy()
    local char = self:peek()
    local str = ""
    while self:word(char) do
        char = self:next()
        str = str .. char
        pos:extend(self.pos)
        char = self:peek()
    end
    return WordNode.new(pos, str)
end
---@param self Scanner
function Scanner:readExpression()
    local pos = self.pos:copy()
    local nodes = {}
    self:next() self:skipWhitespace()
    local char = self:peek()
    while char ~= ")" do
        local node, err = self:node() if err then return nil, err end
        if node == nil then
            return nil, Error.new(pos, "invalid expression")
        end
        table.insert(nodes, node)
        self:skipWhitespace()
        char = self:peek()
    end
    char = self:next()
    return ExpressionNode.new(pos, nodes)
end
---@param self Scanner
function Scanner:readList()
    local pos = self.pos:copy()
    local nodes = {}
    self:next() self:skipWhitespace()
    local char = self:peek()
    while char ~= "]" do
        local node, err = self:node() if err then return nil, err end
        if node == nil then
            return nil, Error.new(pos, "invalid list")
        end
        table.insert(nodes, node)
        self:skipWhitespace()
        char = self:peek()
    end
    self:next()
    return ListNode.new(pos, nodes)
end
---@param self Scanner
function Scanner:readBody()
    local pos = self.pos:copy()
    local nodes = {}
    self:next() self:skipWhitespace()
    local char = self:peek()
    while char ~= "}" do
        local node, err = self:node() if err then return nil, err end
        if node == nil then
            return nil, Error.new(pos, "invalid body")
        end
        table.insert(nodes, node)
        self:skipWhitespace()
        char = self:peek()
    end
    self:next()
    return BodyNode.new(pos, nodes)
end
---@param self Scanner
function Scanner:readKey()
    local pos = self.pos:copy()
    self:next() self:skipWhitespace()
    local node, err = self:node() if err then return nil, err end
    if node == nil then
        return nil, Error.new(pos, "invalid key")
    end
    return KeyNode.new(pos, node)
end
---@param self Scanner
function Scanner:readArgument()
    local pos = self.pos:copy()
    self:next()
    local node, err = self:node() if err then return nil, err end
    if node == nil then
        return nil, Error.new(pos, "invalid argument")
    end
    return ArgumentNode.new(pos, node)
end
---@param self Scanner
function Scanner:readClosure()
    local pos = self.pos:copy()
    self:next()
    local node, err = self:node() if err then return nil, err end
    if node == nil then
        return nil, Error.new(pos, "invalid closure")
    end
    return ClosureNode.new(pos, node)
end
---@param self Scanner
function Scanner:node()
    self:skipWhitespace()
    local char = self:peek()
    if char == "" then return end
    if char == ")" or char == "]" or char == "}" then
        return nil, Error.new(self.pos, ("unexpected symbol %q"):format(char))
    end
    if char == "(" then
        return self:readExpression()
    elseif char == "[" then
        return self:readList()
    elseif char == "{" then
        return self:readBody()
    elseif char == "\"" then
        return self:readString()
    elseif char == "@" then
        return self:readKey()
    elseif char == "&" then
        return self:readArgument()
    elseif char == "#" then
        return self:readClosure()
    elseif char >= "0" and char <= "9" then
        return self:readNumber()
    else
        local node = self:readWord()
        if node ~= nil then
            return node
        end
        node = self:readWord()
        if node ~= nil then
            return node
        end
        return
    end
end
---@param self Scanner
function Scanner:nodes()
    local nodes = {}
    local node, err = self:node() if err then return nil, err end
    while node ~= nil do
        table.insert(nodes, node)
        node, err = self:node() if err then return nil, err end
    end
    return nodes
end

return {
    NullNode = NullNode,
    NumberNode = NumberNode,
    BooleanNode = BooleanNode,
    StringNode = StringNode,
    WordNode = WordNode,
    ExpressionNode = ExpressionNode,
    ListNode = ListNode,
    BodyNode = BodyNode,
    KeyNode = KeyNode,
    ArgumentNode = ArgumentNode,
    ClosureNode = ClosureNode,
    Scanner = Scanner,
    scan = function (file, code)
        local scanner = Scanner.new(file, code)
        return scanner:nodes()
    end
}
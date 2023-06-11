local File = {
    mt = {
        __name = "file"
    }
}
---@param path string
---@return File
function File.new(path)
    ---@class File
    return setmetatable({
        path = path
    }, File.mt)
end

local Position = {
    mt = {
        __name = "position"
    }
}
---@param file File
---@param line integer
---@param column integer
---@return Position
function Position.new(file, line, column)
    ---@class Position
    return setmetatable({
        file = file,
        line = line,
        column = column,
        copy = Position.copy,
        extend = Position.extend
    }, Position.mt)
end
---@param self Position
---@return Position
function Position:copy()
    return Position.new(self.file, self.line, self.column)
end
---@param self Position
---@param other Position
function Position:extend(other)
    if other.file ~= self.file then
        error("cannot extend position with different file")
    end
    if other.line < self.line then
        error("cannot extend position with smaller line")
    end
    if other.line == self.line and other.column < self.column then
        error("cannot extend position with smaller column")
    end
    self.line = other.line
    self.column = other.column
end

local Error = {
    mt = {
        __name = "error",
        __tostring = function(self)
            return string.format(
                "%s%d:%d: %s",
                self.pos.file and self.pos.file.path..":" or "",
                self.pos.line, self.pos.column,
                self.message
            )
        end
    }
}
---@param pos Position
---@param message string
---@return Error
function Error.new(pos, message)
    ---@class Error
    return setmetatable({
        pos = pos,
        message = message
    }, Error.mt)
end

return {
    File = File,
    Position = Position,
    Error = Error
}
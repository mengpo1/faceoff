local InputConfig = {}
InputConfig.__index = InputConfig

local function cloneBindings(bindings)
    local output = {}

    for action, keys in pairs(bindings or {}) do
        output[action] = {}

        for _, key in ipairs(keys) do
            table.insert(output[action], key)
        end
    end

    return output
end

function InputConfig.new(bindings)
    local self = setmetatable({}, InputConfig)

    self.bindings = cloneBindings(bindings or {
        up = { "up" },
        down = { "down" },
        left = { "left" },
        right = { "right" },
    })

    return self
end

function InputConfig:setBinding(action, keys)
    self.bindings[action] = {}

    for _, key in ipairs(keys or {}) do
        table.insert(self.bindings[action], key)
    end
end

function InputConfig:setBindings(bindings)
    self.bindings = cloneBindings(bindings or {})
end

function InputConfig:getBindings()
    return cloneBindings(self.bindings)
end

function InputConfig:addKey(action, key)
    self.bindings[action] = self.bindings[action] or {}

    for _, existingKey in ipairs(self.bindings[action]) do
        if existingKey == key then
            return
        end
    end

    table.insert(self.bindings[action], key)
end

function InputConfig:isActionPressed(action)
    local keys = self.bindings[action] or {}

    for _, key in ipairs(keys) do
        if love.keyboard.isDown(key) then
            return true
        end
    end

    return false
end

function InputConfig:getDirection()
    local direction = { x = 0, y = 0 }

    if self:isActionPressed("up") then
        direction.y = direction.y - 1
    end

    if self:isActionPressed("down") then
        direction.y = direction.y + 1
    end

    if self:isActionPressed("left") then
        direction.x = direction.x - 1
    end

    if self:isActionPressed("right") then
        direction.x = direction.x + 1
    end

    return direction
end

function InputConfig:getBindingLabel(action)
    return table.concat(self.bindings[action] or {}, "/")
end

return InputConfig

local Player = {}
Player.__index = Player

local function clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

function Player.new(props)
    local self = setmetatable({}, Player)

    self.x = props.x or 0
    self.y = props.y or 0
    self.size = props.size or 32
    self.speed = props.speed or 220
    self.color = props.color or { 0.9, 0.2, 0.2 }

    return self
end

function Player:update(dt, direction, room)
    local dx = direction.x
    local dy = direction.y

    if dx ~= 0 and dy ~= 0 then
        local normalizer = math.sqrt(2)
        dx = dx / normalizer
        dy = dy / normalizer
    end

    self.x = self.x + dx * self.speed * dt
    self.y = self.y + dy * self.speed * dt

    self:clampToRoom(room)
end

function Player:clampToRoom(room)
    local bounds = room:getInnerBounds(self.size, self.size)

    self.x = clamp(self.x, bounds.minX, bounds.maxX)
    self.y = clamp(self.y, bounds.minY, bounds.maxY)
end

function Player:draw()
    love.graphics.setColor(self.color)
    love.graphics.rectangle("fill", self.x, self.y, self.size, self.size)
end

return Player

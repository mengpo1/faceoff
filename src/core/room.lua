local Room = {}
Room.__index = Room

function Room.new(props)
    local self = setmetatable({}, Room)

    self.x = props.x or 0
    self.y = props.y or 0
    self.width = props.width or 800
    self.height = props.height or 600
    self.backgroundColor = props.backgroundColor or { 0.12, 0.12, 0.16 }
    self.borderColor = props.borderColor or { 0.65, 0.65, 0.75 }

    return self
end

function Room:getInnerBounds(entityWidth, entityHeight)
    return {
        minX = self.x,
        minY = self.y,
        maxX = self.x + self.width - entityWidth,
        maxY = self.y + self.height - entityHeight,
    }
end

function Room:draw()
    love.graphics.setColor(self.backgroundColor)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)

    love.graphics.setColor(self.borderColor)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
end

return Room

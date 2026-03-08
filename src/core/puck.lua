-- Palet autonome: déplacement inertiel, friction et rebonds sur les limites de salle.
local Puck = {}
Puck.__index = Puck

function Puck.new(config)
    local self = setmetatable({}, Puck)

    self.radius = config.radius or 14
    self.x = config.x or 0
    self.y = config.y or 0
    self.vx = config.vx or 260
    self.vy = config.vy or -180
    self.friction = config.friction or 0.992
    self.restitution = config.restitution or 0.92
    self.color = config.color or { 0.95, 0.95, 0.2 }

    return self
end

function Puck:resetToCenter(room)
    self.x = room.x + (room.width * 0.5)
    self.y = room.y + (room.height * 0.5)
    self.vx = 260
    self.vy = -180
end

function Puck:clampToRoom(room)
    local ellipse = room:getInnerEllipse(self.radius * 2, self.radius * 2)
    local offsetX = self.x - ellipse.centerX
    local offsetY = self.y - ellipse.centerY

    local normalizedX = offsetX / ellipse.radiusX
    local normalizedY = offsetY / ellipse.radiusY
    local distanceSq = (normalizedX * normalizedX) + (normalizedY * normalizedY)

    if distanceSq <= 1 then
        return
    end

    local distance = math.sqrt(distanceSq)
    self.x = ellipse.centerX + ((normalizedX / distance) * ellipse.radiusX)
    self.y = ellipse.centerY + ((normalizedY / distance) * ellipse.radiusY)
end

function Puck:update(dt, room)
    self.x = self.x + (self.vx * dt)
    self.y = self.y + (self.vy * dt)

    local ellipse = room:getInnerEllipse(self.radius * 2, self.radius * 2)
    local offsetX = self.x - ellipse.centerX
    local offsetY = self.y - ellipse.centerY
    local normalizedX = offsetX / ellipse.radiusX
    local normalizedY = offsetY / ellipse.radiusY
    local distanceSq = (normalizedX * normalizedX) + (normalizedY * normalizedY)

    if distanceSq > 1 then
        local distance = math.sqrt(distanceSq)

        self.x = ellipse.centerX + ((normalizedX / distance) * ellipse.radiusX)
        self.y = ellipse.centerY + ((normalizedY / distance) * ellipse.radiusY)

        local normalX = (self.x - ellipse.centerX) / (ellipse.radiusX * ellipse.radiusX)
        local normalY = (self.y - ellipse.centerY) / (ellipse.radiusY * ellipse.radiusY)
        local normalLength = math.sqrt((normalX * normalX) + (normalY * normalY))

        if normalLength > 0 then
            normalX = normalX / normalLength
            normalY = normalY / normalLength

            local dot = (self.vx * normalX) + (self.vy * normalY)
            self.vx = (self.vx - (2 * dot * normalX)) * self.restitution
            self.vy = (self.vy - (2 * dot * normalY)) * self.restitution
        end
    end

    self.vx = self.vx * self.friction
    self.vy = self.vy * self.friction
end

function Puck:draw()
    love.graphics.setColor(self.color)
    love.graphics.circle("fill", self.x, self.y, self.radius)
end

return Puck

-- Salle de jeu: dimensions, bornes de déplacement et rendu du décor.
local Room = {}
Room.__index = Room

-- Construit une salle depuis les propriétés passées en argument.
function Room.new(props)
    local self = setmetatable({}, Room)

    self.x = props.x or 0
    self.y = props.y or 0
    self.width = props.width or 800
    self.height = props.height or 600
    self.backgroundColor = props.backgroundColor or { 0.12, 0.12, 0.16 }
    self.borderColor = props.borderColor or { 0.65, 0.65, 0.75 }

    -- Paramètres de stries horizontales pour donner une sensation de déplacement.
    self.stripeSpacing = props.stripeSpacing or 60
    self.stripeThickness = props.stripeThickness or 20
    self.stripeDark = props.stripeDark or { 0.2, 0.2, 0.22, 0.16 }
    self.stripeLight = props.stripeLight or { 0.32, 0.32, 0.35, 0.1 }

    return self
end

-- Renvoie les limites de déplacement disponibles pour une entité donnée.
function Room:getInnerBounds(entityWidth, entityHeight)
    return {
        minX = self.x,
        minY = self.y,
        maxX = self.x + self.width - entityWidth,
        maxY = self.y + self.height - entityHeight,
    }
end

-- Dessine le fond de la salle et sa bordure.
function Room:draw()
    love.graphics.setColor(self.backgroundColor)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)

    -- Stries fixes (non animées) avec hauteur marquée pour un rendu plus lisible.
    local stripePeriod = math.max(1, self.stripeSpacing)

    love.graphics.setScissor(self.x, self.y, self.width, self.height)

    local startY = self.y
    local maxY = self.y + self.height
    local rowIndex = 0

    for y = startY, maxY, stripePeriod do
        local color = (rowIndex % 2 == 0) and self.stripeDark or self.stripeLight
        love.graphics.setColor(color)
        love.graphics.rectangle("fill", self.x, y, self.width, self.stripeThickness)
        rowIndex = rowIndex + 1
    end

    love.graphics.setScissor()

    love.graphics.setColor(self.borderColor)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
end

return Room

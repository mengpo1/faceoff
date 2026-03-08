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

-- Renvoie les paramètres de l'ellipse interne en tenant compte de la taille d'une entité.
function Room:getInnerEllipse(entityWidth, entityHeight)
    local centerX = self.x + (self.width * 0.5)
    local centerY = self.y + (self.height * 0.5)
    local radiusX = math.max(1, (self.width * 0.5) - (entityWidth * 0.5))
    local radiusY = math.max(1, (self.height * 0.5) - (entityHeight * 0.5))

    return {
        centerX = centerX,
        centerY = centerY,
        radiusX = radiusX,
        radiusY = radiusY,
    }
end

-- Dessine le fond de la salle et sa bordure.
function Room:draw()
    love.graphics.setColor(self.backgroundColor)
    love.graphics.ellipse(
        "fill",
        self.x + (self.width * 0.5),
        self.y + (self.height * 0.5),
        self.width * 0.5,
        self.height * 0.5
    )

    -- Stries fixes (non animées) avec hauteur marquée pour un rendu plus lisible.
    local stripePeriod = math.max(1, self.stripeSpacing)

    love.graphics.stencil(function()
        love.graphics.ellipse(
            "fill",
            self.x + (self.width * 0.5),
            self.y + (self.height * 0.5),
            self.width * 0.5,
            self.height * 0.5
        )
    end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)

    local startY = self.y
    local maxY = self.y + self.height
    local rowIndex = 0

    for y = startY, maxY, stripePeriod do
        local color = (rowIndex % 2 == 0) and self.stripeDark or self.stripeLight
        love.graphics.setColor(color)
        love.graphics.rectangle("fill", self.x, y, self.width, self.stripeThickness)
        rowIndex = rowIndex + 1
    end

    love.graphics.setStencilTest()

    love.graphics.setColor(self.borderColor)
    love.graphics.setLineWidth(3)
    love.graphics.ellipse(
        "line",
        self.x + (self.width * 0.5),
        self.y + (self.height * 0.5),
        self.width * 0.5,
        self.height * 0.5
    )
end

return Room

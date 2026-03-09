-- Salle de jeu: dimensions, bornes de déplacement et rendu du décor.
local Room = {}
Room.__index = Room

Room.GOAL_TOP = "top"
Room.GOAL_BOTTOM = "bottom"

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

    self.goalWidthRatio = props.goalWidthRatio or 0.26
    self.goalDepth = props.goalDepth or 36
    self.goalColor = props.goalColor or { 0.95, 0.95, 0.95, 0.4 }

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


function Room:getGoalZones()
    local goalWidth = self.width * self.goalWidthRatio
    local goalX = self.x + ((self.width - goalWidth) * 0.5)

    local topGoal = {
        x = goalX,
        y = self.y - self.goalDepth,
        width = goalWidth,
        height = self.goalDepth,
    }

    local bottomGoal = {
        x = goalX,
        y = self.y + self.height,
        width = goalWidth,
        height = self.goalDepth,
    }

    return {
        [Room.GOAL_TOP] = topGoal,
        [Room.GOAL_BOTTOM] = bottomGoal,
    }
end

function Room:drawGoals()
    local goals = self:getGoalZones()
    love.graphics.setColor(self.goalColor)
    love.graphics.rectangle("fill", goals[Room.GOAL_TOP].x, goals[Room.GOAL_TOP].y, goals[Room.GOAL_TOP].width, goals[Room.GOAL_TOP].height)
    love.graphics.rectangle("fill", goals[Room.GOAL_BOTTOM].x, goals[Room.GOAL_BOTTOM].y, goals[Room.GOAL_BOTTOM].width, goals[Room.GOAL_BOTTOM].height)
end

-- Dessine le fond de la salle et sa bordure.
function Room:draw()
    local centerX = self.x + (self.width * 0.5)
    local centerY = self.y + (self.height * 0.5)
    local radiusX = self.width * 0.5
    local radiusY = self.height * 0.5

    love.graphics.setColor(self.backgroundColor)
    love.graphics.ellipse("fill", centerX, centerY, radiusX, radiusY)

    -- Stries fixes (non animées) avec hauteur marquée pour un rendu plus lisible.
    -- On évite le stencil ici pour rester compatible avec le rendu sur Canvas sans stencil buffer.
    local stripePeriod = math.max(1, self.stripeSpacing)
    local startY = self.y
    local maxY = self.y + self.height
    local rowIndex = 0

    for y = startY, maxY, stripePeriod do
        local stripeHeight = math.min(self.stripeThickness, maxY - y)
        if stripeHeight > 0 then
            local stripeCenterY = y + (stripeHeight * 0.5)
            local normalizedY = (stripeCenterY - centerY) / radiusY

            if math.abs(normalizedY) <= 1 then
                local halfWidth = radiusX * math.sqrt(1 - (normalizedY * normalizedY))
                local color = (rowIndex % 2 == 0) and self.stripeDark or self.stripeLight
                love.graphics.setColor(color)
                love.graphics.rectangle("fill", centerX - halfWidth, y, halfWidth * 2, stripeHeight)
            end
        end

        rowIndex = rowIndex + 1
    end

    self:drawGoals()

    love.graphics.setColor(self.borderColor)
    love.graphics.setLineWidth(3)
    love.graphics.ellipse("line", centerX, centerY, radiusX, radiusY)
end

return Room

-- Etat de match léger: contient la salle, les entités et leur mise à jour/rendu.
-- Objectif: préparer l'ajout d'autres entités sans basculer sur une architecture lourde.
local MatchState = {}
MatchState.__index = MatchState

function MatchState.new(config)
    local self = setmetatable({}, MatchState)

    self.room = config.room
    self.entities = {}
    self.controlledEntity = nil

    for _, entity in ipairs(config.entities or {}) do
        self:addEntity(entity)
    end

    if config.controlledEntity then
        self:setControlledEntity(config.controlledEntity)
    else
        self.controlledEntity = self.entities[1]
    end

    return self
end

function MatchState:addEntity(entity)
    table.insert(self.entities, entity)
end

function MatchState:setControlledEntity(entity)
    self.controlledEntity = entity
end

function MatchState:getControlledEntity()
    return self.controlledEntity
end

-- Met à jour toutes les entités. La première version garde la logique actuelle du joueur.
function MatchState:update(dt, input, entityDirections)
    local controlledDirection = { x = 0, y = 0 }

    if input and self.controlledEntity then
        controlledDirection = input:getDirection()
    end

    for _, entity in ipairs(self.entities) do
        if entity.update then
            if entity == self.controlledEntity then
                entity:update(dt, controlledDirection, self.room)
            elseif entityDirections and entityDirections[entity] then
                entity:update(dt, entityDirections[entity], self.room)
            else
                entity:update(dt, self.room)
            end
        end
    end
end

function MatchState:drawTerrain()
    if self.room and self.room.draw then
        self.room:draw()
    end
end

function MatchState:drawEntities()
    for _, entity in ipairs(self.entities) do
        if entity.draw then
            entity:draw()
        end
    end
end

-- Point de reset basique pour garder le comportement prototype actuel.
function MatchState:reset(spawnPoints)
    local focusEntity = self.controlledEntity
    if focusEntity then
        local focusSpawn = spawnPoints[focusEntity] or spawnPoints[1]
        if focusSpawn then
            focusEntity.x = focusSpawn.x
            focusEntity.y = focusSpawn.y
        end

        if focusEntity.resetMotion then
            focusEntity:resetMotion()
        end
    end

    for _, entity in ipairs(self.entities) do
        if entity ~= focusEntity and spawnPoints[entity] then
            entity.x = spawnPoints[entity].x
            entity.y = spawnPoints[entity].y

            if entity.resetMotion then
                entity:resetMotion()
            end
        elseif entity ~= focusEntity and entity.resetToCenter then
            entity:resetToCenter(self.room)
        end
    end
end

return MatchState

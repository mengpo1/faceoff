-- Entité joueur: position, inertie, collision salle, rendu.
local Player = {}
Player.__index = Player

-- Utilitaire local de bornage numérique.
local function clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

-- Interpolation linéaire utilitaire (utilisée pour le contrôle de direction type hockey).
local function lerp(a, b, t)
    return a + (b - a) * t
end

-- Borne la norme du vecteur vitesse au maximum autorisé.
local function clampSpeed(vx, vy, maxSpeed)
    local speedSq = vx * vx + vy * vy
    local maxSpeedSq = maxSpeed * maxSpeed

    if speedSq <= maxSpeedSq then
        return vx, vy
    end

    local speed = math.sqrt(speedSq)
    local ratio = maxSpeed / speed
    return vx * ratio, vy * ratio
end

-- Normalise une direction d'entrée (8 directions + neutre).
local function normalizeDirection(dx, dy)
    if dx == 0 and dy == 0 then
        return 0, 0
    end

    local magnitude = math.sqrt(dx * dx + dy * dy)
    return dx / magnitude, dy / magnitude
end

-- Construit un joueur à partir des propriétés fournies.
function Player.new(props)
    local self = setmetatable({}, Player)

    self.x = props.x or 0
    self.y = props.y or 0
    self.size = props.size or 32

    -- Paramètres de glisse: accélération + inertie + vitesse max + contrôle de virage.
    self.accel = props.accel or 1300
    self.dragMoving = props.dragMoving or props.drag or 0.94
    self.dragIdle = props.dragIdle or props.drag or 0.985
    self.maxSpeed = props.maxSpeed or 340
    self.turnControl = props.turnControl or 10

    -- Paramètres reverse internes, sans table dédiée, pour garder un code plus simple.
    self.reverseBrakeDrag = 0.72
    self.reverseLockSpeed = 180
    self.reverseUnlockSpeed = 110
    self.reverseHardLockSpeed = 70
    self.reverseBrakeStrength = 6
    self.reverseSteerFactor = 0.12
    self.turn180Lock = false
    self.turn180Timer = 0
    self.turn180DirX = 0
    self.turn180DirY = 0

    -- Vitesse courante (persistante entre les frames).
    self.vx = props.vx or 0
    self.vy = props.vy or 0

    self.color = props.color or { 0.9, 0.2, 0.2 }

    return self
end

-- Réinitialise l'inertie (utile pour nouvelle partie/téléportation).
function Player:resetMotion()
    self.vx = 0
    self.vy = 0
end

-- Met à jour la position via accélération d'entrée + inertie + cap vitesse.
function Player:update(dt, direction, room)
    local prevVX = self.vx
    local prevVY = self.vy
    local prevSpeed = math.sqrt(prevVX * prevVX + prevVY * prevVY)

    local dirX, dirY = normalizeDirection(direction.x, direction.y)

    -- Input -> accélération : ax = accel * cos(dir), ay = accel * sin(dir).
    -- Ici cos/sin sont implicites car dirX/dirY est déjà unitaire.
    local ax = dirX * self.accel
    local ay = dirY * self.accel

    -- Drag différencié: en mouvement on conserve de la réactivité, au relâchement on glisse plus.
    local hasInput = dirX ~= 0 or dirY ~= 0

    local speedBefore = prevSpeed
    local vDirX, vDirY = 0, 0
    local opposition = 1

    if speedBefore > 0.0001 then
        vDirX = prevVX / speedBefore
        vDirY = prevVY / speedBefore
    end

    if hasInput and speedBefore > 0.0001 then
        opposition = (vDirX * dirX) + (vDirY * dirY)
    end

    local isOppositeInput = hasInput and speedBefore > 0.0001 and opposition < -0.6

    if (not self.turn180Lock) and isOppositeInput and speedBefore > self.reverseLockSpeed then
        self.turn180Lock = true
        self.turn180Timer = 4.0
        self.turn180DirX = dirX
        self.turn180DirY = dirY
    end

    if self.turn180Lock then
        self.turn180Timer = math.max(0, self.turn180Timer - dt)
        if self.turn180Timer <= 0 then
            self.turn180Lock = false
            self.turn180DirX = 0
            self.turn180DirY = 0
        end
    end

    local isReversing = self.turn180Lock

    local baseDrag = hasInput and self.dragMoving or self.dragIdle

    if isReversing and hasInput then
        local lockDot = (dirX * self.turn180DirX) + (dirY * self.turn180DirY)
        if lockDot > 0.8 and self.turn180Timer > 0 then
            -- Pendant le lock, aucune propulsion vers la direction 180 memorisee.
            ax = 0
            ay = 0
        end
    end

    local dragFactor = math.pow(baseDrag, dt * 60)

    -- Vitesse avec inertie: pv = pv * drag + a.
    self.vx = (self.vx * dragFactor) + (ax * dt)
    self.vy = (self.vy * dragFactor) + (ay * dt)

    if isReversing then
        local currentSpeed = math.sqrt(self.vx * self.vx + self.vy * self.vy)
        if currentSpeed > 0.0001 then
            local currentDirX = self.vx / currentSpeed
            local currentDirY = self.vy / currentSpeed

            -- Freinage actif oppose a la vitesse, proportionnel a la vitesse courante.
            local brakeDelta = self.reverseBrakeStrength * dt * currentSpeed
            self.vx = self.vx - currentDirX * brakeDelta
            self.vy = self.vy - currentDirY * brakeDelta
        end

        -- Drag reverse renforce, independant du framerate.
        local reverseDragFactor = math.pow(self.reverseBrakeDrag, dt * 60)
        self.vx = self.vx * reverseDragFactor
        self.vy = self.vy * reverseDragFactor
    end

    -- Contrôle "hockeyeur": on réaligne progressivement la trajectoire vers la direction voulue.
    if hasInput then
        local speed = math.sqrt(self.vx * self.vx + self.vy * self.vy)
        if speed > 0.0001 then
            local desiredVX = dirX * speed
            local desiredVY = dirY * speed

            -- Verrouille le demi-tour pendant le lock si l'input vise la direction 180 memorisee.
            if isReversing and self.turn180Timer > 0 then
                local lockDot = (dirX * self.turn180DirX) + (dirY * self.turn180DirY)
                if lockDot > 0.8 then
                    desiredVX = self.vx
                    desiredVY = self.vy
                end
            end

            local steer = clamp(self.turnControl * dt, 0, 1)
            if isReversing then
                steer = steer * self.reverseSteerFactor
            end

            self.vx = lerp(self.vx, desiredVX, steer)
            self.vy = lerp(self.vy, desiredVY, steer)
        end
    end

    -- Invariant anti inversion instantanee: pas de flip de direction sur une frame a haute vitesse.
    local newSpeed = math.sqrt(self.vx * self.vx + self.vy * self.vy)
    if prevSpeed >= 0.2 and newSpeed > 0.0001 then
        local dotFrame = ((prevVX * self.vx) + (prevVY * self.vy)) / (prevSpeed * newSpeed)
        if dotFrame < -0.2 then
            self.vx = 0
            self.vy = 0
        end
    end

    -- Cap de vitesse maximum.
    self.vx, self.vy = clampSpeed(self.vx, self.vy, self.maxSpeed)

    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt

    self:clampToRoom(room)
end

-- Contraint le joueur aux limites internes de la salle.
function Player:clampToRoom(room)
    local bounds = room:getInnerBounds(self.size, self.size)

    local clampedX = clamp(self.x, bounds.minX, bounds.maxX)
    local clampedY = clamp(self.y, bounds.minY, bounds.maxY)

    -- Coupe la vitesse sur l'axe en collision pour garder un contrôle propre.
    if clampedX ~= self.x then
        self.vx = 0
    end

    if clampedY ~= self.y then
        self.vy = 0
    end

    self.x = clampedX
    self.y = clampedY
end

-- Dessine le joueur sous forme de rectangle plein.
function Player:draw()
    love.graphics.setColor(self.color)
    love.graphics.rectangle("fill", self.x, self.y, self.size, self.size)
end

return Player

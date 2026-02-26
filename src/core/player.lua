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
    local dirX, dirY = normalizeDirection(direction.x, direction.y)

    -- Input -> accélération : ax = accel * cos(dir), ay = accel * sin(dir).
    -- Ici cos/sin sont implicites car dirX/dirY est déjà unitaire.
    local ax = dirX * self.accel
    local ay = dirY * self.accel

    -- Drag différencié: en mouvement on conserve de la réactivité, au relâchement on glisse plus.
    local hasInput = dirX ~= 0 or dirY ~= 0

    local speedBefore = math.sqrt(self.vx * self.vx + self.vy * self.vy)
    local isReversing = false

    if hasInput and speedBefore > 0.0001 then
        local dirVX = self.vx / speedBefore
        local dirVY = self.vy / speedBefore
        local alignment = (dirVX * dirX) + (dirVY * dirY)
        isReversing = alignment < -0.15
    end

    local baseDrag = hasInput and self.dragMoving or self.dragIdle
    if isReversing then
        -- Quand on pousse en sens opposé, on freine d'abord: pas d'inversion immédiate.
        baseDrag = math.min(baseDrag, self.reverseBrakeDrag)

        -- Tant que la vitesse n'a pas suffisamment chuté, on bloque l'accélération opposée.
        if speedBefore > self.reverseUnlockSpeed then
            ax = 0
            ay = 0
        end
    end

    local dragFactor = math.pow(baseDrag, dt * 60)

    -- Vitesse avec inertie: pv = pv * drag + a.
    self.vx = (self.vx * dragFactor) + (ax * dt)
    self.vy = (self.vy * dragFactor) + (ay * dt)

    if isReversing then
        -- Freinage actif supplémentaire pour rendre le reverse plus marqué et lisible.
        local brakeFactor = clamp(self.reverseBrakeStrength * dt, 0, 1)
        self.vx = self.vx * (1 - brakeFactor)
        self.vy = self.vy * (1 - brakeFactor)
    end

    -- Contrôle "hockeyeur": on réaligne progressivement la trajectoire vers la direction voulue.
    if hasInput then
        local speed = math.sqrt(self.vx * self.vx + self.vy * self.vy)
        if speed > 0.0001 then
            local desiredVX = dirX * speed
            local desiredVY = dirY * speed

            -- Verrouille le demi-tour tant que la vitesse reste élevée.
            if isReversing then
                if speed > self.reverseLockSpeed then
                    desiredVX = self.vx
                    desiredVY = self.vy
                elseif speed > self.reverseHardLockSpeed then
                    desiredVX = lerp(self.vx, desiredVX, 0.08)
                    desiredVY = lerp(self.vy, desiredVY, 0.08)
                end
            end

            local steer = clamp(self.turnControl * dt, 0, 1)
            if isReversing then
                steer = steer * self.reverseSteerFactor * 0.55
            end

            self.vx = lerp(self.vx, desiredVX, steer)
            self.vy = lerp(self.vy, desiredVY, steer)
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

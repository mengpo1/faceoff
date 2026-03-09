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

-- Ramène un angle en radians dans l'intervalle ]-pi, pi].
local function normalizeAngle(angle)
    return math.atan2(math.sin(angle), math.cos(angle))
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

    -- Vitesse courante (persistante entre les frames).
    self.vx = props.vx or 0
    self.vy = props.vy or 0

    self.color = props.color or { 0.9, 0.2, 0.2 }

    -- Direction de visée (mise à jour depuis la position souris en espace monde).
    self.aimAngle = props.aimAngle or 0
    self.aimDirX = math.cos(self.aimAngle)
    self.aimDirY = math.sin(self.aimAngle)

    -- Forward du joueur (utilisé pour contraindre le tir dans un cône frontal).
    self.forwardAngle = props.forwardAngle or self.aimAngle
    self.forwardDirX = math.cos(self.forwardAngle)
    self.forwardDirY = math.sin(self.forwardAngle)
    self.entityType = "player"
    self.team = props.team or "ally"
    self.role = props.role or "skater"

    -- Feedback de collision joueur/joueur.
    self.impactStunTimer = 0
    self.impactFlashTimer = 0

    return self
end

function Player:applyImpactFeedback(stunDuration, flashDuration)
    self.impactStunTimer = math.max(self.impactStunTimer, stunDuration or 0)
    self.impactFlashTimer = math.max(self.impactFlashTimer, flashDuration or 0)
end

function Player:enforceSpeedLimit()
    self.vx, self.vy = clampSpeed(self.vx, self.vy, self.maxSpeed)
end

-- Met à jour le forward depuis la direction de déplacement clavier.
function Player:updateForwardFromMovement(moveX, moveY)
    local dirX, dirY = normalizeDirection(moveX, moveY)
    if dirX == 0 and dirY == 0 then
        return
    end

    self.forwardAngle = math.atan2(dirY, dirX)
    self.forwardDirX = dirX
    self.forwardDirY = dirY
end

-- Met à jour la direction de visée depuis une cible en coordonnées monde.
function Player:updateAim(targetX, targetY)
    local centerX = self.x + (self.size * 0.5)
    local centerY = self.y + (self.size * 0.5)
    local deltaX = targetX - centerX
    local deltaY = targetY - centerY

    if deltaX == 0 and deltaY == 0 then
        return
    end

    self.aimAngle = math.atan2(deltaY, deltaX)
    self.aimDirX = math.cos(self.aimAngle)
    self.aimDirY = math.sin(self.aimAngle)
end

-- Rabat un angle de tir dans le cône frontal autorisé autour du forward.
function Player:clampAngleToForwardCone(angle, coneAngleRadians)
    local clampedCone = clamp(coneAngleRadians or math.pi, 0, math.pi * 2)
    local maxDeviation = clampedCone * 0.5
    local delta = normalizeAngle(angle - self.forwardAngle)
    local clampedDelta = clamp(delta, -maxDeviation, maxDeviation)
    return normalizeAngle(self.forwardAngle + clampedDelta)
end

-- Renvoie l'angle de tir autorisé vers une cible monde (prêt pour la logique de tir).
function Player:getClampedShotAngle(targetX, targetY, coneAngleRadians)
    local centerX = self.x + (self.size * 0.5)
    local centerY = self.y + (self.size * 0.5)
    local targetAngle = math.atan2(targetY - centerY, targetX - centerX)
    return self:clampAngleToForwardCone(targetAngle, coneAngleRadians)
end

-- Utilitaire futur tir: vrai si une cible reste dans le cône frontal du joueur.
function Player:isTargetInFront(targetX, targetY, coneAngleRadians)
    local centerX = self.x + (self.size * 0.5)
    local centerY = self.y + (self.size * 0.5)
    local toTargetX = targetX - centerX
    local toTargetY = targetY - centerY
    local distance = math.sqrt((toTargetX * toTargetX) + (toTargetY * toTargetY))

    if distance <= 0.0001 then
        return true
    end

    local normalizedTargetX = toTargetX / distance
    local normalizedTargetY = toTargetY / distance
    local dot = (self.forwardDirX * normalizedTargetX) + (self.forwardDirY * normalizedTargetY)
    local halfCone = clamp((coneAngleRadians or math.pi) * 0.5, 0, math.pi)
    local minDot = math.cos(halfCone)
    return dot >= minDot
end

-- Réinitialise l'inertie (utile pour nouvelle partie/téléportation).
function Player:resetMotion()
    self.vx = 0
    self.vy = 0
end

-- Met à jour la position via accélération d'entrée + inertie + cap vitesse.
function Player:update(dt, direction, room)
    if room == nil then
        room = direction
        direction = { x = 0, y = 0 }
    end

    local dirX, dirY = normalizeDirection(direction.x, direction.y)
    self:updateForwardFromMovement(direction.x, direction.y)

    self.impactStunTimer = math.max(0, self.impactStunTimer - dt)
    self.impactFlashTimer = math.max(0, self.impactFlashTimer - dt)

    local stunControlFactor = self.impactStunTimer > 0 and 0.45 or 1

    -- Input -> accélération : ax = accel * cos(dir), ay = accel * sin(dir).
    -- Ici cos/sin sont implicites car dirX/dirY est déjà unitaire.
    local ax = dirX * self.accel * stunControlFactor
    local ay = dirY * self.accel * stunControlFactor

    -- Drag différencié: en mouvement on conserve de la réactivité, au relâchement on freine davantage.
    local hasInput = dirX ~= 0 or dirY ~= 0
    local baseDrag = hasInput and self.dragMoving or self.dragIdle
    if self.impactStunTimer > 0 then
        baseDrag = math.min(baseDrag, 0.9)
    end
    local dragFactor = math.pow(baseDrag, dt * 60)

    -- Vitesse avec inertie: pv = pv * drag + a.
    self.vx = (self.vx * dragFactor) + (ax * dt)
    self.vy = (self.vy * dragFactor) + (ay * dt)

    -- Contrôle "hockeyeur": on réaligne progressivement la trajectoire vers la direction voulue.
    if hasInput then
        local speed = math.sqrt(self.vx * self.vx + self.vy * self.vy)
        if speed > 0.0001 then
            local desiredVX = dirX * speed
            local desiredVY = dirY * speed
            local steer = clamp(self.turnControl * dt, 0, 1)

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

-- Contraint le joueur aux limites internes elliptiques de la salle.
function Player:clampToRoom(room)
    local ellipse = room:getInnerEllipse(self.size, self.size)

    local centerX = self.x + (self.size * 0.5)
    local centerY = self.y + (self.size * 0.5)

    local normalizedX = (centerX - ellipse.centerX) / ellipse.radiusX
    local normalizedY = (centerY - ellipse.centerY) / ellipse.radiusY
    local distanceSq = (normalizedX * normalizedX) + (normalizedY * normalizedY)

    if distanceSq <= 1 then
        return
    end

    local distance = math.sqrt(distanceSq)
    local projectedCenterX = ellipse.centerX + ((normalizedX / distance) * ellipse.radiusX)
    local projectedCenterY = ellipse.centerY + ((normalizedY / distance) * ellipse.radiusY)

    self.x = projectedCenterX - (self.size * 0.5)
    self.y = projectedCenterY - (self.size * 0.5)

    -- Coupe la vitesse sur les axes poussés hors de l'ellipse pour un contrôle propre.
    if math.abs(projectedCenterX - centerX) > 0.0001 then
        self.vx = 0
    end

    if math.abs(projectedCenterY - centerY) > 0.0001 then
        self.vy = 0
    end
end

-- Dessine le joueur sous forme de rectangle plein.
function Player:draw()
    local centerX = self.x + (self.size * 0.5)
    local centerY = self.y + (self.size * 0.5)
    local renderX = self.x
    local renderY = self.y

    if self.impactStunTimer > 0 then
        local wobble = math.sin(love.timer.getTime() * 40) * 2
        renderX = renderX + wobble
    end

    love.graphics.setColor(self.color)
    love.graphics.rectangle("fill", renderX, renderY, self.size, self.size)

    if self.impactFlashTimer > 0 then
        local flashAlpha = clamp(self.impactFlashTimer / 0.18, 0, 1)
        love.graphics.setColor(1, 1, 1, flashAlpha)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", renderX - 2, renderY - 2, self.size + 4, self.size + 4)
    end

    if self.impactStunTimer > 0 then
        local iconAlpha = clamp(self.impactStunTimer / 0.28, 0.25, 1)
        love.graphics.setColor(1, 0.95, 0.3, iconAlpha)
        love.graphics.circle("fill", centerX, renderY - 8, 4)
    end

    local indicatorLength = self.size * 0.9
    local tipX = centerX + (self.aimDirX * indicatorLength)
    local tipY = centerY + (self.aimDirY * indicatorLength)

    love.graphics.setColor(1, 1, 1)
    love.graphics.setLineWidth(2)
    love.graphics.line(centerX, centerY, tipX, tipY)
end

return Player

local Room = require("src.core.room")
local Player = require("src.core.player")
local InputConfig = require("src.config.input_config")
local PauseMenu = require("src.ui.pause_menu")

local Game = {}
Game.__index = Game

-- Fichier local persistant les options utilisateur (graphismes, son, touches).
local SETTINGS_FILE = "settings.cfg"
local RESOLUTION_CONFIRMATION_SECONDS = 15
local RESOLUTION_CANCEL_MESSAGE = "Resolution annulee"
local RESOLUTION_TIMEOUT_MESSAGE = "Temps ecoule: resolution precedente restauree"

local DEFAULT_INPUT_BINDINGS = {
    up = { "up", "z" },
    down = { "down", "s" },
    left = { "left", "q" },
    right = { "right", "d" },
}

-- Liste des résolutions virtuelles proposées au joueur (format portrait).
-- Le moteur dessine dans cette résolution virtuelle puis met à l'échelle sur la fenêtre.
local RESOLUTIONS = {
    { width = 720, height = 1280 },
    { width = 900, height = 1600 },
    { width = 1080, height = 1920 },
}

local MOVEMENT_ACTIONS = { "up", "down", "left", "right" }

-- Utilitaire générique : borne une valeur entre un minimum et un maximum.
local function clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

-- Copie profonde d'une table de bindings pour éviter les effets de bord.
local function cloneBindings(bindings)
    local output = {}

    for action, keys in pairs(bindings or {}) do
        output[action] = {}
        for _, key in ipairs(keys) do
            table.insert(output[action], key)
        end
    end

    return output
end

-- Découpe une chaîne sur un séparateur (utilisé pour recharger les bindings).
local function split(value, separator)
    local output = {}

    if value == "" then
        return output
    end

    local pattern = "([^" .. separator .. "]+)"
    for part in string.gmatch(value, pattern) do
        table.insert(output, part)
    end

    return output
end

local function formatPercent(value)
    return string.format("%d%%", math.floor(value * 100))
end

-- Constructeur principal : initialise état jeu, menus, rendu et paramètres.
function Game.new()
    local self = setmetatable({}, Game)

    self.defaultInputBindings = cloneBindings(DEFAULT_INPUT_BINDINGS)
    self.input = InputConfig.new(self.defaultInputBindings)

    self.room = Room.new({ x = 80, y = 60, width = 960, height = 600 })
    self.spawnPoint = { x = self.room.x + 40, y = self.room.y + 40 }

    self.player = Player.new({
        x = self.spawnPoint.x,
        y = self.spawnPoint.y,
        size = 36,
        accel = 1200,
        drag = 0.88,
        maxSpeed = 300,
        color = { 0.95, 0.25, 0.25 },
    })

    self.graphicsSettings = { resolutionIndex = 1, fullscreen = false }
    self.committedGraphicsSettings = { resolutionIndex = 1, fullscreen = false }
    self.pendingResolutionChange = nil

        -- État du pipeline de rendu : dimensions virtuelles, transformation écran, caméra.
    self.renderState = {
        virtualWidth = RESOLUTIONS[1].width,
        virtualHeight = RESOLUTIONS[1].height,
        scale = 1,
        offsetX = 0,
        offsetY = 0,
        cameraX = 0,
        cameraY = 0,
        canvas = nil,
    }

    self.soundSettings = { musicVolume = 0.7, sfxVolume = 0.8 }

    self.isPaused = false
    self.awaitingRebindAction = nil
    self.statusMessage = ""

    self.menus = {
        pause = PauseMenu.new({ title = "Pause" }),
        confirmNewGame = PauseMenu.new({ title = "Confirmation" }),
        options = PauseMenu.new({ title = "Options" }),
        controls = PauseMenu.new({ title = "Options / Controls" }),
        graphics = PauseMenu.new({ title = "Options / Graphics" }),
        sound = PauseMenu.new({ title = "Options / Sound" }),
    }

    self.currentMenuKey = "pause"

    self:loadSettings()
    self.committedGraphicsSettings = {
        resolutionIndex = self.graphicsSettings.resolutionIndex,
        fullscreen = self.graphicsSettings.fullscreen,
    }

    self:applyGraphicsSettings(false)
    self:refreshMenus()

    return self
end

-- Renvoie la résolution virtuelle sélectionnée dans les options graphiques.
function Game:getVirtualResolution()
    local resolution = RESOLUTIONS[self.graphicsSettings.resolutionIndex]
    return resolution.width, resolution.height
end

-- Recalcule l'état de rendu à chaque changement de fenêtre/résolution.
-- Important: la largeur virtuelle est forcée à occuper toute la largeur de fenêtre.
function Game:updateRenderState()
    local windowWidth = love.graphics.getWidth()
    local windowHeight = love.graphics.getHeight()
    local virtualWidth, virtualHeight = self:getVirtualResolution()

    self.renderState.virtualWidth = virtualWidth
    self.renderState.virtualHeight = virtualHeight

    if not self.renderState.canvas
        or self.renderState.canvas:getWidth() ~= virtualWidth
        or self.renderState.canvas:getHeight() ~= virtualHeight then
        self.renderState.canvas = love.graphics.newCanvas(virtualWidth, virtualHeight)
    end

    -- Échelle horizontale imposée: la scène remplit toujours la largeur de la fenêtre.
    self.renderState.scale = windowWidth / virtualWidth
    self.renderState.offsetX = 0
    -- Centrage vertical: peut produire des bandes haut/bas si ratio différent.
    self.renderState.offsetY = math.floor((windowHeight - virtualHeight * self.renderState.scale) / 2)
end

-- Convertit des coordonnées écran (pixels fenêtre) en coordonnées virtuelles canvas.
function Game:toVirtualPosition(screenX, screenY)
    local scale = self.renderState.scale
    local x = (screenX - self.renderState.offsetX) / scale
    local y = (screenY - self.renderState.offsetY) / scale
    return x, y
end

-- Recalcule la salle et le point de spawn selon la résolution virtuelle actuelle.
function Game:updateLayoutFromWindow()
    local windowWidth = self.renderState.virtualWidth
    local windowHeight = self.renderState.virtualHeight

    -- Réduit les marges latérales pour élargir visuellement le terrain.
    local marginX = math.floor(windowWidth * 0.03)
    local topOffset = math.floor(windowHeight * 0.14)
    local bottomOffset = math.floor(windowHeight * 0.08)

    marginX = math.max(12, marginX)
    topOffset = math.max(80, topOffset)
    bottomOffset = math.max(40, bottomOffset)

    local roomWidth = math.max(320, windowWidth - marginX * 2)
    local roomHeight = math.max(220, windowHeight - topOffset - bottomOffset)

    self.room.x = math.floor((windowWidth - roomWidth) / 2)
    self.room.y = topOffset
    self.room.width = roomWidth
    self.room.height = roomHeight

    self.spawnPoint.x = self.room.x + math.floor(self.room.width * 0.08)
    self.spawnPoint.y = self.room.y + math.floor(self.room.height * 0.08)

    self.player:clampToRoom(self.room)
end

-- Sérialise les options persistantes vers un format clé=valeur.
function Game:serializeSettings()
    local lines = {
        "resolutionIndex=" .. tostring(self.committedGraphicsSettings.resolutionIndex),
        "fullscreen=" .. (self.committedGraphicsSettings.fullscreen and "1" or "0"),
        "musicVolume=" .. tostring(self.soundSettings.musicVolume),
        "sfxVolume=" .. tostring(self.soundSettings.sfxVolume),
    }

    local bindings = self.input:getBindings()
    for _, action in ipairs(MOVEMENT_ACTIONS) do
        lines[#lines + 1] = "bind_" .. action .. "=" .. table.concat(bindings[action] or {}, ",")
    end

    return table.concat(lines, "\n")
end

-- Charge les options depuis le fichier de settings si présent.
function Game:loadSettings()
    if not love.filesystem.getInfo(SETTINGS_FILE) then
        return
    end

    local content, readError = love.filesystem.read(SETTINGS_FILE)
    if not content then
        self.statusMessage = "Lecture settings impossible: " .. tostring(readError)
        return
    end

    local loadedBindings = cloneBindings(self.defaultInputBindings)

    for line in string.gmatch(content, "[^\n]+") do
        local key, value = line:match("^(.-)=(.*)$")
        if key and value then
            if key == "resolutionIndex" then
                self.graphicsSettings.resolutionIndex = clamp(tonumber(value) or 1, 1, #RESOLUTIONS)
            elseif key == "fullscreen" then
                self.graphicsSettings.fullscreen = value == "1"
            elseif key == "musicVolume" then
                self.soundSettings.musicVolume = clamp(tonumber(value) or self.soundSettings.musicVolume, 0, 1)
            elseif key == "sfxVolume" then
                self.soundSettings.sfxVolume = clamp(tonumber(value) or self.soundSettings.sfxVolume, 0, 1)
            elseif key:find("^bind_") then
                local action = key:gsub("^bind_", "")
                loadedBindings[action] = split(value, ",")
            end
        end
    end

    local fallbackBindings = cloneBindings(self.defaultInputBindings)
    for _, action in ipairs(MOVEMENT_ACTIONS) do
        if not loadedBindings[action] or #loadedBindings[action] == 0 then
            loadedBindings[action] = fallbackBindings[action]
        end
    end

    self.input:setBindings(loadedBindings)
    self.statusMessage = "Options chargees"
end

-- Sauvegarde les options sur disque (appelé à la fermeture et au quit).
function Game:saveSettings()
    local ok, writeError = love.filesystem.write(SETTINGS_FILE, self:serializeSettings())
    if not ok then
        self.statusMessage = "Erreur sauvegarde: " .. tostring(writeError)
        return false
    end

    self.statusMessage = "Options sauvegardees"
    return true
end

-- Reconstruit dynamiquement les menus (labels dépendants de l'état courant).
function Game:refreshMenus()
    self.menus.pause:setItems({
        { label = "Nouvelle partie", onActivate = function(game) game:openMenu("confirmNewGame") end },
        { label = "Options", onActivate = function(game) game:openMenu("options") end },
        { label = "Quitter", onActivate = function(game) game:quit() end },
    })

    self.menus.confirmNewGame:setItems({
        { label = "Confirmer nouvelle partie", onActivate = function(game) game:startNewGame() end },
        { label = "Annuler", onActivate = function(game) game:openMenu("pause") end },
    })

    self.menus.options:setItems({
        { label = "Controls", onActivate = function(game) game:openMenu("controls") end },
        { label = "Graphics", onActivate = function(game) game:openMenu("graphics") end },
        { label = "Sound", onActivate = function(game) game:openMenu("sound") end },
        { label = "Retour", onActivate = function(game) game:openMenu("pause") end },
    })

    self.menus.controls:setItems({
        { label = "Move Up", valueLabel = self.input:getBindingLabel("up"), onActivate = function(game) game:startRebind("up") end },
        { label = "Move Down", valueLabel = self.input:getBindingLabel("down"), onActivate = function(game) game:startRebind("down") end },
        { label = "Move Left", valueLabel = self.input:getBindingLabel("left"), onActivate = function(game) game:startRebind("left") end },
        { label = "Move Right", valueLabel = self.input:getBindingLabel("right"), onActivate = function(game) game:startRebind("right") end },
        { label = "Default Inputs", onActivate = function(game) game:resetDefaultInputs() end },
        { label = "Retour", onActivate = function(game) game:openMenu("options") end },
    })

    local resolution = RESOLUTIONS[self.graphicsSettings.resolutionIndex]
    self.menus.graphics:setItems({
        {
            label = "Resolution",
            valueLabel = resolution.width .. "x" .. resolution.height,
            onLeft = function(game) game:previewResolutionChange(-1) end,
            onRight = function(game) game:previewResolutionChange(1) end,
            onActivate = function(game) game:previewResolutionChange(1) end,
        },
        {
            label = "Fullscreen",
            valueLabel = self.graphicsSettings.fullscreen and "ON" or "OFF",
            onLeft = function(game) game:previewFullscreenToggle() end,
            onRight = function(game) game:previewFullscreenToggle() end,
            onActivate = function(game) game:previewFullscreenToggle() end,
        },
        { label = "Retour", onActivate = function(game) game:openMenu("options") end },
    })

    self.menus.sound:setItems({
        {
            label = "Music Volume",
            valueLabel = formatPercent(self.soundSettings.musicVolume),
            onLeft = function(game) game:changeMusicVolume(-0.05) end,
            onRight = function(game) game:changeMusicVolume(0.05) end,
        },
        {
            label = "SFX Volume",
            valueLabel = formatPercent(self.soundSettings.sfxVolume),
            onLeft = function(game) game:changeSfxVolume(-0.05) end,
            onRight = function(game) game:changeSfxVolume(0.05) end,
        },
        { label = "Retour", onActivate = function(game) game:openMenu("options") end },
    })
end

function Game:openMenu(menuKey)
    self.currentMenuKey = menuKey
    self.awaitingRebindAction = nil
end

-- Réinitialise la partie et recale la caméra sur le spawn du joueur.
function Game:startNewGame()
    self.player.x = self.spawnPoint.x
    self.player.y = self.spawnPoint.y
    self.player:resetMotion()
    self:updateCamera()
    self.isPaused = false
    self.currentMenuKey = "pause"
    self.awaitingRebindAction = nil
    self.statusMessage = "Nouvelle partie lancee"
end

function Game:startRebind(action)
    self.awaitingRebindAction = action
    self.statusMessage = "Appuie sur une touche pour " .. action
end

function Game:finishRebind(key)
    if key == "escape" then
        self.awaitingRebindAction = nil
        self.statusMessage = "Reassignation annulee"
        return
    end

    self.input:setBinding(self.awaitingRebindAction, { key })
    self.statusMessage = "Touche " .. self.awaitingRebindAction .. " => " .. key
    self.awaitingRebindAction = nil
    self:refreshMenus()
end

function Game:resetDefaultInputs()
    self.input:setBindings(self.defaultInputBindings)
    self.awaitingRebindAction = nil
    self.statusMessage = "Touches par defaut restaurees"
    self:refreshMenus()
end

-- Prévisualise une nouvelle résolution avec fenêtre de confirmation temporaire.
function Game:previewResolutionChange(direction)
    local index = self.graphicsSettings.resolutionIndex + direction
    self.graphicsSettings.resolutionIndex = clamp(index, 1, #RESOLUTIONS)
    self:applyGraphicsSettings(true)
    self:startResolutionCountdown()
    self:refreshMenus()
end

function Game:previewFullscreenToggle()
    self.graphicsSettings.fullscreen = not self.graphicsSettings.fullscreen
    self:applyGraphicsSettings(true)

    self.committedGraphicsSettings.fullscreen = self.graphicsSettings.fullscreen

    if not self.pendingResolutionChange then
        self.statusMessage = "Fullscreen: " .. (self.graphicsSettings.fullscreen and "ON" or "OFF")
    end

    self:refreshMenus()
end

function Game:startResolutionCountdown()
    if not self.pendingResolutionChange then
        self.pendingResolutionChange = { countdown = RESOLUTION_CONFIRMATION_SECONDS, selectedButton = 1 }
    else
        self.pendingResolutionChange.countdown = RESOLUTION_CONFIRMATION_SECONDS
    end

    self.statusMessage = "Validation de resolution demandee"
end

function Game:confirmResolutionChange()
    if not self.pendingResolutionChange then
        return
    end

    self.committedGraphicsSettings.resolutionIndex = self.graphicsSettings.resolutionIndex
    self.committedGraphicsSettings.fullscreen = self.graphicsSettings.fullscreen
    self.pendingResolutionChange = nil
    self.statusMessage = "Resolution validee"
    self:refreshMenus()
end

function Game:cancelResolutionChange(reason)
    if not self.pendingResolutionChange then
        return
    end

    self.graphicsSettings.resolutionIndex = self.committedGraphicsSettings.resolutionIndex
    self.graphicsSettings.fullscreen = self.committedGraphicsSettings.fullscreen
    self.pendingResolutionChange = nil
    self:applyGraphicsSettings(false)
    self.statusMessage = reason or RESOLUTION_CANCEL_MESSAGE
    self:refreshMenus()
end

-- Applique les options graphiques courantes (fenêtré/fullscreen + layout + caméra).
function Game:applyGraphicsSettings(showStatus)
    local resolution = RESOLUTIONS[self.graphicsSettings.resolutionIndex]

    if self.graphicsSettings.fullscreen then
        local desktopWidth, desktopHeight = love.window.getDesktopDimensions(1)
        love.window.setMode(desktopWidth, desktopHeight, {
            fullscreen = true,
            fullscreentype = "desktop",
            borderless = true,
            resizable = false,
        })
    else
        love.window.setMode(resolution.width, resolution.height, {
            fullscreen = false,
            borderless = false,
            resizable = true,
            minwidth = 360,
            minheight = 640,
        })
    end

    self:updateRenderState()
    self:updateLayoutFromWindow()
    self:updateCamera()

    if showStatus then
        self.statusMessage = "Graphics: " .. resolution.width .. "x" .. resolution.height
    end
end

function Game:changeMusicVolume(delta)
    self.soundSettings.musicVolume = clamp(self.soundSettings.musicVolume + delta, 0, 1)
    self.statusMessage = "Music volume: " .. formatPercent(self.soundSettings.musicVolume)
    self:refreshMenus()
end

function Game:changeSfxVolume(delta)
    self.soundSettings.sfxVolume = clamp(self.soundSettings.sfxVolume + delta, 0, 1)
    self.statusMessage = "SFX volume: " .. formatPercent(self.soundSettings.sfxVolume)
    self:refreshMenus()
end

function Game:quit()
    self:saveSettings()
    love.event.quit()
end

function Game:togglePause()
    self.isPaused = not self.isPaused
    self.awaitingRebindAction = nil
    if self.isPaused then
        self.currentMenuKey = "pause"
    end
end

-- Décrit la géométrie de la popup de confirmation de résolution.
function Game:getResolutionPopupLayout()
    local windowWidth = self.renderState.virtualWidth
    local windowHeight = self.renderState.virtualHeight

    local popupWidth = 620
    local popupHeight = 240
    local popupX = (windowWidth - popupWidth) / 2
    local popupY = (windowHeight - popupHeight) / 2

    local buttonWidth = 140
    local buttonHeight = 40
    local buttonSpacing = 12

    local cancelX = popupX + popupWidth - buttonWidth - 24
    local validateX = cancelX - buttonWidth - buttonSpacing
    local buttonY = popupY + popupHeight - buttonHeight - 20

    return {
        x = popupX,
        y = popupY,
        width = popupWidth,
        height = popupHeight,
        buttons = {
            { x = validateX, y = buttonY, width = buttonWidth, height = buttonHeight, label = "Valider", action = "confirm" },
            { x = cancelX, y = buttonY, width = buttonWidth, height = buttonHeight, label = "Annuler", action = "cancel" },
        },
    }
end

function Game:activateResolutionPopupButton(action)
    if action == "confirm" then
        self:confirmResolutionChange()
    else
        self:cancelResolutionChange(RESOLUTION_CANCEL_MESSAGE)
    end
end

function Game:handleResolutionPopupKey(key)
    if not self.pendingResolutionChange then
        return false
    end

    if key == "left" then
        self.pendingResolutionChange.selectedButton = 1
        return true
    end

    if key == "right" then
        self.pendingResolutionChange.selectedButton = 2
        return true
    end

    if key == "return" or key == "kpenter" then
        if self.pendingResolutionChange.selectedButton == 1 then
            self:activateResolutionPopupButton("confirm")
        else
            self:activateResolutionPopupButton("cancel")
        end
        return true
    end

    return false
end

-- Gestion souris limitée à la popup de résolution (clic gauche).
function Game:mousepressed(x, y, button)
    if button ~= 1 then
        return
    end

    if not self.isPaused or not self.pendingResolutionChange then
        return
    end

    local virtualX, virtualY = self:toVirtualPosition(x, y)
    local layout = self:getResolutionPopupLayout()

    for index, popupButton in ipairs(layout.buttons) do
        local insideX = virtualX >= popupButton.x and virtualX <= popupButton.x + popupButton.width
        local insideY = virtualY >= popupButton.y and virtualY <= popupButton.y + popupButton.height

        if insideX and insideY then
            self.pendingResolutionChange.selectedButton = index
            self:activateResolutionPopupButton(popupButton.action)
            return
        end
    end
end

-- Routage des entrées clavier quand le jeu est en pause.
function Game:handlePausedInput(key)
    if self.awaitingRebindAction then
        self:finishRebind(key)
        return
    end

    if self.pendingResolutionChange and self:handleResolutionPopupKey(key) then
        return
    end

    local currentMenu = self.menus[self.currentMenuKey]
    if not currentMenu then
        return
    end

    if key == "up" then
        currentMenu:moveSelection(-1)
        return
    end

    if key == "down" then
        currentMenu:moveSelection(1)
        return
    end

    local selected = currentMenu:getSelectedItem()

    if key == "left" and selected and selected.onLeft then
        selected.onLeft(self)
        return
    end
    if key == "right" and selected and selected.onRight then
        selected.onRight(self)
        return
    end

    if (key == "return" or key == "kpenter") and selected and selected.onActivate then
        selected.onActivate(self)
    end
end

-- Point d'entrée global clavier (pause + navigation menus).
function Game:keypressed(key)
    if key == "escape" then
        if not self.isPaused then
            self:togglePause()
            return
        end

        if self.awaitingRebindAction then
            self.awaitingRebindAction = nil
            self.statusMessage = "Reassignation annulee"
            return
        end

        if self.pendingResolutionChange then
            self:cancelResolutionChange(RESOLUTION_CANCEL_MESSAGE)
            return
        end

        if self.currentMenuKey ~= "pause" then
            self:openMenu("pause")
            return
        end

        self:togglePause()
        return
    end

    if self.isPaused then
        self:handlePausedInput(key)
    end
end

-- Centre la caméra sur le centre du personnage (sans clamp monde pour l'instant).
function Game:updateCamera()
    local virtualWidth = self.renderState.virtualWidth
    local virtualHeight = self.renderState.virtualHeight

    -- Caméra X: place le centre du joueur au centre de la vue virtuelle.
    self.renderState.cameraX = self.player.x + (self.player.size * 0.5) - (virtualWidth * 0.5)
    -- Caméra Y: même principe sur l'axe vertical.
    self.renderState.cameraY = self.player.y + (self.player.size * 0.5) - (virtualHeight * 0.5)
end

-- Boucle logique : timer popup, déplacement joueur, puis mise à jour caméra.
function Game:update(dt)
    if self.pendingResolutionChange then
        self.pendingResolutionChange.countdown = self.pendingResolutionChange.countdown - dt
        if self.pendingResolutionChange.countdown <= 0 then
            self:cancelResolutionChange(RESOLUTION_TIMEOUT_MESSAGE)
        end
    end

    if self.isPaused then
        return
    end

    local direction = self.input:getDirection()
    self.player:update(dt, direction, self.room)
    self:updateCamera()
end

-- Callback Love2D sur redimensionnement : on recalcule rendu, layout et caméra.
function Game:resize()
    self:updateRenderState()
    self:updateLayoutFromWindow()
    self:updateCamera()
end

-- HUD d'aide contrôles: volontairement dessiné en coordonnées écran (non caméra).
function Game:drawHud()
    local baseX = 24
    local baseY = 18

    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Deplacement", baseX, baseY)
    love.graphics.print("Haut: " .. self.input:getBindingLabel("up"), baseX, baseY + 16)
    love.graphics.print("Bas: " .. self.input:getBindingLabel("down"), baseX, baseY + 32)
    love.graphics.print("Gauche: " .. self.input:getBindingLabel("left"), baseX, baseY + 48)
    love.graphics.print("Droite: " .. self.input:getBindingLabel("right"), baseX, baseY + 64)
end

-- Dessine la popup de résolution.
-- originX/originY permet de l'ancrer dans le repère caméra quand nécessaire.
function Game:drawResolutionPopup(originX, originY)
    if not self.pendingResolutionChange then
        return
    end

    local layout = self:getResolutionPopupLayout()
    local drawOffsetX = originX or 0
    local drawOffsetY = originY or 0
    local secondsLeft = math.max(0, math.ceil(self.pendingResolutionChange.countdown))

    love.graphics.setColor(0.08, 0.08, 0.08, 0.95)
    love.graphics.rectangle("fill", layout.x + drawOffsetX, layout.y + drawOffsetY, layout.width, layout.height, 8, 8)

    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", layout.x + drawOffsetX, layout.y + drawOffsetY, layout.width, layout.height, 8, 8)

    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Confirmer le changement de resolution ?", layout.x + drawOffsetX + 24, layout.y + drawOffsetY + 24, layout.width - 48, "left")
    love.graphics.printf("Le changement sera annule automatiquement dans " .. tostring(secondsLeft) .. " secondes.", layout.x + drawOffsetX + 24, layout.y + drawOffsetY + 62, layout.width - 48, "left")

    for index, popupButton in ipairs(layout.buttons) do
        local isSelected = self.pendingResolutionChange.selectedButton == index

        if isSelected then
            love.graphics.setColor(0.92, 0.82, 0.25)
        else
            love.graphics.setColor(0.25, 0.25, 0.3)
        end

        love.graphics.rectangle("fill", popupButton.x + drawOffsetX, popupButton.y + drawOffsetY, popupButton.width, popupButton.height, 5, 5)

        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("line", popupButton.x + drawOffsetX, popupButton.y + drawOffsetY, popupButton.width, popupButton.height, 5, 5)
        love.graphics.printf(popupButton.label, popupButton.x + drawOffsetX, popupButton.y + drawOffsetY + 12, popupButton.width, "center")
    end
end

-- Dessine la couche pause dans le repère caméra, autour de la zone observée.
-- Le menu est positionné près du joueur puis contraint aux limites de la vue.
function Game:drawPauseLayer()
    local windowWidth = self.renderState.virtualWidth
    local windowHeight = self.renderState.virtualHeight
    local cameraX = self.renderState.cameraX
    local cameraY = self.renderState.cameraY

    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", cameraX, cameraY, windowWidth, windowHeight)

    local viewLeft = cameraX
    local viewTop = cameraY
    local viewRight = cameraX + windowWidth
    local viewBottom = cameraY + windowHeight

    -- Position horizontale: à droite du joueur, puis clampée pour rester lisible dans la vue.
    local menuX = clamp(self.player.x + self.player.size + 28, viewLeft + 24, viewRight - 320)
    -- Position verticale: légèrement au-dessus du joueur, puis clampée dans la vue.
    local menuY = clamp(self.player.y - 48, viewTop + 24, viewBottom - 220)

    local currentMenu = self.menus[self.currentMenuKey]
    if currentMenu then
        currentMenu:draw(menuX, menuY)
    end

    self:drawResolutionPopup(cameraX, cameraY)

    love.graphics.setColor(0.95, 0.95, 0.95)
    local hints = {}

    if self.awaitingRebindAction then
        table.insert(hints, "En attente d'une touche pour: " .. self.awaitingRebindAction)
    end

    if self.currentMenuKey == "confirmNewGame" then
        table.insert(hints, "Confirme avant de reinitialiser la partie")
    end

    local hintText = ""
    if #hints > 0 then
        hintText = " | " .. table.concat(hints, " | ")
    end

    love.graphics.print(self.statusMessage .. hintText, cameraX + 24, cameraY + windowHeight - 60)
end

-- Pipeline de rendu:
-- 1) monde (room + player) sous transformation caméra
-- 2) pause (dans repère caméra)
-- 3) HUD écran
-- 4) blit du canvas sur la fenêtre avec scale/offset
function Game:draw()
    local canvas = self.renderState.canvas

    love.graphics.setCanvas(canvas)
    love.graphics.clear(0.08, 0.08, 0.1, 1)

    love.graphics.push()
    -- On inverse le déplacement caméra pour amener la zone suivie dans la fenêtre.
    love.graphics.translate(-self.renderState.cameraX, -self.renderState.cameraY)
    self.room:draw()
    self.player:draw()

    if self.isPaused then
        self:drawPauseLayer()
    end

    love.graphics.pop()

    self:drawHud()

    love.graphics.setCanvas()
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(canvas, self.renderState.offsetX, self.renderState.offsetY, 0, self.renderState.scale, self.renderState.scale)
end

return Game

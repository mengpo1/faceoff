-- Composant UI simple de menu de pause/navigation.
local PauseMenu = {}
PauseMenu.__index = PauseMenu

-- Construit un menu avec titre, items et texte d'aide.
function PauseMenu.new(config)
    local self = setmetatable({}, PauseMenu)

    self.title = config.title or "Menu"
    self.items = config.items or {}
    self.helpText = config.helpText or "↑/↓ naviguer - Entrée valider - Echap retour"
    self.selectedIndex = 1

    return self
end

-- Remplace la liste d'items et garde un index de sélection valide.
function PauseMenu:setItems(items)
    self.items = items or {}
    self.selectedIndex = math.max(1, math.min(self.selectedIndex, #self.items))
end

-- Déplace la sélection avec un comportement circulaire.
function PauseMenu:moveSelection(offset)
    if #self.items == 0 then
        return
    end

    self.selectedIndex = self.selectedIndex + offset

    if self.selectedIndex < 1 then
        self.selectedIndex = #self.items
    elseif self.selectedIndex > #self.items then
        self.selectedIndex = 1
    end
end

-- Renvoie l'item actuellement sélectionné.
function PauseMenu:getSelectedItem()
    return self.items[self.selectedIndex]
end

-- Dessine le menu à une position donnée.
function PauseMenu:draw(x, y)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(self.title, x, y)

    for index, item in ipairs(self.items) do
        local prefix = index == self.selectedIndex and "> " or "  "
        local line = prefix .. (item.label or "")

        if item.valueLabel then
            line = line .. ": " .. item.valueLabel
        end

        love.graphics.print(line, x, y + index * 24)
    end

    love.graphics.setColor(0.85, 0.85, 0.85)
    love.graphics.print(self.helpText, x, y + (#self.items + 2) * 24)
end

return PauseMenu

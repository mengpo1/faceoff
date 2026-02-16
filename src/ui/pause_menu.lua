local PauseMenu = {}
PauseMenu.__index = PauseMenu

function PauseMenu.new(config)
    local self = setmetatable({}, PauseMenu)

    self.title = config.title or "Menu"
    self.items = config.items or {}
    self.helpText = config.helpText or "↑/↓ naviguer - Entrée valider - Echap retour"
    self.selectedIndex = 1

    return self
end

function PauseMenu:setItems(items)
    self.items = items or {}
    self.selectedIndex = math.max(1, math.min(self.selectedIndex, #self.items))
end

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

function PauseMenu:getSelectedItem()
    return self.items[self.selectedIndex]
end

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

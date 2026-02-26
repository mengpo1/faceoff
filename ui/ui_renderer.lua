local renderer = {}

local function drawRectOutline(rect, r, g, b)
    love.graphics.setColor(r, g, b, 0.9)
    love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h)
end

local function drawBar(rect, value, fg)
    love.graphics.setColor(0.12, 0.12, 0.14, 1)
    love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h)
    love.graphics.setColor(fg[1], fg[2], fg[3], 1)
    love.graphics.rectangle("fill", rect.x + 1, rect.y + 1, (rect.w - 2) * value, rect.h - 2)
    love.graphics.setColor(0.85, 0.85, 0.9, 1)
    love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h)
end

function renderer.draw(game, layoutData)
    local uiState = game.uiState

    love.graphics.setColor(0.08, 0.08, 0.11, 0.92)
    love.graphics.rectangle("fill", layoutData.infoRect.x, layoutData.infoRect.y, layoutData.infoRect.w, layoutData.infoRect.h)
    love.graphics.rectangle("fill", layoutData.controlsRect.x, layoutData.controlsRect.y, layoutData.controlsRect.w, layoutData.controlsRect.h)

    local p1 = layoutData.portraits.left
    local p2 = layoutData.portraits.right

    love.graphics.setColor(0.25, 0.45, 0.65, 1)
    love.graphics.rectangle("fill", p1.x, p1.y, p1.w, p1.h)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("P1", p1.x, p1.y + math.floor(p1.h * 0.4), p1.w, "center")

    love.graphics.setColor(0.55, 0.35, 0.25, 1)
    love.graphics.rectangle("fill", p2.x, p2.y, p2.w, p2.h)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("P2", p2.x, p2.y + math.floor(p2.h * 0.4), p2.w, "center")

    drawBar(layoutData.bars.p1hp, uiState.p1hp, { 0.88, 0.18, 0.18 })
    drawBar(layoutData.bars.p1mana, uiState.p1mana, { 0.2, 0.5, 0.95 })
    drawBar(layoutData.bars.p2hp, uiState.p2hp, { 0.88, 0.18, 0.18 })
    drawBar(layoutData.bars.p2mana, uiState.p2mana, { 0.2, 0.5, 0.95 })

    for _, slotRect in ipairs(layoutData.itemSlots) do
        love.graphics.setColor(0.2, 0.22, 0.27, 1)
        love.graphics.rectangle("fill", slotRect.x, slotRect.y, slotRect.w, slotRect.h)
        love.graphics.setColor(0.82, 0.84, 0.92, 1)
        love.graphics.rectangle("line", slotRect.x, slotRect.y, slotRect.w, slotRect.h)
        love.graphics.printf(slotRect.name, slotRect.x, slotRect.y + math.floor(slotRect.h * 0.35), slotRect.w, "center")
    end

    for action, rect in pairs(layoutData.controls) do
        local isActive = game.uiControlState[action]
        if isActive then
            love.graphics.setColor(0.92, 0.75, 0.26, 1)
        else
            love.graphics.setColor(0.28, 0.3, 0.36, 1)
        end
        love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h)
        love.graphics.setColor(0.92, 0.92, 0.95, 1)
        love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h)
        love.graphics.printf(action, rect.x, rect.y + math.floor(rect.h * 0.34), rect.w, "center")
    end

    if game.uiConfig.debugLayout then
        drawRectOutline(layoutData.zones.view, 0.2, 0.95, 0.3)
        drawRectOutline(layoutData.infoRect, 0.15, 0.6, 1)
        drawRectOutline(layoutData.controlsRect, 1, 0.55, 0.2)

        love.graphics.setColor(0.2, 0.95, 0.3, 1)
        love.graphics.print("VIEW", layoutData.zones.view.x + 4, 4)
        love.graphics.setColor(0.15, 0.6, 1, 1)
        love.graphics.print("INFO", layoutData.infoRect.x + 4, 4)
        love.graphics.setColor(1, 0.55, 0.2, 1)
        love.graphics.print("CTRL", layoutData.controlsRect.x + 4, 4)
    end
end

return renderer

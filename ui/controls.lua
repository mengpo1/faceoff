local controls = {}

local function contains(rect, x, y)
    return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
end

function controls.hitTest(layoutData, x, y)
    for action, rect in pairs(layoutData.controls) do
        if contains(rect, x, y) then
            return action
        end
    end

    for _, slotRect in ipairs(layoutData.itemSlots) do
        if contains(slotRect, x, y) then
            return "ITEM_" .. slotRect.name
        end
    end

    return nil
end

return controls

local layout = {}

local function rect(x, y, w, h, name)
    return { x = x, y = y, w = w, h = h, name = name }
end

function layout.compute(screenW, screenH, controlsSide)
    local side = controlsSide == "left" and "left" or "right"

    local sidePanelW = math.floor(screenW * 0.24)
    sidePanelW = math.max(170, math.min(sidePanelW, 300))

    local gap = math.floor(screenW * 0.02)
    gap = math.max(10, gap)

    local viewX = sidePanelW + gap
    local viewW = screenW - (sidePanelW * 2) - (gap * 2)
    viewW = math.max(220, viewW)

    local zones = {
        view = rect(viewX, 0, viewW, screenH, "VIEW"),
        leftPanel = rect(0, 0, sidePanelW, screenH, "LEFT_PANEL"),
        rightPanel = rect(screenW - sidePanelW, 0, sidePanelW, screenH, "RIGHT_PANEL"),
    }

    local controlsRect = side == "right" and zones.rightPanel or zones.leftPanel
    local infoRect = side == "right" and zones.leftPanel or zones.rightPanel

    local portraitMargin = 12
    local portraitSize = math.min(infoRect.w - portraitMargin * 2, math.floor(screenH * 0.13))
    portraitSize = math.max(72, portraitSize)

    local hpBarH = 12
    local manaBarH = 12
    local barGap = 6

    local portraitLeft = rect(infoRect.x + portraitMargin, portraitMargin, portraitSize, portraitSize, "P1")
    local portraitRight = rect(
        infoRect.x + infoRect.w - portraitMargin - portraitSize,
        portraitMargin,
        portraitSize,
        portraitSize,
        "P2"
    )

    local bars = {
        p1hp = rect(portraitLeft.x, portraitLeft.y + portraitLeft.h + 6, portraitLeft.w, hpBarH, "HP1"),
        p1mana = rect(portraitLeft.x, portraitLeft.y + portraitLeft.h + 6 + hpBarH + barGap, portraitLeft.w, manaBarH, "STA1"),
        p2hp = rect(portraitRight.x, portraitRight.y + portraitRight.h + 6, portraitRight.w, hpBarH, "HP2"),
        p2mana = rect(portraitRight.x, portraitRight.y + portraitRight.h + 6 + hpBarH + barGap, portraitRight.w, manaBarH, "STA2"),
    }

    local itemsTop = math.max(
        bars.p1mana.y + bars.p1mana.h,
        bars.p2mana.y + bars.p2mana.h
    ) + 12

    local itemsArea = rect(infoRect.x + portraitMargin, itemsTop, infoRect.w - portraitMargin * 2, infoRect.h - itemsTop - 12, "ITEMS")

    local colGap = 8
    local slotSize = math.floor((itemsArea.w - colGap) / 2)
    slotSize = math.max(34, math.min(slotSize, 72))
    local rowGap = 6

    local itemSlots = {}
    for i = 1, 11 do
        local isLeftCol = i <= 6
        local col = isLeftCol and 0 or 1
        local row = isLeftCol and (i - 1) or (i - 7)

        local x = itemsArea.x + col * (slotSize + colGap)
        local y = itemsArea.y + row * (slotSize + rowGap)

        table.insert(itemSlots, rect(x, y, slotSize, slotSize, tostring(i)))
    end

    local cMargin = 14
    local cW = controlsRect.w - cMargin * 2
    local btnSize = math.floor(cW * 0.28)
    btnSize = math.max(42, math.min(btnSize, 82))
    local bGap = 10

    local centerX = controlsRect.x + math.floor((controlsRect.w - btnSize) / 2)
    local topY = math.floor(screenH * 0.18)

    local controls = {
        TURN_L = rect(centerX - btnSize - bGap, topY, btnSize, btnSize, "TURN_L"),
        MOVE_F = rect(centerX, topY, btnSize, btnSize, "MOVE_F"),
        TURN_R = rect(centerX + btnSize + bGap, topY, btnSize, btnSize, "TURN_R"),
        MOVE_B = rect(centerX, topY + btnSize + bGap, btnSize, btnSize, "MOVE_B"),
        USE = rect(centerX, topY + (btnSize + bGap) * 2, btnSize, btnSize, "USE"),
        PAUSE = rect(controlsRect.x + cMargin, controlsRect.y + controlsRect.h - btnSize - 14, btnSize, btnSize, "PAUSE"),
        SPEED = rect(controlsRect.x + controlsRect.w - cMargin - btnSize, controlsRect.y + controlsRect.h - btnSize - 14, btnSize, btnSize, "SPEED"),
    }

    return {
        controlsSide = side,
        zones = zones,
        controlsRect = controlsRect,
        infoRect = infoRect,
        portraits = { left = portraitLeft, right = portraitRight },
        bars = bars,
        itemsArea = itemsArea,
        itemSlots = itemSlots,
        controls = controls,
    }
end

return layout

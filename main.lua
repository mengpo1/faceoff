local Game = require("src.core.game")

local game = nil

function love.load()
    love.window.setTitle("Faceoff Prototype")
    game = Game.new()
end

function love.update(dt)
    game:update(dt)
end

function love.draw()
    game:draw()
end

function love.keypressed(key)
    game:keypressed(key)
end

function love.mousepressed(x, y, button)
    game:mousepressed(x, y, button)
end

function love.resize(_, _)
    if game then
        game:resize()
    end
end

function love.quit()
    if game then
        game:saveSettings()
    end
end

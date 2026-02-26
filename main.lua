-- Point d'entrée Love2D du prototype Faceoff.
-- Ce fichier ne contient que le câblage des callbacks Love vers l'objet Game.
local Game = require("src.core.game")

-- Instance unique de la boucle de jeu.
local game = nil

-- Initialisation de la fenêtre et création du jeu.
function love.load()
    love.window.setTitle("Faceoff Prototype")
    game = Game.new()
end

-- Tick logique appelé à chaque frame.
function love.update(dt)
    game:update(dt)
end

-- Rendu appelé à chaque frame.
function love.draw()
    game:draw()
end

-- Propagation des entrées clavier vers la logique Game.
function love.keypressed(key)
    game:keypressed(key)
end

-- Propagation des clics souris (utilisé notamment par les popups).
function love.mousepressed(x, y, button)
    game:mousepressed(x, y, button)
end

-- Recalage du rendu/layout lors d'un redimensionnement de fenêtre.
function love.resize(_, _)
    if game then
        game:resize()
    end
end

-- Persistance des paramètres à la fermeture de l'application.
function love.quit()
    if game then
        game:saveSettings()
    end
end

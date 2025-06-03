local upgradeTreeCameraSpeed = 300 -- pixels per second for tree camera movement
local isDraggingTree = false
local lastMouseX, lastMouseY = 0, 0

function love.load()
    -- Load core modules first
    Config = require("config") -- Made global with capital
    utils = require("utils")
    Assets = require("assets") -- Load assets early

    love.window.setTitle(Config.windowTitle)
    love.window.setMode(Config.windowWidth, Config.windowHeight)
    -- Use baseFontSize and uiScaleFactor for font creation
    local effectiveFontSize = (Config.baseFontSize or 14) * (Config.uiScaleFactor or 1)
    font = love.graphics.newFont(math.floor(effectiveFontSize)) -- Ensure integer font size
    love.graphics.setFont(font)

    -- Load game logic modules
    Player = require("player")
    Enemies = require("enemies")
    Upgrades = require("upgrades")
    UI = require("ui")
    Game = require("game") -- Game module last as it might use others

    -- Initialize modules that require it
    Enemies.initialize()
    Upgrades.initializeTree()
    Game.initializeRealms()
    if Player.initializeAnimation and Assets.player_spritesheet then
        Player.initializeAnimation(Assets.player_spritesheet)
    elseif Player.initializeAnimation then
        print("Warning: Assets.player_spritesheet not available for Player.initializeAnimation.")
    end
    -- UI.initialize() if exists
    Upgrades.recalculatePlayerBonuses(Player, Upgrades.getNodes()) -- Initial bonus calculation
end

function love.update(dt)
    if UI.state.showPauseMenu then
        -- Game is paused, no game logic updates
        return
    end

    -- If not paused, proceed with other game logic:
    if not UI.state.showUpgradeTree then
        Player.update(dt) -- Update player input and state first

        -- Provider functions for Enemies.update
        local realmProvider = function() return Game.getPlayerRealm() end
        local killsProvider = function() return Player.data.kills end

        -- Enemies.update now uses callbacks passed from Game.update for damage/loot
        Enemies.update(dt, Player.data, realmProvider, killsProvider)

        -- Game.update handles bullets, collisions (which then calls Enemies.damage... with callbacks), loot, level up etc.
        Game.update(dt, Player, Enemies, Config, utils) -- Pass global Config
    end

    -- Continuous camera movement for upgrade tree (only if tree is visible and game not paused)
    if UI.state.showUpgradeTree then -- Check if tree is visible (implicitly not paused due to check above)
        local moveAmount = upgradeTreeCameraSpeed * dt
        if love.keyboard.isDown("left") then
            UI.moveUpgradeTreeCamera(-moveAmount, 0) -- To see left, decrease offset.x
        end
        if love.keyboard.isDown("right") then
            UI.moveUpgradeTreeCamera(moveAmount, 0) -- To see right, increase offset.x
        end
        if love.keyboard.isDown("up") then
            UI.moveUpgradeTreeCamera(0, -moveAmount) -- To see up, decrease offset.y
        end
        if love.keyboard.isDown("down") then
            UI.moveUpgradeTreeCamera(0, moveAmount) -- To see down, increase offset.y
        end
    end
end

function love.draw()
    Player.draw()
    Enemies.draw()
    Game.draw() -- Draws bullets and loot

    -- UI drawing uses getters from Game module for realm info
    UI.drawHUD(Player.data, Game.getPlayerRealm())
    UI.drawInventory(Player.data.gold, Player.data.essence.tier1, Player.data.essence.tier2)
    UI.drawRealmList(Game.getRealmsTable(), Game.getPlayerRealm())
    UI.drawUpgradeTree(Upgrades.getNodes(), Upgrades.effectParams) -- Pass effectParams
    UI.drawStatsMenu(Player.data) -- Add this line
    UI.drawPauseMenu() -- Draw pause menu on top
end

function love.keypressed(key)
    if key == "m" then
        UI.toggleUpgradeTree()
    end

    if key == "tab" then
        UI.toggleInventory()
    end

    if key == "r" then
        UI.toggleRealmList()
    end

    if key == "t" then
        Game.changeRealm(-1, Player, Enemies) -- Pass Player and Enemies
    end

    if key == "y" then
        Game.changeRealm(1, Player, Enemies) -- Pass Player and Enemies
    end

    -- Changed elseif to if for the 'c' key to make it an independent condition
    if key == "c" then
        Player.craftTier2Essence()
    end

    if key == "k" then -- Or any preferred key
        UI.toggleStatsMenu()
    end

    if key == "escape" then
        UI.togglePauseMenu()
    end
end

function love.mousepressed(x, y, button)
    if button == 1 then
        if UI.state.showPauseMenu then
            -- UI.pauseMenuButtons is populated by UI.drawPauseMenu
            if UI.pauseMenuButtons then
                for _, btn in ipairs(UI.pauseMenuButtons) do
                    if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
                        if btn.label == "Continue" then
                            UI.togglePauseMenu()
                        elseif btn.label == "Settings" then
                            print("Settings clicked - Placeholder") -- Placeholder
                        elseif btn.label == "Credits" then
                            print("Credits clicked - Placeholder") -- Placeholder
                        elseif btn.label == "Quit" then
                            love.event.quit()
                        end
                        return -- Click handled by pause menu
                    end
                end
            end
            return -- Click was on the overlay but not on a button, consume it
        end

        -- If not paused, check other UI elements (e.g., Upgrade Tree)
        if UI.state.showUpgradeTree then
            local currentNodes = Upgrades.getNodes()
            local treeZoom = UI.treeZoom or 1.0 -- Ensure fallback if not set
        local treeOffsetX = UI.treeOffset and UI.treeOffset.x or 0
        local treeOffsetY = UI.treeOffset and UI.treeOffset.y or 0

        local screenWidth = love.graphics.getWidth()
        local screenHeight = love.graphics.getHeight()

        -- Apply inverse transformation to mouse coordinates
        love.graphics.push()
        love.graphics.translate(screenWidth / 2, screenHeight / 2)
        love.graphics.scale(treeZoom, treeZoom)
        love.graphics.translate(-screenWidth / 2 + treeOffsetX, -screenHeight / 2 + treeOffsetY)
        local worldX, worldY = love.graphics.inverseTransformPoint(x, y)
        love.graphics.pop()

        local nodeRadius = 15 -- Base model radius in world coordinates

        local clickedOnNode = false
        for idx, node_obj in ipairs(currentNodes) do
            if utils.distance(worldX, worldY, node_obj.x, node_obj.y) <= nodeRadius then
                Upgrades.upgradeNode(idx, Player)
                clickedOnNode = true
                break
            end
        end

        if not clickedOnNode then
            isDraggingTree = true
            lastMouseX, lastMouseY = x, y -- Store initial position for dragging
        end
    end
end

function love.mousereleased(x, y, button)
    if button == 1 then
        isDraggingTree = false
    end
end

function love.mousemoved(x, y, dx, dy, istouch)
    if isDraggingTree then
        -- UI.moveUpgradeTreeCamera adds its arguments to UI.treeOffset.
        -- If mouse dx > 0 (moves right), tree content should move left on screen, meaning treeOffset.x decreases.
        UI.moveUpgradeTreeCamera(-dx, -dy)
    end
end

function love.wheelmoved(wx, wy) -- wx is horizontal scroll (usually 0), wy is vertical scroll (+1 up, -1 down)
    if UI.state.showUpgradeTree then
        local zoomSpeed = 0.1
        if wy > 0 then -- Scrolled up, zoom in
            UI.treeZoom = UI.treeZoom + zoomSpeed
        elseif wy < 0 then -- Scrolled down, zoom out
            UI.treeZoom = UI.treeZoom - zoomSpeed
        end
        UI.treeZoom = math.max(UI.MIN_ZOOM, math.min(UI.MAX_ZOOM, UI.treeZoom)) -- Clamp zoom
    end
end

-- Removed initializeRealms, dropLoot, resetEnemies as they are now in Game module

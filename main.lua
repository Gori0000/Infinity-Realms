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
    Player.update(dt) -- Update player input and state first

    -- Provider functions for Enemies.update
    local realmProvider = function() return Game.getPlayerRealm() end
    local killsProvider = function() return Player.data.kills end

    -- Enemies.update now uses callbacks passed from Game.update for damage/loot
    Enemies.update(dt, Player.data, realmProvider, killsProvider)

    -- Game.update handles bullets, collisions (which then calls Enemies.damage... with callbacks), loot, level up etc.
    Game.update(dt, Player, Enemies, Config, utils) -- Pass global Config
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

    if key == "left" then
        UI.moveUpgradeTreeCamera(20, 0)
    end

    if key == "right" then
        UI.moveUpgradeTreeCamera(-20, 0)
    end

    if key == "up" then
        UI.moveUpgradeTreeCamera(0, 20)
    end

    if key == "down" then
        UI.moveUpgradeTreeCamera(0, -20)
    end
end

function love.mousepressed(x, y, button)
    if button == 1 and UI.state.showUpgradeTree then
        local currentNodes = Upgrades.getNodes()
        for idx, node in ipairs(currentNodes) do
            if utils.distance(x, y, node.x + UI.treeOffset.x, node.y + UI.treeOffset.y) <= 15 then
                Upgrades.upgradeNode(idx, Player) -- Pass Player module
                break
            end
        end
    end
end

-- Removed initializeRealms, dropLoot, resetEnemies as they are now in Game module

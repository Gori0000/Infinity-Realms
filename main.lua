local upgradeTreeCameraSpeed = 300 -- pixels per second for tree camera movement
local isDraggingTree = false
local lastMouseX, lastMouseY = 0, 0

function love.load()
    -- Load core modules first
    Config = require("config") -- Made global with capital
    DebugSettings = require("debug_settings") -- Load debug settings
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
    SpellsData = require("spells") -- Load spell definitions
    ItemsData = require("items") -- Load item definitions

    -- Initialize modules that require it
    Enemies.initialize()
    Upgrades.initializeTree()
    Game.initializeRealms()
    if Player.initializeAnimation and Assets.player_spritesheet then
        Player.initializeAnimation(Assets.player_spritesheet)
    elseif Player.initializeAnimation then
        print("Warning: Assets.player_spritesheet not available for Player.initializeAnimation.")
    end
    Player.initializeSpells(SpellsData) -- Initialize player's spell slots

    -- Initialize spell tree definitions after SpellsData is loaded
    if Upgrades and Upgrades.initializeSpellTreeDefinition then
        for spellId, baseData in pairs(SpellsData) do
            Upgrades.initializeSpellTreeDefinition(spellId, baseData)
        end
    else
        print("Error: Upgrades.initializeSpellTreeDefinition not found.")
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
        -- Also pass Player.data and Game module for status effect death callbacks
        Enemies.update(dt, Player.data, realmProvider, killsProvider, Player.data, Game)

        -- Game.update handles bullets, collisions (which then calls Enemies.damage... with callbacks), loot, level up etc.
        -- Pass DebugSettings instead of Config to Game.update
        Game.update(dt, Player, Enemies, DebugSettings, utils)
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

    -- Conditional drawing for Upgrade Tree
    if UI.state.showUpgradeTree then
        if UI.state.currentUpgradeTreeView == "player" then
            UI.drawUpgradeTree(Upgrades.getNodes(), Upgrades.effectParams, Upgrades.nodes, "player")
        elseif UI.state.currentUpgradeTreeView == "spell" then
            local spellInstance = Player.data.spells[UI.state.currentSpellSlotView]
            if spellInstance and spellInstance.id and Upgrades.spellTreeDefinitions and Upgrades.spellTreeDefinitions[spellInstance.id] then
                local treeDef = Upgrades.spellTreeDefinitions[spellInstance.id]
                UI.drawUpgradeTree(treeDef.nodes, Upgrades.spellEffectParams, spellInstance.upgrades, spellInstance.id)
            else
                -- Draw an empty tree or placeholder if spell/definition not found
                UI.drawUpgradeTree(nil, Upgrades.spellEffectParams, {}, "No Spell/Invalid Slot " .. UI.state.currentSpellSlotView)
            end
        end
    end

    UI.drawSpellSlots(Player.data.spells) -- Draw spell slots HUD
    UI.drawStatsMenu(Player.data) -- Add this line
    UI.drawPauseMenu() -- Draw pause menu on top
    UI.drawDebugMenu() -- Draw debug menu on top of everything if active
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

    -- Spell casting keys
    if key == "1" or key == "2" or key == "3" or key == "4" or key == "5" then
        if not UI.state.showPauseMenu and Player and Player.castSpell then -- Ensure game is not paused
            local slotIndex = tonumber(key)
            local mx, my = love.mouse.getPosition()
            Player.castSpell(slotIndex, mx, my)
            -- print("Attempted to cast spell in slot " .. slotIndex .. " at " .. mx .. "," .. my)
        end
    end
end

function love.mousepressed(x, y, button) -- Function definition starts here (around line 166)
    if button == 1 then
        if UI.state.showPauseMenu then
            -- UI.pauseMenuButtons is populated by UI.drawPauseMenu
            if UI.pauseMenuButtons then
                for _, btn in ipairs(UI.pauseMenuButtons) do
                    if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
                        if btn.label == "Continue" then
                            UI.togglePauseMenu()
                        elseif btn.label == "Settings" then
                            UI.state.showPauseMenu = false
                            UI.state.showDebugMenu = true
                            print("Settings clicked - Opening Debug Menu")
                        elseif btn.label == "Credits" then
                            print("Credits clicked - Placeholder") -- Placeholder
                        elseif btn.label == "Quit" then
                            love.event.quit()
                        end -- closes: if btn.label == "..."
                        return -- Click handled by pause menu
                    end -- closes: if x >= btn.x ...
                end -- closes: for _, btn ...
            end -- closes: if UI.pauseMenuButtons
            return -- Click was on the overlay but not on a button, consume it

        elseif UI.state.showDebugMenu then -- IMPORTANT: Use elseif here
            if UI.debugMenuControls then
                for _, control in ipairs(UI.debugMenuControls) do
                    if x >= control.x and x <= control.x + control.w and y >= control.y and y <= control.y + control.h then
                        if control.action == "inc" then
                            DebugSettings[control.paramKey] = math.min(control.max, (DebugSettings[control.paramKey] or 0) + control.step)
                            print("DebugSettings." .. control.paramKey .. " increased to " .. DebugSettings[control.paramKey])
                            if control.paramKey == "uiScaleFactor" or control.paramKey == "baseFontSize" then -- Font needs recreation
                                local effectiveFontSize = (DebugSettings.baseFontSize or 14) * (DebugSettings.uiScaleFactor or 1)
                                font = love.graphics.newFont(math.floor(effectiveFontSize))
                                love.graphics.setFont(font)
                            end
                        elseif control.action == "dec" then
                            DebugSettings[control.paramKey] = math.max(control.min, (DebugSettings[control.paramKey] or 0) - control.step)
                            print("DebugSettings." .. control.paramKey .. " decreased to " .. DebugSettings[control.paramKey])
                            if control.paramKey == "uiScaleFactor" or control.paramKey == "baseFontSize" then -- Font needs recreation
                                local effectiveFontSize = (DebugSettings.baseFontSize or 14) * (DebugSettings.uiScaleFactor or 1)
                                font = love.graphics.newFont(math.floor(effectiveFontSize))
                                love.graphics.setFont(font)
                            end
                        elseif control.action == "reset_debug" then
                            if DebugSettings.originalDefaults then
                                for k_param, v_param in pairs(DebugSettings.originalDefaults) do
                                    DebugSettings[k_param] = v_param
                                end
                                print("DebugSettings reset to original defaults.")
                                -- Font needs recreation after reset
                                local effectiveFontSize = (DebugSettings.baseFontSize or 14) * (DebugSettings.uiScaleFactor or 1)
                                font = love.graphics.newFont(math.floor(effectiveFontSize))
                                love.graphics.setFont(font)
                            else
                                print("Error: DebugSettings.originalDefaults not found!")
                            end
                        elseif control.action == "close_debug" then
                            UI.state.showDebugMenu = false
                            UI.state.showPauseMenu = true -- Go back to the pause menu
                            print("Closed Debug Menu, returning to Pause Menu.")
                        end
                        return -- Click handled by debug menu control
                    end
                end
            end
            return -- Click was inside debug menu area but not on a specific control, consume it

        elseif UI.state.showUpgradeTree then -- Use elseif here
            -- First, check for clicks on tree view switch buttons
            if UI.upgradeTreeViewSwitchButtons then
                for _, switchBtn in ipairs(UI.upgradeTreeViewSwitchButtons) do
                    if x >= switchBtn.x and x <= switchBtn.x + switchBtn.w and y >= switchBtn.y and y <= switchBtn.y + switchBtn.h then
                        if switchBtn.id == "Player Tree" then
                            UI.state.currentUpgradeTreeView = "player"
                        elseif string.sub(switchBtn.id, 1, 5) == "Spell" then
                            UI.state.currentUpgradeTreeView = "spell"
                            UI.state.currentSpellSlotView = tonumber(string.sub(switchBtn.id, 7))
                        end -- closes: if switchBtn.id == "Player Tree" ...
                        return -- Click handled by switch button
                    end -- closes: if x >= switchBtn.x ... (for switchBtn)
                end -- closes: for _, switchBtn ...
            end -- closes: if UI.upgradeTreeViewSwitchButtons

            -- If no switch button clicked, then check for node clicks
            local nodesToSearch
            -- local currentEffectParams -- Not used here for click logic directly
            -- local upgradesSource -- Not used here for click logic directly
            -- local treeIdForUpgrade -- Not used here for click logic directly
            local isPlayerTree = (UI.state.currentUpgradeTreeView == "player")

            if isPlayerTree then
                nodesToSearch = Upgrades.getNodes()
            else -- Spell tree
                local spellInstance = Player.data.spells[UI.state.currentSpellSlotView]
                if spellInstance and spellInstance.id and Upgrades.spellTreeDefinitions and Upgrades.spellTreeDefinitions[spellInstance.id] then
                    local treeDef = Upgrades.spellTreeDefinitions[spellInstance.id]
                    nodesToSearch = treeDef.nodes
                else
                    nodesToSearch = {} -- No nodes to search if spell/tree not found
                end -- closes: if spellInstance and ... (for spell tree node search assignment)
            end -- closes: if isPlayerTree then ... else ...

            if not nodesToSearch or #nodesToSearch == 0 then
                -- If no nodes (e.g. empty spell slot), allow dragging
                isDraggingTree = true
                lastMouseX, lastMouseY = x, y
                return
            end -- closes: if not nodesToSearch or #nodesToSearch == 0

            local treeZoom = UI.treeZoom or 1.0
            local treeOffsetX = UI.treeOffset and UI.treeOffset.x or 0
            local treeOffsetY = UI.treeOffset and UI.treeOffset.y or 0

            local screenWidth = love.graphics.getWidth()
            local screenHeight = love.graphics.getHeight()

            love.graphics.push()
            love.graphics.translate(screenWidth / 2, screenHeight / 2)
            love.graphics.scale(treeZoom, treeZoom)
            love.graphics.translate(-screenWidth / 2 + treeOffsetX, -screenHeight / 2 + treeOffsetY)
            local worldX, worldY = love.graphics.inverseTransformPoint(x, y)
            love.graphics.pop()

            local nodeRadius = 15
            local clickedOnNode = false
            for _, node_obj in ipairs(nodesToSearch) do
                if utils.distance(worldX, worldY, node_obj.x, node_obj.y) <= nodeRadius then
                    if isPlayerTree then
                        Upgrades.upgradeNode(node_obj.id, Player)
                    else
                        local spellInstance = Player.data.spells[UI.state.currentSpellSlotView]
                        -- Ensure spellInstance and treeDef are valid before upgrading
                        if spellInstance and spellInstance.id and Upgrades.spellTreeDefinitions and Upgrades.spellTreeDefinitions[spellInstance.id] then
                            local treeDef = Upgrades.spellTreeDefinitions[spellInstance.id]
                            Upgrades.upgradeSpellNode(spellInstance, node_obj.id, treeDef, Player.data)
                        else
                            print("Error: Attempted to upgrade node for invalid spell/slot: " .. UI.state.currentSpellSlotView)
                        end -- closes: if spellInstance and ... (for upgrade call)
                    end -- closes: if isPlayerTree then ... else ... (for upgrade call)
                    clickedOnNode = true
                    break
                end -- closes: if utils.distance ...
            end -- closes: for _, node_obj ... (node click check)

            if not clickedOnNode then
                isDraggingTree = true
                lastMouseX, lastMouseY = x, y
            end -- closes: if not clickedOnNode
        end -- closes: if UI.state.showUpgradeTree then
    end -- closes: if button == 1 then
end -- closes: function love.mousepressed

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

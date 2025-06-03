local Upgrades = {}
local utils = require("utils") -- Required for distance calculation

Upgrades.effectParams = {
    DMG = {
        name = "Damage Bonus",
        base = 100,
        falloff = 0.98,
        unit = "%"
    },
    CDR = {
        name = "Cooldown Reduction",
        base = 50,
        falloff = 0.97,
        unit = "%"
    },
    HP_MAX = {
        name = "Max HP Bonus",
        base = 500,
        falloff = 0.99,
        unit = "flat"
    },
    MOVE_SPEED = {
        name = "Movement Speed",
        base = 50,
        falloff = 0.98,
        unit = "%"
    }
}

Upgrades.spellTreeDefinitions = {} -- To store each spell's unique tree structure template
Upgrades.spellEffectParams = {
    SPELL_DMG = { name = "Damage Inc.", base = 50, falloff = 0.9, unit = "%" },
    SPELL_CDR = { name = "Cooldown Red.", base = 30, falloff = 0.9, unit = "%" },
    SPELL_RANGE = { name = "Range Inc.", base = 100, falloff = 0.85, unit = "units" },
    SPELL_AOE = { name = "AoE Inc.", base = 50, falloff = 0.88, unit = "%" },
    SPELL_PIERCE = { name = "Pierce Inc.", base = 3, falloff = 0.7, unit = "hits" }
    -- Future: SPELL_DURATION, SPELL_EFFECT_STRENGTH, etc.
}

Upgrades.nodes = {}

function Upgrades.categorizeNode(node)
    if not node.category then
        if node.id % 3 == 1 then node.category = "Offense"
        elseif node.id % 3 == 2 then node.category = "Defense"
        else node.category = "Support" end
    end
end

function Upgrades.recalculatePlayerBonuses(Player, nodes)
    if not Player or not Player.data then
        print("Warning: Player data not available for recalculatePlayerBonuses.")
        return
    end

    local totalLevels = {}
    for _, node in ipairs(nodes) do
        node.maxed = false
        local effectType = node.effect

        if Upgrades.effectParams[effectType] then
            totalLevels[effectType] = totalLevels[effectType] or 0
            totalLevels[effectType] = totalLevels[effectType] + node.level

            if node.level == node.maxLevel then
                node.maxed = true
                totalLevels[effectType] = totalLevels[effectType] + 3
            end
        end
    end

    Player.data.calculatedBonuses = {}

    for effectType, currentTotalLevel in pairs(totalLevels) do
        local params = Upgrades.effectParams[effectType]
        if params then
            local finalValue = params.base * (1 - params.falloff ^ currentTotalLevel)
            Player.data.calculatedBonuses[effectType] = finalValue
        end
    end

    if Player.applyCalculatedBonuses then
        Player.applyCalculatedBonuses()
    else
        print("Warning: Player.applyCalculatedBonuses function not found on Player object.")
    end
end

function Upgrades.initializeTree()
    Upgrades.nodes = {} -- Clear existing nodes

    local uiScale = (Config and Config.uiScaleFactor) or 1
    if not Config then
        print("Warning: Global Config not found in Upgrades.initializeTree, using uiScale=1")
    end

    local centerX = (Config and Config.windowWidth or 1920) / 2
    local centerY = (Config and Config.windowHeight or 1080) / 2

    -- Define base offsets for the triangular layout
    -- These values make them "closer to center"
    local baseVerticalOffset = 100 -- Reduced from 280
    local baseHorizontalOffset = 120 -- Reduced from 320

    -- Apply UI scaling to offsets
    local verticalOffset = baseVerticalOffset * uiScale
    local horizontalOffset = baseHorizontalOffset * uiScale

    -- Define the three initial nodes with specific categories and positions

    -- Top Node (Support) - Green
    local supportNode = {
        id = 1,
        x = centerX,
        y = centerY - verticalOffset, -- Positioned towards the top
        level = 0, maxLevel = 10,
        effect = "CDR", -- Cooldown Reduction is a common support effect
        category = "Support",
        children = {},
        maxed = false
    }

    -- Bottom-Left Node (Defense) - Blue
    local defenseNode = {
        id = 2,
        x = centerX - horizontalOffset, -- Positioned to the bottom-left
        y = centerY + verticalOffset,
        level = 0, maxLevel = 10,
        effect = "HP_MAX", -- Max HP is a common defense effect
        category = "Defense",
        children = {},
        maxed = false
    }

    -- Bottom-Right Node (Offense) - Red
    local offenseNode = {
        id = 3,
        x = centerX + horizontalOffset, -- Positioned to the bottom-right
        y = centerY + verticalOffset,
        level = 0, maxLevel = 10,
        effect = "DMG", -- Damage is a common offense effect
        category = "Offense",
        children = {},
        maxed = false
    }

    table.insert(Upgrades.nodes, supportNode)
    table.insert(Upgrades.nodes, defenseNode)
    table.insert(Upgrades.nodes, offenseNode)

    print("Upgrades.initializeTree: Created new triangular layout. Top (Support), BL (Defense), BR (Offense).")
    print("  Support Node (ID 1): x=" .. supportNode.x .. ", y=" .. supportNode.y)
    print("  Defense Node (ID 2): x=" .. defenseNode.x .. ", y=" .. defenseNode.y)
    print("  Offense Node (ID 3): x=" .. offenseNode.x .. ", y=" .. offenseNode.y)
end

function Upgrades.expandTree(nodeToExpand)
    if not nodeToExpand then
        print("Error: expandTree called with nil nodeToExpand.")
        return
    end

    local uiScale = (Config and Config.uiScaleFactor) or 1
    if not Config then
        print("Warning: Global Config not found in Upgrades.expandTree, using uiScale=1")
    end

    local centerX = (Config and Config.windowWidth or 1920) / 2
    local centerY = (Config and Config.windowHeight or 1080) / 2

    print("Attempting to expand node ID:", nodeToExpand.id, "Category:", nodeToExpand.category, "at (", nodeToExpand.x, ",", nodeToExpand.y, ")")

    local parentNode = nodeToExpand
    -- The 'distance' variable determines how far children are from parent.
    -- This will be reviewed in the "Reduce Upgrade Tree Size" step.
    local expansion_distance = 60 * uiScale

    local dirX = parentNode.x - centerX
    local dirY = parentNode.y - centerY
    local baseAngle

    if math.abs(dirX) < 0.01 and math.abs(dirY) < 0.01 then -- Check if parent is effectively at the center
        print("  Info: Parent node is at or near the center. Using default upward base angle for expansion.")
        baseAngle = -math.pi / 2 -- Default to upward expansion
    else
        baseAngle = math.atan2(dirY, dirX)
    end

    local spreadAngleOffset = math.pi / 6 -- 30 degrees spread from baseAngle

    -- Define two potential children based on angles
    local potentialChildrenData = {
        { angle = baseAngle - spreadAngleOffset, name = "Child 1 (angle - offset)" },
        { angle = baseAngle + spreadAngleOffset, name = "Child 2 (angle + offset)" }
    }

    local nodeVisualRadius = 15 * uiScale -- Used for collision checking
    local buffer = 10 * uiScale           -- Buffer space between nodes
    local minSpacing = (nodeVisualRadius * 2) + buffer
    local childrenAddedCount = 0

    for _, childInfo in ipairs(potentialChildrenData) do
        local targetX = parentNode.x + expansion_distance * math.cos(childInfo.angle)
        local targetY = parentNode.y + expansion_distance * math.sin(childInfo.angle)
        print("  Prospective " .. childInfo.name .. " target coords: (", targetX, ",", targetY, ") angle: ", childInfo.angle)

        local collisionDetected = false
        for _, existingNode in ipairs(Upgrades.nodes) do
            -- Essential: Do not check collision with the parent node itself
            if existingNode.id == parentNode.id then
                goto continue_collision_check
            end

            if utils.distance(targetX, targetY, existingNode.x, existingNode.y) < minSpacing then
                collisionDetected = true
                print("    Collision DETECTED for " .. childInfo.name .. " with existing node ID:", existingNode.id, "at (", existingNode.x, ",", existingNode.y, "). Dist:", utils.distance(targetX, targetY, existingNode.x, existingNode.y), "MinSpacing:", minSpacing)
                break -- Stop checking for this child, it collides
            end
            ::continue_collision_check::
        end

        if not collisionDetected then
            local newId = #Upgrades.nodes + 1
            local availableEffects = {}
            for key, _ in pairs(Upgrades.effectParams) do
                table.insert(availableEffects, key)
            end
            local effectKey = availableEffects[math.random(#availableEffects)]

            local newNode = {
                id = newId,
                x = targetX,
                y = targetY,
                level = 0,
                maxLevel = 10,
                effect = effectKey,
                category = parentNode.category, -- Inherit category from parent
                children = {},
                maxed = false
            }
            -- Upgrades.categorizeNode(newNode) -- This can be called if new nodes need re-categorization based on ID or other rules

            table.insert(parentNode.children, newNode) -- Link child to parent
            table.insert(Upgrades.nodes, newNode)     -- Add to global list of nodes
            childrenAddedCount = childrenAddedCount + 1
            print("    Expansion SUCCEEDED for " .. childInfo.name .. ". New child ID:", newNode.id, "Category:", newNode.category, "Effect:", newNode.effect)
        else
            print("    Expansion SKIPPED for " .. childInfo.name .. " due to collision.")
        end
    end

    if childrenAddedCount == 0 then
        print("  Expansion FAILED for node ID:", parentNode.id, "- no valid positions found for any new children.")
    else
        print("  Expansion completed for node ID:", parentNode.id, ". Added " .. childrenAddedCount .. " child/children.")
    end
end

function Upgrades.upgradeNode(nodeId, Player)
    local nodeToUpgrade = nil
    if nodeId >= 1 and nodeId <= #Upgrades.nodes then -- Ensure nodeId is within bounds
        nodeToUpgrade = Upgrades.nodes[nodeId]
    end

    if not nodeToUpgrade then
        print("Attempted to upgrade non-existent or out-of-bounds node with ID: " .. tostring(nodeId))
        return false
    end

    -- Node exists, now check if it can be upgraded
    if nodeToUpgrade.level < nodeToUpgrade.maxLevel then
        -- Check for skill points
        -- Ensure Player and Player.data exist before trying to access skillPoints
        if Player and Player.data and (Player.data.skillPoints or 0) >= 1 then
            Player.data.skillPoints = Player.data.skillPoints - 1 -- Spend the point

            nodeToUpgrade.level = nodeToUpgrade.level + 1
            Upgrades.recalculatePlayerBonuses(Player, Upgrades.nodes)

            if nodeToUpgrade.level == 5 then -- Expansion trigger (as per previous modifications)
                if #nodeToUpgrade.children == 0 then
                    Upgrades.expandTree(nodeToUpgrade)
                end
            end
            print("Node " .. nodeToUpgrade.id .. " upgraded to level " .. nodeToUpgrade.level .. ". Skill points remaining: " .. Player.data.skillPoints)
            return true
        else
            -- Not enough skill points or Player/Player.data is nil
            local currentPoints = "N/A"
            if Player and Player.data and Player.data.skillPoints ~= nil then
                currentPoints = Player.data.skillPoints
            elseif Player and Player.data then
                 currentPoints = "0 (field missing?)"
            end
            print("Attempted to upgrade node " .. nodeToUpgrade.id .. " but not enough skill points. Current points: " .. currentPoints)
            return false
        end
    else
        -- Node is already at max level
        print("Attempted to upgrade node " .. nodeToUpgrade.id .. " but it's already at max level (" .. nodeToUpgrade.level .. "/" .. nodeToUpgrade.maxLevel .. ").")
        return false
    end
end

function Upgrades.getNodes()
    return Upgrades.nodes
end

-- For Spell Upgrade Trees
function Upgrades.initializeSpellTreeDefinition(spellId, baseSpellData)
    local treeNodes = {}
    -- Create a simple, standardized tree for now. E.g., 3 nodes.
    -- Positions are relative for now, can be laid out better in UI.drawUpgradeTree later.
    -- These x,y are more like abstract positions or could be used if drawing them on a fixed small grid.

    -- Node 1: Damage
    table.insert(treeNodes, {
        id = 1, x = 100, y = 100, level = 0, maxLevel = 10, -- Level here is maxLevel for the definition
        effect = "SPELL_DMG", category = "Offense", children = {}, maxed = false,
        name = "Damage", description = "Increases spell damage."
    })

    -- Node 2: Cooldown
    table.insert(treeNodes, {
        id = 2, x = 100, y = 200, level = 0, maxLevel = 10,
        effect = "SPELL_CDR", category = "Utility", children = {}, maxed = false,
        name = "Cooldown", description = "Reduces spell cooldown."
    })

    -- Node 3: Utility (Range for projectiles/beams, AoE for AoE spells)
    local utilityEffect = "SPELL_RANGE"
    local utilityName = "Range/Effect"
    local utilityDesc = "Increases range or area of effect."
    if baseSpellData.type == "aoe_centered" then
        utilityEffect = "SPELL_AOE"
    elseif baseSpellData.type == "projectile" and baseSpellData.aoeRadius > 0 then
         utilityEffect = "SPELL_AOE" -- If projectile has an AoE component, upgrade that
    end

    table.insert(treeNodes, {
        id = 3, x = 100, y = 300, level = 0, maxLevel = 10,
        effect = utilityEffect, category = "Utility", children = {}, maxed = false,
        name = utilityName, description = utilityDesc
    })

    -- Pierce node if applicable for projectiles
    if baseSpellData.type == "projectile" then
        table.insert(treeNodes, {
            id = 4, x = 100, y = 400, level = 0, maxLevel = 5, -- Max 5 levels for pierce
            effect = "SPELL_PIERCE", category = "Offense", children = {}, maxed = false,
            name = "Pierce", description = "Increases projectile pierce count."
        })
    end

    Upgrades.spellTreeDefinitions[spellId] = { nodes = treeNodes }
    -- print("Initialized spell tree definition for: " .. spellId)
end

function Upgrades.recalculateSpellStats(playerSpellInstance, spellTreeDefinition)
    if not playerSpellInstance or not spellTreeDefinition then
        -- print("Warning: Missing playerSpellInstance or spellTreeDefinition for recalculateSpellStats.")
        return
    end

    -- Reset to base stats before applying bonuses
    playerSpellInstance.calculatedDamage = playerSpellInstance.baseDamage
    playerSpellInstance.calculatedCooldown = playerSpellInstance.baseCooldown
    playerSpellInstance.calculatedRange = playerSpellInstance.baseRange
    playerSpellInstance.calculatedAoeRadius = playerSpellInstance.baseAoeRadius
    playerSpellInstance.calculatedPierce = playerSpellInstance.basePierce
    -- calculatedEffects might need more complex logic later

    for _, nodeDef in ipairs(spellTreeDefinition.nodes) do
        local nodeLevel = playerSpellInstance.upgrades[nodeDef.id] or 0
        if nodeLevel > 0 then
            local effectParams = Upgrades.spellEffectParams[nodeDef.effect]
            if effectParams then
                local bonus = effectParams.base * (1 - effectParams.falloff ^ nodeLevel)

                if nodeDef.effect == "SPELL_DMG" then
                    playerSpellInstance.calculatedDamage = playerSpellInstance.calculatedDamage * (1 + bonus / 100)
                elseif nodeDef.effect == "SPELL_CDR" then
                    playerSpellInstance.calculatedCooldown = playerSpellInstance.calculatedCooldown * (1 - bonus / 100)
                elseif nodeDef.effect == "SPELL_RANGE" then
                    playerSpellInstance.calculatedRange = playerSpellInstance.calculatedRange + bonus
                elseif nodeDef.effect == "SPELL_AOE" then
                    playerSpellInstance.calculatedAoeRadius = playerSpellInstance.calculatedAoeRadius * (1 + bonus / 100)
                elseif nodeDef.effect == "SPELL_PIERCE" then
                    playerSpellInstance.calculatedPierce = playerSpellInstance.calculatedPierce + bonus
                end
            end
        end
    end
    -- print("Recalculated stats for spell: " .. playerSpellInstance.id .. ", Dmg: " .. playerSpellInstance.calculatedDamage)
end

function Upgrades.upgradeSpellNode(playerSpellInstance, nodeId, spellTreeDefinition, playerData)
    if not playerSpellInstance or not spellTreeDefinition or not playerData then
        print("Error: Missing arguments for Upgrades.upgradeSpellNode.")
        return false
    end

    local nodeToUpgrade = nil
    for _, nodeDef in ipairs(spellTreeDefinition.nodes) do
        if nodeDef.id == nodeId then
            nodeToUpgrade = nodeDef
            break
        end
    end

    if not nodeToUpgrade then
        print("Attempted to upgrade non-existent spell node with ID: " .. tostring(nodeId) .. " for spell " .. playerSpellInstance.id)
        return false
    end

    local currentLevel = playerSpellInstance.upgrades[nodeId] or 0
    if currentLevel < nodeToUpgrade.maxLevel then
        if (playerData.spellUpgradePoints or 0) >= 1 then
            playerData.spellUpgradePoints = playerData.spellUpgradePoints - 1
            playerSpellInstance.upgrades[nodeId] = currentLevel + 1

            -- Mark as maxed if applicable (for spell tree nodes, this is just for data, UI might use it)
            if playerSpellInstance.upgrades[nodeId] == nodeToUpgrade.maxLevel then
                 -- We don't store 'maxed' bool directly in playerSpellInstance.upgrades,
                 -- but can check against nodeToUpgrade.maxLevel.
                 -- The 'nodeToUpgrade.maxed' in the definition is not per-instance.
            end

            Upgrades.recalculateSpellStats(playerSpellInstance, spellTreeDefinition)
            -- print("Spell node " .. nodeToUpgrade.id .. " for " .. playerSpellInstance.id .. " upgraded to level " .. playerSpellInstance.upgrades[nodeId] .. ". Spell points remaining: " .. playerData.spellUpgradePoints)
            return true
        else
            -- print("Not enough spell upgrade points for spell " .. playerSpellInstance.id .. ", node " .. nodeId)
            return false
        end
    else
        -- print("Spell node " .. nodeId .. " for " .. playerSpellInstance.id .. " already at max level.")
        return false
    end
end

return Upgrades

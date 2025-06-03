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

return Upgrades

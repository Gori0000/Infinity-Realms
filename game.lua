local Game = {}

Game.bullets = {}
Game.shootCooldown = 0
Game.currentRealm = 1
Game.realms = {}
Game.loot = {}
Game.activeSpells = {} -- For active spell effects

-- Base game mechanics values
local BASE_PROJECTILE_DAMAGE = 25
local BASE_SHOOT_COOLDOWN = 0.25
local MIN_SHOOT_COOLDOWN = 0.05 -- Minimum possible cooldown

function Game.initializeRealms()
    Game.realms = {}
    for i = 1, 10 do
        table.insert(Game.realms, "Realm " .. i)
    end
end

function Game.getPlayerRealm()
    return Game.currentRealm
end

function Game.getLootTable()
    return Game.loot
end

function Game.getBulletsTable()
    return Game.bullets
end

function Game.getRealmsTable()
    return Game.realms
end

function Game.triggerSpellEffect(playerOriginData, spellData, targetX, targetY)
    local spellInstance = {}
    if spellData.type == "projectile" then
        local angle = math.atan2(targetY - playerOriginData.y, targetX - playerOriginData.x)
        local projectileSpeed = spellData.projectileSpeed or 400 -- Use spellData or default
        spellInstance = {
            type = "projectile",
            spellId = spellData.id,
            name = spellData.name, -- For drawing/debugging
            x = playerOriginData.x,
            y = playerOriginData.y,
            dx = math.cos(angle) * projectileSpeed,
            dy = math.sin(angle) * projectileSpeed,
            radius = spellData.projectileRadius or 8, -- Define a radius for collision, default 8
            rangeRemaining = spellData.calculatedRange,
            damage = spellData.calculatedDamage,
            pierceRemaining = spellData.calculatedPierce,
            aoeRadiusOnHit = spellData.calculatedAoeRadius, -- For later, if projectile explodes
            effectsToApply = spellData.effects,
            owner = playerOriginData, -- Could be just player ID or reference
            hitEnemies = {} -- Store IDs of enemies hit
        }
    elseif spellData.type == "aoe_centered" then
        spellInstance = {
            type = "aoe_centered",
            spellId = spellData.id,
            name = spellData.name,
            x = playerOriginData.x,
            y = playerOriginData.y,
            radius = spellData.calculatedAoeRadius,
            damage = spellData.calculatedDamage,
            effectsToApply = spellData.effects,
            duration = 0.2, -- Short duration, processed once then removed
            alreadyHit = false,
            owner = playerOriginData
        }
    elseif spellData.type == "beam" then
        -- Basic beam, visual only for now mostly
        local beamAngle = math.atan2(targetY - playerOriginData.y, targetX - playerOriginData.x)
        local beamEndX = playerOriginData.x + math.cos(beamAngle) * spellData.calculatedRange
        local beamEndY = playerOriginData.y + math.sin(beamAngle) * spellData.calculatedRange
        spellInstance = {
            type = "beam",
            spellId = spellData.id,
            name = spellData.name,
            x1 = playerOriginData.x,
            y1 = playerOriginData.y,
            x2 = beamEndX, -- Actual end point of the beam line segment
            y2 = beamEndY,
            targetX = targetX, -- Original mouse target for drawing direction if needed beyond x2,y2
            targetY = targetY,
            range = spellData.calculatedRange, -- Max range, used for x2,y2 calculation
            width = spellData.calculatedAoeRadius, -- Use aoeRadius as beam width
            damage = spellData.calculatedDamage, -- This is DPS for the DoT
            effectsToApply = spellData.effects,
            duration = 0.5, -- Fixed duration for beam visual and one-time DoT application
            owner = playerOriginData,
            hitEnemiesThisCast = {} -- Enemies hit by this specific beam cast
        }
    else
        print("Game.triggerSpellEffect: Unknown spell type: " .. spellData.type)
        return
    end
    table.insert(Game.activeSpells, spellInstance)
end

function Game.handleChainEffect(firstHitEnemy, originalSpellData, playerData, config_arg, utils)
    local chainParams = originalSpellData.effectsToApply and originalSpellData.effectsToApply.chain or {}
    local maxChains = chainParams.count or 0
    local chainSearchRadius = chainParams.searchRadius or 200 -- Default if not specified
    local chainDamageMultiplier = chainParams.damageMultiplier or 1.0 -- Default if not specified
    local chainDamage = originalSpellData.damage * chainDamageMultiplier -- Use originalSpellData.damage which is calculatedDamage

    local currentChainTarget = firstHitEnemy
    local alreadyChainedTo = { [currentChainTarget] = true }
    local chainCount = 0

    -- print("Starting chain effect from enemy at: " .. currentChainTarget.x .. "," .. currentChainTarget.y)

    for c = 1, maxChains do
        local nearestNextTarget = nil
        local minDistance = chainSearchRadius

        -- Check regular enemies
        local currentEnemiesList = Enemies.getList()
        for i, potentialTarget in ipairs(currentEnemiesList) do
            if not alreadyChainedTo[potentialTarget] then
                local dist = utils.distance(currentChainTarget.x, currentChainTarget.y, potentialTarget.x, potentialTarget.y)
                if dist < minDistance then
                    minDistance = dist
                    nearestNextTarget = potentialTarget
                end
            end
        end

        -- Check boss
        local currentBoss = Enemies.getBoss()
        if currentBoss and not alreadyChainedTo[currentBoss] then
            local dist = utils.distance(currentChainTarget.x, currentChainTarget.y, currentBoss.x, currentBoss.y)
            if dist < minDistance then
                minDistance = dist
                nearestNextTarget = currentBoss
            end
        end

        if nearestNextTarget then
            chainCount = chainCount + 1
            alreadyChainedTo[nearestNextTarget] = true

            -- Add visual effect for the chain
            table.insert(Game.activeSpells, {
                type = "visual_chain_bolt",
                x1 = currentChainTarget.x, y1 = currentChainTarget.y,
                x2 = nearestNextTarget.x, y2 = nearestNextTarget.y,
                duration = 0.15, -- Short duration for visual
                color = {0.5, 0.5, 1, 0.8} -- Light blue
            })

            -- Apply damage
            if nearestNextTarget == currentBoss then -- Check if the nearest target is the boss
                 Enemies.damageBoss(nearestNextTarget, chainDamage,
                    function(exp) playerData.exp = playerData.exp + exp end,
                    function() playerData.kills = playerData.kills + 1 end,
                    function(lx, ly) Game.dropLoot(lx, ly, playerData) end)
            else
                -- Find index for regular enemy
                local enemyIndex = nil
                for idx, enemyInList in ipairs(currentEnemiesList) do
                    if enemyInList == nearestNextTarget then
                        enemyIndex = idx
                        break
                    end
                end
                if enemyIndex then
                    Enemies.damageEnemy(nearestNextTarget, chainDamage, enemyIndex,
                        function(exp) playerData.exp = playerData.exp + exp end,
                        function() playerData.kills = playerData.kills + 1 end,
                        function(lx, ly) Game.dropLoot(lx, ly, playerData) end)
                end
            end
            -- print("Chain " .. chainCount .. ": Hit enemy at " .. nearestNextTarget.x .. "," .. nearestNextTarget.y)
            currentChainTarget = nearestNextTarget
        else
            -- print("Chain effect ended: No more valid targets in range.")
            break -- No more valid targets
        end
    end
end


function Game.dropLoot(x, y, playerData)
    if math.random() < 0.5 then
        -- playerData.gold = playerData.gold + 1 -- Gold is now awarded on pickup
        table.insert(Game.loot, {x=x,y=y, type="coin", radius=8})
    end
    if math.random() < 0.05 then
        playerData.essence.tier1 = playerData.essence.tier1 + 1
        table.insert(Game.loot, {x=x,y=y, type="essence_t1", radius=8})
    end
    if math.random() < 0.02 then
        playerData.essence.tier2 = playerData.essence.tier2 + 1
        table.insert(Game.loot, {x=x,y=y, type="essence_t2", radius=8})
    end
end

local function calculateBulletDamage(bullet, playerData)
    local damageBonusPercent = (playerData.calculatedBonuses and playerData.calculatedBonuses.DMG) or 0
    return BASE_PROJECTILE_DAMAGE * (1 + damageBonusPercent / 100)
end

-- 'config_arg' here is the global 'Config' passed from main.lua
function Game.update(dt, Player, Enemies, config_arg, utils)
    Game.shootCooldown = Game.shootCooldown - dt

    local cooldownReductionPercent = (Player.data.calculatedBonuses and Player.data.calculatedBonuses.CDR) or 0
    local actualCooldown = BASE_SHOOT_COOLDOWN * (1 - cooldownReductionPercent / 100)
    actualCooldown = math.max(actualCooldown, MIN_SHOOT_COOLDOWN)

    if love.mouse.isDown(1) and Game.shootCooldown <= 0 then
        local mx, my = love.mouse.getPosition()
        local angle = math.atan2(my - Player.data.y, mx - Player.data.x)
        table.insert(Game.bullets, {
            x = Player.data.x, y = Player.data.y,
            dx = math.cos(angle) * 400,
            dy = math.sin(angle) * 400,
            radius = 5,
            type = "normal"
        })
        Game.shootCooldown = actualCooldown
    end

    for i = #Game.bullets, 1, -1 do
        local b = Game.bullets[i]
        if b then
            b.x, b.y = b.x + b.dx * dt, b.y + b.dy * dt
            if b.x < 0 or b.x > config_arg.windowWidth or b.y < 0 or b.y > config_arg.windowHeight then
                table.remove(Game.bullets, i)
            end
        end
    end

    for i = #Game.bullets, 1, -1 do
        local b = Game.bullets[i]
        if not b then goto next_bullet_enemy_collision end

        local currentEnemies = Enemies.getList()
        for j = #currentEnemies, 1, -1 do
            local e = currentEnemies[j]
            if e and utils.distance(b.x, b.y, e.x, e.y) < b.radius + e.radius then
                local damage = calculateBulletDamage(b, Player.data)
                local enemyDied = Enemies.damageEnemy(e, damage, j,
                    function(exp) Player.data.exp = Player.data.exp + exp end,
                    function() Player.data.kills = Player.data.kills + 1 end,
                    function(lx, ly) Game.dropLoot(lx, ly, Player.data) end)

                table.remove(Game.bullets, i)
                goto next_bullet_enemy_collision
            end
        end
        ::next_bullet_enemy_collision::
    end

    local currentBoss = Enemies.getBoss()
    if currentBoss then
        for i = #Game.bullets, 1, -1 do
            local b = Game.bullets[i]
            if not b then goto next_bullet_boss_collision end

            if utils.distance(b.x, b.y, currentBoss.x, currentBoss.y) < b.radius + currentBoss.radius then
                local damage = calculateBulletDamage(b, Player.data)
                local bossDied = Enemies.damageBoss(damage,
                    function(exp) Player.data.exp = Player.data.exp + exp end,
                    function() Player.data.kills = Player.data.kills + 1 end,
                    function(lx, ly) Game.dropLoot(lx, ly, Player.data) end)

                table.remove(Game.bullets, i)
            end
            ::next_bullet_boss_collision::
        end
    end

    -- Player-Loot collision (specifically for coins)
    for i = #Game.loot, 1, -1 do
        local l = Game.loot[i]
        if l and l.type == "coin" then
            -- Assuming Player.data.radius is defined and represents player's pickup radius
            local playerRadius = (Player.data and Player.data.radius) or 10 -- Fallback radius
            if utils.distance(Player.data.x, Player.data.y, l.x, l.y) < (playerRadius + l.radius) then
                Player.data.gold = Player.data.gold + 1
                table.remove(Game.loot, i)
            end
        end
    end

    if Player.data.exp >= Player.data.level * 100 then
        Player.data.exp = Player.data.exp - Player.data.level * 100
        Player.data.level = Player.data.level + 1
        Player.data.maxHp = Player.data.maxHp + 10
        Player.data.hp = Player.data.maxHp
        Player.data.skillPoints = (Player.data.skillPoints or 0) + 2
        Player.data.spellUpgradePoints = (Player.data.spellUpgradePoints or 0) + 2 -- Grant spell points
    end

    -- Update active spells
    for i = #Game.activeSpells, 1, -1 do
        local spell = Game.activeSpells[i]
        if not spell then goto next_spell_update end

        if spell.type == "projectile" then
            spell.x = spell.x + spell.dx * dt
            spell.y = spell.y + spell.dy * dt
            local distanceMoved = (spell.dx^2 + spell.dy^2)^0.5 * dt
            spell.rangeRemaining = spell.rangeRemaining - distanceMoved

            if spell.rangeRemaining <= 0 or
               spell.x < 0 or spell.x > config_arg.windowWidth or
               spell.y < 0 or spell.y > config_arg.windowHeight then
                table.remove(Game.activeSpells, i)
                goto next_spell_update
            end

            -- Projectile collision with enemies
            local currentEnemies = Enemies.getList()
            for j = #currentEnemies, 1, -1 do
                local e = currentEnemies[j]
                if e and not spell.hitEnemies[e] and utils.distance(spell.x, spell.y, e.x, e.y) < spell.radius + e.radius then
                    Enemies.damageEnemy(e, spell.damage, j,
                        function(exp) Player.data.exp = Player.data.exp + exp end,
                        function() Player.data.kills = Player.data.kills + 1 end,
                        function(lx, ly) Game.dropLoot(lx, ly, Player.data) end)

                    -- Apply status effects if any
                    if spell.effectsToApply and spell.effectsToApply.burn and spell.spellId == "Fireball" then
                        local burnEffect = spell.effectsToApply.burn
                        local burnDPS = spell.damage * burnEffect.dpsRatio -- spell.damage is calculatedDamage
                        Enemies.applyStatusEffect(e, "burn", burnEffect.duration, burnDPS)
                    elseif spell.effectsToApply and spell.effectsToApply.slow and spell.spellId == "IceLance" then
                        local slowEffect = spell.effectsToApply.slow
                        Enemies.applyStatusEffect(e, "slow", slowEffect.duration, slowEffect.magnitude)
                    end

                    if spell.effectsToApply and spell.effectsToApply.chain and spell.spellId == "ChainBolt" then
                        Game.handleChainEffect(e, spell, Player.data, config_arg, utils)
                        table.remove(Game.activeSpells, i) -- ChainBolt projectile is consumed
                        goto next_spell_update
                    end

                    spell.hitEnemies[e] = true -- Mark enemy as hit by this specific projectile instance
                    spell.pierceRemaining = spell.pierceRemaining - 1
                    if spell.pierceRemaining < 0 then
                        table.remove(Game.activeSpells, i)
                        goto next_spell_update
                    end
                end
            end

            local currentBoss = Enemies.getBoss()
            if currentBoss and not spell.hitEnemies[currentBoss] and utils.distance(spell.x, spell.y, currentBoss.x, currentBoss.y) < spell.radius + currentBoss.radius then
                 Enemies.damageBoss(currentBoss, spell.damage, -- Note: damageBoss doesn't take index
                    function(exp) Player.data.exp = Player.data.exp + exp end,
                    function() Player.data.kills = Player.data.kills + 1 end,
                    function(lx, ly) Game.dropLoot(lx, ly, Player.data) end)

                -- Apply status effects if any to boss
                if spell.effectsToApply and spell.effectsToApply.burn and spell.spellId == "Fireball" then
                    local burnEffect = spell.effectsToApply.burn
                    local burnDPS = spell.damage * burnEffect.dpsRatio
                    Enemies.applyStatusEffect(currentBoss, "burn", burnEffect.duration, burnDPS)
                elseif spell.effectsToApply and spell.effectsToApply.slow and spell.spellId == "IceLance" then
                    local slowEffect = spell.effectsToApply.slow
                    Enemies.applyStatusEffect(currentBoss, "slow", slowEffect.duration, slowEffect.magnitude)
                end

                if spell.effectsToApply and spell.effectsToApply.chain and spell.spellId == "ChainBolt" then
                    Game.handleChainEffect(currentBoss, spell, Player.data, config_arg, utils)
                    table.remove(Game.activeSpells, i) -- ChainBolt projectile is consumed
                    goto next_spell_update
                end

                spell.hitEnemies[currentBoss] = true
                spell.pierceRemaining = spell.pierceRemaining - 1
                 if spell.pierceRemaining < 0 then
                    table.remove(Game.activeSpells, i)
                    goto next_spell_update
                end
            end

        elseif spell.type == "aoe_centered" then
            if not spell.alreadyHit then
                local allEnemies = Enemies.getList()
                for _, e in ipairs(allEnemies) do
                    if utils.distance(spell.x, spell.y, e.x, e.y) < spell.radius + e.radius then
                         Enemies.damageEnemy(e, spell.damage, _, -- Finding index for damageEnemy is tricky here, passing nil or placeholder
                            function(exp) Player.data.exp = Player.data.exp + exp end,
                            function() Player.data.kills = Player.data.kills + 1 end,
                            function(lx, ly) Game.dropLoot(lx, ly, Player.data) end)

                        if spell.effectsToApply and spell.effectsToApply.knockback and spell.spellId == "ArcaneWave" then
                            local knockbackEffect = spell.effectsToApply.knockback
                            local knockbackStrength = knockbackEffect.strength or 50 -- Default if not set
                            local dirX = e.x - spell.x
                            local dirY = e.y - spell.y
                            local dist = (dirX^2 + dirY^2)^0.5
                            if dist > 0 then
                                local normX = dirX / dist
                                local normY = dirY / dist
                                e.x = e.x + normX * knockbackStrength
                                e.y = e.y + normY * knockbackStrength
                                e.x = math.max(e.radius, math.min(config_arg.windowWidth - e.radius, e.x))
                                e.y = math.max(e.radius, math.min(config_arg.windowHeight - e.radius, e.y))
                            end
                        end
                    end
                end
                local currentBoss = Enemies.getBoss()
                if currentBoss and utils.distance(spell.x, spell.y, currentBoss.x, currentBoss.y) < spell.radius + currentBoss.radius then
                    Enemies.damageBoss(currentBoss, spell.damage,
                        function(exp) Player.data.exp = Player.data.exp + exp end,
                        function() Player.data.kills = Player.data.kills + 1 end,
                        function(lx, ly) Game.dropLoot(lx, ly, Player.data) end)

                    if spell.effectsToApply and spell.effectsToApply.knockback and spell.spellId == "ArcaneWave" then
                        local knockbackEffect = spell.effectsToApply.knockback
                        local knockbackStrength = knockbackEffect.strength or 50
                        local dirX = currentBoss.x - spell.x
                        local dirY = currentBoss.y - spell.y
                        local dist = (dirX^2 + dirY^2)^0.5
                        if dist > 0 then
                            local normX = dirX / dist
                            local normY = dirY / dist
                            currentBoss.x = currentBoss.x + normX * knockbackStrength
                            currentBoss.y = currentBoss.y + normY * knockbackStrength
                            currentBoss.x = math.max(currentBoss.radius, math.min(config_arg.windowWidth - currentBoss.radius, currentBoss.x))
                            currentBoss.y = math.max(currentBoss.radius, math.min(config_arg.windowHeight - currentBoss.radius, currentBoss.y))
                        end
                    end
                end
                spell.alreadyHit = true
            end
            spell.duration = spell.duration - dt
            if spell.duration <= 0 then
                table.remove(Game.activeSpells, i)
            end

        elseif spell.type == "beam" then
            if spell.spellId == "VoidBeam" then
                -- Collision detection for VoidBeam (segmented circles)
                local numSegments = 10 -- Or calculate based on length/width: math.ceil(spell.range / (spell.width * 0.5))
                local dx_segment = (spell.x2 - spell.x1) / numSegments
                local dy_segment = (spell.y2 - spell.y1) / numSegments

                for s = 0, numSegments -1 do
                    local checkX = spell.x1 + dx_segment * s + dx_segment * 0.5 -- Midpoint of segment
                    local checkY = spell.y1 + dy_segment * s + dy_segment * 0.5

                    local enemiesToCheck = Enemies.getList()
                    for _, e in ipairs(enemiesToCheck) do
                        if not spell.hitEnemiesThisCast[e] and utils.distance(checkX, checkY, e.x, e.y) < (spell.width / 2 + e.radius) then
                            if spell.effectsToApply and spell.effectsToApply.dot then
                                spell.hitEnemiesThisCast[e] = true
                                local dotEffect = spell.effectsToApply.dot
                                Enemies.applyStatusEffect(e, "dot", dotEffect.duration, spell.damage) -- spell.damage is DPS
                            end
                        end
                    end

                    local boss = Enemies.getBoss()
                    if boss and not spell.hitEnemiesThisCast[boss] and utils.distance(checkX, checkY, boss.x, boss.y) < (spell.width / 2 + boss.radius) then
                        if spell.effectsToApply and spell.effectsToApply.dot then
                            spell.hitEnemiesThisCast[boss] = true
                            local dotEffect = spell.effectsToApply.dot
                            Enemies.applyStatusEffect(boss, "dot", dotEffect.duration, spell.damage) -- spell.damage is DPS
                        end
                    end
                end
            end
            -- Common beam duration handling
            spell.duration = spell.duration - dt
            if spell.duration <= 0 then
                table.remove(Game.activeSpells, i)
            end

        elseif spell.type == "visual_chain_bolt" then
            spell.duration = spell.duration - dt
            if spell.duration <= 0 then
                table.remove(Game.activeSpells, i)
            end
        end
        ::next_spell_update::
    end
end

function Game.draw()
    if not Config then
        print("Warning: Global Config not available in Game.draw(). Sprite scales may be incorrect.")
    end
    local projScale = (Config and Config.projectileScale) or 1
    local coinS = (Config and Config.coinScale) or 1
    local defaultS = (Config and Config.defaultSpriteScale) or 1

    -- Draw bullets
    if Assets and Assets.projectile_blue then
        local projectileImage = Assets.projectile_blue
        local pWidth = projectileImage:getWidth()
        local pHeight = projectileImage:getHeight()
        love.graphics.setColor(1, 1, 1)
        for _, b in ipairs(Game.bullets) do
            love.graphics.draw(projectileImage, b.x, b.y, 0, projScale, projScale, pWidth / 2, pHeight / 2)
        end
    else
        if Assets then
            print("Warning: Assets.projectile_blue is missing. Drawing circles for bullets.")
        end
        love.graphics.setColor(1, 1, 0)
        for _, b in ipairs(Game.bullets) do
            love.graphics.circle("fill", b.x, b.y, b.radius or 5)
        end
    end
    love.graphics.setColor(1, 1, 1)

    -- Draw loot
    for _, l in ipairs(Game.loot) do
        local lootImage = Assets.loot and Assets.loot[l.type]
        local currentLootScale = defaultS

        if l.type == "coin" then
            currentLootScale = coinS
        end
        -- Add other specific loot type scales here if needed e.g.
        -- elseif l.type == "essence_t1" then currentLootScale = Config.essenceScale or defaultS end


        if lootImage then
            love.graphics.setColor(1, 1, 1)
            local lWidth = lootImage:getWidth()
            local lHeight = lootImage:getHeight()
            love.graphics.draw(lootImage, l.x, l.y, 0, currentLootScale, currentLootScale, lWidth / 2, lHeight / 2)
        else
            if Assets and Assets.loot then
                 print("Info: No sprite for loot type: " .. (l.type or "unknown") .. ". Drawing fallback circle.")
            end
            if l.type == "coin" then
                love.graphics.setColor(1, 0.84, 0)
            elseif l.type == "essence_t1" then
                love.graphics.setColor(0, 1, 0)
            elseif l.type == "essence_t2" then
                love.graphics.setColor(0.2, 0.5, 1)
            else
                love.graphics.setColor(1, 0, 1)
            end
            love.graphics.circle("fill", l.x, l.y, l.radius or 5)
        end
    end
    love.graphics.setColor(1, 1, 1)

    -- Draw active spells
    for _, spell in ipairs(Game.activeSpells) do
        if spell.type == "projectile" then
            love.graphics.setColor(1, 0, 0, 0.8) -- Red for projectiles
            love.graphics.circle("fill", spell.x, spell.y, spell.radius or 5)
        elseif spell.type == "aoe_centered" then
            if spell.duration > 0.1 then -- Draw only in the first half of its short life for a flash effect
                 love.graphics.setColor(0, 0, 1, 0.5) -- Blue for AoE
                 love.graphics.circle("fill", spell.x, spell.y, spell.radius * ( (0.2 - spell.duration) / 0.2) ) -- Expanding effect
            end
        elseif spell.type == "visual_chain_bolt" then
            local r,g,b,a = unpack(spell.color or {0.5,0.5,1,0.8})
            love.graphics.setColor(r,g,b,a * (spell.duration / 0.15)) -- Fade out
            love.graphics.setLineWidth(3)
            love.graphics.line(spell.x1, spell.y1, spell.x2, spell.y2)
            love.graphics.setLineWidth(1)
        elseif spell.type == "beam" then
            love.graphics.setColor(0.5, 0, 0.5, 0.7) -- Purple for beams
            love.graphics.setLineWidth(spell.width or 10)
            love.graphics.line(spell.x1, spell.y1, spell.x2, spell.y2) -- Use pre-calculated x2, y2
            love.graphics.setLineWidth(1) -- Reset line width
        end
    end
    love.graphics.setColor(1, 1, 1) -- Reset color
end

function Game.resetForNewRealm(Player, Enemies)
    Enemies.reset()
    Game.bullets = {}
    if Player and Player.data then
        Player.data.kills = 0
    end
    Game.loot = {}
    Game.activeSpells = {} -- Clear active spells on realm change
end

function Game.changeRealm(delta, Player, Enemies)
    Game.currentRealm = math.max(1, Game.currentRealm + delta)
    Game.resetForNewRealm(Player, Enemies)
end

return Game

local Assets = {}

-- Path prefix for convenience
local gfxPath = "assets/graphics/" -- Assuming all graphics are in this subfolder

-- Player
-- Assuming a single spritesheet for the player. Animation/quads will be handled later.
Assets.player_spritesheet = love.graphics.newImage(gfxPath .. "wizard_spritesheet.png")

-- Projectiles
Assets.projectile_blue = love.graphics.newImage(gfxPath .. "projectile_blue.png")

-- Enemies (store them in a sub-table for organization)
Assets.enemies = {
    slime = love.graphics.newImage(gfxPath .. "slime.png"),
    skeleton = love.graphics.newImage(gfxPath .. "skeleton.png"),
    bird = love.graphics.newImage(gfxPath .. "bird.png"),
    zombie = love.graphics.newImage(gfxPath .. "zombie.png"),
    treant = love.graphics.newImage(gfxPath .. "treant.png")
}

-- Loot (store in a sub-table)
Assets.loot = {
    coin = love.graphics.newImage(gfxPath .. "coin.png"),
    essence_t1 = love.graphics.newImage(gfxPath .. "essence_green.png"), -- Mapping tier1 to green
    -- essence_t2 = love.graphics.newImage(gfxPath .. "essence_blue.png") -- Example if a blue essence existed
}

-- UI elements or other specific assets can be added here as needed
-- Example:
-- Assets.ui = {
--    inventory_panel = love.graphics.newImage(gfxPath .. "inventory_panel.png")
-- }

-- Upgrade Tree Node Orbs:
-- The prompt indicates these are primarily color-coded circles drawn directly.
-- If specific images were to be used for different node states (e.g., maxed, category),
-- they would be loaded here like:
-- Assets.node_orbs = {
--     offense = love.graphics.newImage(gfxPath .. "orb_red.png"),
--     defense = love.graphics.newImage(gfxPath .. "orb_blue.png"),
--     support = love.graphics.newImage(gfxPath .. "orb_green.png"),
--     maxed_overlay = love.graphics.newImage(gfxPath .. "orb_max_overlay.png")
-- }
-- For now, this section is illustrative, as direct drawing with colors is used.

return Assets

local Assets = {}

local gfxPath = "assets/graphics/"

local function loadImage(path)
    local fullPath = gfxPath .. path
    local status_ok, image_or_error = pcall(love.graphics.newImage, fullPath)
    if status_ok then
        return image_or_error
    else
        print("Warning: Failed to load image at '" .. fullPath .. "'. Error: " .. tostring(image_or_error))
        return nil
    end
end

-- Player
Assets.player_spritesheet = loadImage("wizard_spritesheet.png")

-- Projectiles
Assets.projectile_blue = loadImage("projectile_blue.png")

-- Enemies
Assets.enemies = {
    slime = loadImage("slime.png"),
    skeleton = loadImage("skeleton.png"),
    bird = loadImage("bird.png"),
    zombie = loadImage("zombie.png"),
    treant = loadImage("treant.png")
}

-- Loot
Assets.loot = {
    coin = loadImage("coin.png"),
    essence_t1 = loadImage("essence_green.png")
    -- essence_t2 will be handled by fallback color in Game.draw() as it has no sprite
}

-- Example for UI or other assets if they were images:
-- Assets.ui = {
--    inventory_panel = loadImage("inventory_panel.png")
-- }

return Assets

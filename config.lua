local config = {
    windowTitle = "Infinity Realms - FINAL VERSION", -- Keeping existing title
    windowWidth = 1920,
    windowHeight = 1080,

    -- Font and UI scaling
    baseFontSize = 14,    -- Base font size before UI scaling
    uiScaleFactor = 3,    -- Factor to scale UI elements (text, nodes, HUD text)

    -- Individual sprite category scaling
    playerScale = 0.5,       -- Overall scale for the player sprite (wizard_spritesheet.png is 256x256, so 0.5 makes it 128x128)
    enemyScale = 0.5 / 3,    -- Approx 0.166. (e.g. if slime is 32x32, this makes it ~5.3x5.3, which is very small. User might mean enemies should be 1/3 of player's *rendered* size, not 1/3 of the global 0.5 scale. This needs careful testing. For now, implementing as per formula)
    projectileScale = 0.5 / 8, -- Approx 0.0625 (e.g. if projectile_blue is 32x32, this makes it 2x2 pixels. This seems extremely small)
    coinScale = 0.5 / 8,       -- Approx 0.0625 (e.g. if coin is 16x16, this makes it 1x1 pixel. Also very small)

    defaultSpriteScale = 0.5, -- For other sprites like essences, or as a general fallback if a specific scale isn't defined.
                            -- Note: The original `spriteScale = 0.5` might have been intended as this default.

    fontPath = nil -- Retaining this from previous version
}
-- The old 'fontSize = 14' is replaced by 'baseFontSize' and 'uiScaleFactor'.
-- The old 'spriteScale = 0.5' is replaced by more granular playerScale, enemyScale, etc.

-- It's important to consider the original pixel dimensions of the sprites
-- when setting these scales to achieve the desired on-screen size.
-- For example, if player sprite is 64x64 and playerScale is 0.5, it becomes 32x32.
-- If an enemy sprite is 32x32 and enemyScale is 0.166, it becomes ~5x5 pixels.
-- The user's intent for "3x smaller" might mean 3x smaller than the player's *rendered size*,
-- not 1/3 of a general spriteScale of 0.5.
-- For example, if player is 128px wide (256 * 0.5), then 3x smaller might mean ~42px for enemies.
-- If enemy sprite is 32x32, scale would be 42/32 = ~1.3.
-- However, I will implement the direct interpretation of "0.5 / 3" for now.

return config

return {
  Fireball = {
    name = "Fireball",
    icon = "assets/graphics/spell_fireball.png",
    baseDamage = 20,
    cooldown = 2.0,
    range = 500,
    aoeRadius = 64,
    pierce = 0,
    effects = {"burn"}, -- 3s burn damage over time
    type = "projectile"
  },
  IceLance = {
    name = "Ice Lance",
    icon = "assets/graphics/spell_icelance.png",
    baseDamage = 14,
    cooldown = 1.4,
    range = 600,
    aoeRadius = 0,
    pierce = 2,
    effects = {"slow"}, -- -40% movement for 2s
    type = "projectile"
  },
  ChainBolt = {
    name = "Chain Bolt",
    icon = "assets/graphics/spell_chainbolt.png",
    baseDamage = 10,
    cooldown = 2.5,
    range = 300,
    aoeRadius = 0,
    pierce = 0,
    effects = {"chain=4"}, -- jumps to 4 enemies
    type = "projectile"
  },
  ArcaneWave = {
    name = "Arcane Wave",
    icon = "assets/graphics/spell_wave.png",
    baseDamage = 12,
    cooldown = 3.0,
    range = 0,
    aoeRadius = 160,
    pierce = 0,
    effects = {"knockback"}, -- pushes enemies outward
    type = "aoe_centered"
  },
  VoidBeam = {
    name = "Void Beam",
    icon = "assets/graphics/spell_voidbeam.png",
    baseDamage = 8,
    cooldown = 0.1, -- This implies it's a channeled spell / rapid fire
    range = 600,
    aoeRadius = 48, -- This could be beam width
    pierce = 999,
    effects = {"dot=5"}, -- deals damage while held (implies damage per tick or per second for X seconds)
    type = "beam"
  }
}

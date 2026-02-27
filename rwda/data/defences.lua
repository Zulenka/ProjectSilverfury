rwda = rwda or {}
rwda.data = rwda.data or {}

rwda.data.defences = {
  shield = {
    aliases = { "shield", "magical shield" },
    default_confidence = 1.0,
    decay_seconds = 6,
    drop_on_aggressive_act = true,
    drop_on_move = true,
  },
  rebounding = {
    aliases = { "rebounding", "aura of weapons rebounding" },
    default_confidence = 1.0,
    decay_seconds = 8,
    drop_on_aggressive_act = true,
    drop_on_move = false,
  },
  dragonarmour = {
    aliases = { "dragonarmour" },
    default_confidence = 1.0,
    decay_seconds = 0,
    drop_on_aggressive_act = false,
    drop_on_move = false,
  },
}

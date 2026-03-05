-- Silverfury/state/room.lua
-- Room state: current room id, player list.

Silverfury = Silverfury or {}
Silverfury.state = Silverfury.state or {}

Silverfury.state.room = {
  num     = nil,
  name    = nil,
  area    = nil,
  players = {},   -- key = lowercased name, value = true
}

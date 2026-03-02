rwda = rwda or {}
rwda.data = rwda.data or {}

rwda.data.venoms = {
  -- Primary lock stack
  curare     = { applies = "paralysis",    class = "lock" },
  kalmia     = { applies = "asthma",       class = "breathlock" },
  vernalius  = { applies = "weariness",    class = "pressure" },
  xentio     = { applies = "clumsiness",   class = "pressure" },
  euphorbia  = { applies = "nausea",       class = "pressure" },
  gecko      = { applies = "slickness",    class = "salve_block" },
  slike      = { applies = "anorexia",     class = "pressure" },
  aconite    = { applies = "stupidity",    class = "pressure" },

  -- Fallback / filler
  eurypteria = { applies = "recklessness", class = "pressure" },
  larkspur   = { applies = "dizziness",    class = "pressure" },
  prefarar   = { applies = "sensitivity",  class = "pressure" },
  darkshade  = { applies = "darkshade",    class = "pressure" },
  vardrax    = { applies = "addiction",    class = "pressure" },
  digitalis  = { applies = "shyness",      class = "pressure" },
  monkshood  = { applies = "disloyalty",   class = "pressure" },

  -- Special
  voyria     = { applies = "voyria",       class = "kill" },
  loki       = { applies = "loki",         class = "special" },
}

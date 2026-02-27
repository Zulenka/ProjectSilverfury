rwda = rwda or {}
rwda.data = rwda.data or {}

rwda.data.afflictions = {
  anorexia = {
    cures = {
      { channel = "salve", item = "epidermal" },
    },
    blocks = { "eat", "sip" },
    priority = 95,
    tags = { "critical", "consumption_block" },
  },
  slickness = {
    cures = {
      { channel = "herb", item = "bloodroot" },
      { channel = "smoke", item = "valerian" },
    },
    blocks = { "apply" },
    priority = 90,
    tags = { "critical", "salve_block" },
  },
  paralysis = {
    cures = {
      { channel = "herb", item = "bloodroot" },
    },
    blocks = { "movement", "offense" },
    priority = 92,
    tags = { "mobility_lock" },
  },
  impatience = {
    cures = {
      { channel = "herb", item = "goldenseal" },
    },
    blocks = { "focus" },
    priority = 75,
    tags = { "mental" },
  },
  confusion = {
    cures = {
      { channel = "herb", item = "pricklyash" },
    },
    blocks = { "focus" },
    priority = 70,
    tags = { "mental" },
  },
  epilepsy = {
    cures = {
      { channel = "herb", item = "goldenseal" },
    },
    blocks = { "balance_stability" },
    priority = 78,
    tags = { "balance_risk" },
  },
  recklessness = {
    cures = {
      { channel = "herb", item = "lobelia" },
    },
    blocks = {},
    priority = 68,
    tags = { "vitals_mask" },
  },
  weariness = {
    cures = {
      { channel = "special", item = "fitness" },
    },
    blocks = { "fitness" },
    priority = 82,
    tags = { "resource_pressure" },
  },
  webbed = {
    cures = {
      { channel = "writhe", item = "writhe" },
    },
    blocks = { "movement" },
    priority = 88,
    tags = { "mobility_lock" },
  },
  transfixed = {
    cures = {
      { channel = "writhe", item = "writhe" },
    },
    blocks = { "movement", "offense" },
    priority = 88,
    tags = { "mobility_lock" },
  },
}

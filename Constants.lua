-- BlingtronApp - Global addon namespace and constants

BlingtronApp = BlingtronApp or {}
BlingtronApp.logoIconSmall = "|TInterface\\AddOns\\BlingtronApp\\Media\\logo:12:12:0:0:0:0:0:0:0:0|t"
BlingtronApp.logoIcon      = "|TInterface\\AddOns\\BlingtronApp\\Media\\logo:16:16:0:0:0:0:0:0:0:0|t"

BlingtronApp.RC        = BlingtronApp.RC or {}
BlingtronApp.RCColumns = BlingtronApp.RCColumns or {}

--- Available BiS list sources. Populated by Data/BisList/*.lua files.
--- Each entry: key -> { label = "...", id = "...", order = n }
BlingtronApp.BisListSources = BlingtronApp.BisListSources or {}

--- BiS data container. Populated by Data/BisList/*.lua files.
--- [sourceId] -> { [specID] -> { [itemID] = { pct = n, slot = "...", source = { type = "raid"|"mythic_plus", id = n }? } } }
BlingtronApp.BisList = BlingtronApp.BisList or {}

--- Current-season raid/dungeon loot pools. Populated by Data/LootPools.lua.
--- Each item may have lootSpecs = { [specID] = true } for bonus-roll eligibility.
BlingtronApp.LootPools = BlingtronApp.LootPools or { raids = {}, dungeons = {} }

--- First matching row wins (highest min first). Slot-max items are always "BiS".
BlingtronApp.BIS_TIER_THRESHOLDS = {
    { min = 70, tier = "S" },
    { min = 50, tier = "A" },
    { min = 30, tier = "B" },
    { min = 15, tier = "C" },
    { min = 0,  tier = "D" },
}

--- Performance ratings: "Name-Realm" -> "A"|"B"|"C"|"D"|"F"
BlingtronApp.Performance = BlingtronApp.Performance or {}

--- Spec IDs (SpecializationID). See https://wowpedia.fandom.com/wiki/SpecializationID
BlingtronApp.DEATH_KNIGHT_BLOOD     = 250
BlingtronApp.DEATH_KNIGHT_FROST     = 251
BlingtronApp.DEATH_KNIGHT_UNHOLY    = 252
BlingtronApp.DEMON_HUNTER_HAVOC     = 577
BlingtronApp.DEMON_HUNTER_VENGEANCE = 581
BlingtronApp.DEMON_HUNTER_DEVOURER  = 1480
BlingtronApp.DRUID_BALANCE          = 102
BlingtronApp.DRUID_FERAL            = 103
BlingtronApp.DRUID_GUARDIAN         = 104
BlingtronApp.DRUID_RESTORATION      = 105
BlingtronApp.EVOKER_DEVASTATION     = 1467
BlingtronApp.EVOKER_PRESERVATION    = 1468
BlingtronApp.EVOKER_AUGMENTATION    = 1473
BlingtronApp.HUNTER_BEAST_MASTERY   = 253
BlingtronApp.HUNTER_MARKSMANSHIP    = 254
BlingtronApp.HUNTER_SURVIVAL        = 255
BlingtronApp.MAGE_ARCANE            = 62
BlingtronApp.MAGE_FIRE              = 63
BlingtronApp.MAGE_FROST             = 64
BlingtronApp.MONK_BREWMASTER        = 268
BlingtronApp.MONK_MISTWEAVER        = 270
BlingtronApp.MONK_WINDWALKER        = 269
BlingtronApp.PALADIN_HOLY           = 65
BlingtronApp.PALADIN_PROTECTION     = 66
BlingtronApp.PALADIN_RETRIBUTION    = 70
BlingtronApp.PRIEST_DISCIPLINE      = 256
BlingtronApp.PRIEST_HOLY            = 257
BlingtronApp.PRIEST_SHADOW          = 258
BlingtronApp.ROGUE_ASSASSINATION    = 259
BlingtronApp.ROGUE_OUTLAW           = 260
BlingtronApp.ROGUE_SUBTLETY         = 261
BlingtronApp.SHAMAN_ELEMENTAL       = 262
BlingtronApp.SHAMAN_ENHANCEMENT     = 263
BlingtronApp.SHAMAN_RESTORATION     = 264
BlingtronApp.WARLOCK_AFFLICTION     = 265
BlingtronApp.WARLOCK_DEMONOLOGY     = 266
BlingtronApp.WARLOCK_DESTRUCTION    = 267
BlingtronApp.WARRIOR_ARMS           = 71
BlingtronApp.WARRIOR_FURY           = 72
BlingtronApp.WARRIOR_PROTECTION     = 73

--- Ordered SpecializationIDs for UI (spec editor dropdown, etc.). Matches bundled BiS data coverage.
BlingtronApp.ALL_CLASS_SPEC_IDS = {
    BlingtronApp.DEATH_KNIGHT_BLOOD,
    BlingtronApp.DEATH_KNIGHT_FROST,
    BlingtronApp.DEATH_KNIGHT_UNHOLY,
    BlingtronApp.DEMON_HUNTER_HAVOC,
    BlingtronApp.DEMON_HUNTER_VENGEANCE,
    BlingtronApp.DEMON_HUNTER_DEVOURER,
    BlingtronApp.DRUID_BALANCE,
    BlingtronApp.DRUID_FERAL,
    BlingtronApp.DRUID_GUARDIAN,
    BlingtronApp.DRUID_RESTORATION,
    BlingtronApp.EVOKER_DEVASTATION,
    BlingtronApp.EVOKER_PRESERVATION,
    BlingtronApp.EVOKER_AUGMENTATION,
    BlingtronApp.HUNTER_BEAST_MASTERY,
    BlingtronApp.HUNTER_MARKSMANSHIP,
    BlingtronApp.HUNTER_SURVIVAL,
    BlingtronApp.MAGE_ARCANE,
    BlingtronApp.MAGE_FIRE,
    BlingtronApp.MAGE_FROST,
    BlingtronApp.MONK_BREWMASTER,
    BlingtronApp.MONK_MISTWEAVER,
    BlingtronApp.MONK_WINDWALKER,
    BlingtronApp.PALADIN_HOLY,
    BlingtronApp.PALADIN_PROTECTION,
    BlingtronApp.PALADIN_RETRIBUTION,
    BlingtronApp.PRIEST_DISCIPLINE,
    BlingtronApp.PRIEST_HOLY,
    BlingtronApp.PRIEST_SHADOW,
    BlingtronApp.ROGUE_ASSASSINATION,
    BlingtronApp.ROGUE_OUTLAW,
    BlingtronApp.ROGUE_SUBTLETY,
    BlingtronApp.SHAMAN_ELEMENTAL,
    BlingtronApp.SHAMAN_ENHANCEMENT,
    BlingtronApp.SHAMAN_RESTORATION,
    BlingtronApp.WARLOCK_AFFLICTION,
    BlingtronApp.WARLOCK_DEMONOLOGY,
    BlingtronApp.WARLOCK_DESTRUCTION,
    BlingtronApp.WARRIOR_ARMS,
    BlingtronApp.WARRIOR_FURY,
    BlingtronApp.WARRIOR_PROTECTION,
}

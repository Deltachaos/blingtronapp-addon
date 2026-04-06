-- BlingtronApp - Global addon namespace and constants

BlingtronApp = BlingtronApp or {}
BlingtronApp.logoIconSmall = "|TInterface\\AddOns\\BlingtronApp\\Media\\logo:12:12:0:0:0:0:0:0:0:0|t"
BlingtronApp.logoIcon      = "|TInterface\\AddOns\\BlingtronApp\\Media\\logo:16:16:0:0:0:0:0:0:0:0|t"

BlingtronApp.RC        = BlingtronApp.RC or {}
BlingtronApp.RCColumns = BlingtronApp.RCColumns or {}

--- Available BiS list sources. Populated by Data/BisList/*.lua files.
--- Each entry: key -> { label = "...", id = "..." }
BlingtronApp.BisListSources = BlingtronApp.BisListSources or {}

--- BiS data container. Populated by Data/BisList/*.lua files.
--- [sourceId] -> { [itemID] -> { [specID] = "BiS" | "T1" | "T2" | "T3" } }
BlingtronApp.BisList = BlingtronApp.BisList or {}

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

BlingtronApp.SET_HEAD = "head"
BlingtronApp.SET_SHOULDERS = "shoulders"
BlingtronApp.SET_CHEST = "chest"
BlingtronApp.SET_LEGS = "legs"
BlingtronApp.SET_HANDS = "hands"

BlingtronApp.SET_ROUGE_MONK_DRUID_DEAMON_HUNTER = {
    [BlingtronApp.SET_HEAD] = 249356,
    [BlingtronApp.SET_SHOULDERS] = 249364,
    [BlingtronApp.SET_CHEST] = 249348,
    [BlingtronApp.SET_LEGS] = 249360,
    [BlingtronApp.SET_HANDS] = 249352,
}

BlingtronApp.SET_ROGUE = BlingtronApp.SET_ROUGE_MONK_DRUID_DEAMON_HUNTER
BlingtronApp.SET_MONK = BlingtronApp.SET_ROUGE_MONK_DRUID_DEAMON_HUNTER
BlingtronApp.SET_DRUID = BlingtronApp.SET_ROUGE_MONK_DRUID_DEAMON_HUNTER
BlingtronApp.SET_DEAMON_HUNTER = BlingtronApp.SET_ROUGE_MONK_DRUID_DEAMON_HUNTER

BlingtronApp.SET_WARRIOR_PALADIN_DEATH_KNIGHT = {
    [BlingtronApp.SET_HEAD] = 249358,
    [BlingtronApp.SET_SHOULDERS] = 249366,
    [BlingtronApp.SET_CHEST] = 249350,
    [BlingtronApp.SET_LEGS] = 249362,
    [BlingtronApp.SET_HANDS] = 249354,
}

BlingtronApp.SET_PALADIN = BlingtronApp.SET_WARRIOR_PALADIN_DEATH_KNIGHT
BlingtronApp.SET_DEATH_KNIGHT = BlingtronApp.SET_WARRIOR_PALADIN_DEATH_KNIGHT
BlingtronApp.SET_WARRIOR = BlingtronApp.SET_WARRIOR_PALADIN_DEATH_KNIGHT

BlingtronApp.SET_PRIEST_MAGE_WARLOCK = {
    [BlingtronApp.SET_HEAD] = 249355,
    [BlingtronApp.SET_SHOULDERS] = 249363,
    [BlingtronApp.SET_CHEST] = 249347,
    [BlingtronApp.SET_LEGS] = 249359,
    [BlingtronApp.SET_HANDS] = 249351,
}

BlingtronApp.SET_MAGE = BlingtronApp.SET_PRIEST_MAGE_WARLOCK
BlingtronApp.SET_WARLOCK = BlingtronApp.SET_PRIEST_MAGE_WARLOCK
BlingtronApp.SET_PRIEST = BlingtronApp.SET_PRIEST_MAGE_WARLOCK

BlingtronApp.SET_HUNTER_SHAMAN_EVOKER = {
    [BlingtronApp.SET_HEAD] = 249357,
    [BlingtronApp.SET_SHOULDERS] = 249365,
    [BlingtronApp.SET_CHEST] = 249349,
    [BlingtronApp.SET_LEGS] = 249361,
    [BlingtronApp.SET_HANDS] = 249353,
}

BlingtronApp.SET_SHAMAN = BlingtronApp.SET_HUNTER_SHAMAN_EVOKER
BlingtronApp.SET_EVOKER = BlingtronApp.SET_HUNTER_SHAMAN_EVOKER
BlingtronApp.SET_HUNTER = BlingtronApp.SET_HUNTER_SHAMAN_EVOKER
BCORE.Unbox.config = BCORE.Unbox.config or {}
BCORE.Unbox.config.sh = BCORE.Unbox.config.sh or {}

local cfg = BCORE.Unbox.config.sh

cfg.Colors = {
    bg = Color(28,28,28),
    accent = Color(40,39,44),
    light = Color(55,54,60),
    sec = Color(35,34,38),
    cwhite = Color(202,202,202),
    tert = Color(194,55,9),
    stert = Color(255,78,217),
    moneygreen = Color(255,206,31),
    online = Color(0,82,224),
    current = Color(254,89,12),
    playtime = Color(0,247,255), -- was Color(0,247,589) - 589 is out of the 0-255 range
}

-- Set unconditionally (same reasoning as beeps-printers' Colors default) so the admin item
-- editor's CATEGORY/TYPE dropdown always has real choices, whether or not BCORE.Config is
-- actually present below to override it with an admin-edited list.
BCORE.Unbox.ItemTypes = BCORE.Unbox.ItemTypes or { "Weapon", "Consumable" }

-- Register with BCORE.Config (beep-framework), if present, so all of the above (plus the
-- rarity weights / rarity price multipliers / bulk-discount tiers that used to be hardcoded
-- directly in sv_economy.lua, never even in a config file at all) becomes in-game
-- editable/persisted. This must be a SHARED registration (not server-only) even though the
-- rarity/pricing values are only ever used server-side, because the config UI's schema is
-- never itself synced over the network - only Values are (see BCORE.Config's own sync file) -
-- a client that never registered these definitions locally would render no row for them.
if BCORE and BCORE.RegisterConfig then
    local colorFields, defaultColors = {}, {}
    for key, col in pairs(cfg.Colors) do
        colorFields[#colorFields + 1] = { key = key, label = key }
        defaultColors[key] = Color(col.r, col.g, col.b, col.a)
    end
    table.sort(colorFields, function(a, b) return a.key < b.key end)

    BCORE:RegisterConfig("beep_unboxing", "colors", {
        label = "Unboxing UI Colors",
        category = "Appearance",
        type = "colors",
        fields = colorFields,
        default = defaultColors,
    })

    BCORE:RegisterConfig("beep_unboxing", "RarityWeights", {
        label = "Rarity Roll Weights",
        category = "Economy",
        description = "Relative weight used when rolling a case's legacy per-rarity item pool. Higher = more common.",
        type = "records",
        fields = {
            { key = "rarity", label = "Rarity", type = "string", default = "" },
            { key = "weight", label = "Weight", type = "number", min = 0, decimals = 0, default = 0 },
        },
        default = {
            { rarity = "common", weight = 60 },
            { rarity = "uncommon", weight = 25 },
            { rarity = "rare", weight = 10 },
            { rarity = "epic", weight = 4 },
            { rarity = "legendary", weight = 1 },
        },
    })

    BCORE:RegisterConfig("beep_unboxing", "RarityPriceMultipliers", {
        label = "Rarity Price Multipliers",
        category = "Economy",
        description = "Multiplies an item's base price based on its rarity.",
        type = "records",
        fields = {
            { key = "rarity", label = "Rarity", type = "string", default = "" },
            { key = "multiplier", label = "Multiplier", type = "number", min = 0, decimals = 2, default = 1 },
        },
        default = {
            { rarity = "common", multiplier = 1 },
            { rarity = "uncommon", multiplier = 1.25 },
            { rarity = "rare", multiplier = 1.75 },
            { rarity = "epic", multiplier = 2.5 },
            { rarity = "legendary", multiplier = 4 },
        },
    })

    BCORE:RegisterConfig("beep_unboxing", "BulkDiscounts", {
        label = "Bulk Purchase Discounts",
        category = "Economy",
        description = "Buying at least this many at once applies the given price multiplier. Order doesn't matter - the highest matching Min Amount always wins.",
        type = "records",
        fields = {
            { key = "minAmount", label = "Min Amount", type = "number", min = 1, decimals = 0, default = 1 },
            { key = "multiplier", label = "Multiplier", type = "number", min = 0, max = 1, decimals = 2, default = 1 },
        },
        default = {
            { minAmount = 10, multiplier = 0.95 },
            { minAmount = 20, multiplier = 0.9 },
            { minAmount = 50, multiplier = 0.85 },
        },
    })

    BCORE:RegisterConfig("beep_unboxing", "ItemTypes", {
        label = "Item Types",
        category = "Economy",
        description = "The CATEGORY/TYPE choices offered when creating or editing an item in the Unbox admin panel. Add a new entry here to make it selectable there - no code edit needed.",
        type = "list",
        default = { "Weapon", "Consumable" },
    })

    BCORE:RegisterConfig("beep_unboxing", "AnnounceRarity", {
        label = "Announce Unboxes At Rarity",
        category = "Economy",
        description = "Broadcasts a server-wide chat message, colored to match the item's rarity, whenever anyone unboxes an item of this rarity or rarer. Off disables announcements entirely.",
        type = "choice",
        choices = { "Off", "common", "uncommon", "rare", "epic", "legendary" },
        default = "legendary",
    })

    BCORE:RegisterConfig("beep_unboxing", "TradeInEnabled", {
        label = "Enable Trade-In", category = "Trade-In",
        description = "Turns the whole Trade-In tab (scrap for cash, trade up) on or off. Off blocks both actions server-side and hides the tab.",
        type = "bool", default = true,
    })
    BCORE:RegisterConfig("beep_unboxing", "ScrapPercent", {
        label = "Scrap Payout %", category = "Trade-In",
        description = "What percentage of an item's Base Price it pays out when scrapped for cash.",
        type = "number", min = 0, max = 100, decimals = 0, default = 40,
    })
    BCORE:RegisterConfig("beep_unboxing", "TradeUpItemsRequired", {
        label = "Trade-Up Items Required", category = "Trade-In",
        description = "How many items of the SAME rarity a trade-up consumes to produce one item of the next rarity up.",
        type = "number", min = 2, decimals = 0, default = 5,
    })

    BCORE:RegisterConfig("beep_unboxing", "GamblingEnabled", {
        label = "Enable Gambling", category = "Gambling",
        description = "Turns the whole Gambling tab on or off. Off blocks every gambling action server-side and hides the tab.",
        type = "bool", default = true,
    })
    BCORE:RegisterConfig("beep_unboxing", "GamblingHouseEdgePercent", {
        label = "House Edge %", category = "Gambling",
        description = "Percentage taken off every gambling payout across all five games.",
        type = "number", min = 0, max = 100, decimals = 0, default = 5,
    })
    BCORE:RegisterConfig("beep_unboxing", "GamblingMinBet", {
        label = "Minimum Bet", category = "Gambling",
        type = "number", min = 0, decimals = 0, default = 100,
    })
    BCORE:RegisterConfig("beep_unboxing", "GamblingMaxBet", {
        label = "Maximum Bet", category = "Gambling",
        type = "number", min = 0, decimals = 0, default = 1000000,
    })
    BCORE:RegisterConfig("beep_unboxing", "EnableCoinflip", {
        label = "Enable Coinflip", category = "Gambling", type = "bool", default = true,
    })
    BCORE:RegisterConfig("beep_unboxing", "EnableDice", {
        label = "Enable Dice/Roulette", category = "Gambling", type = "bool", default = true,
    })
    BCORE:RegisterConfig("beep_unboxing", "EnableJackpot", {
        label = "Enable Jackpot", category = "Gambling", type = "bool", default = true,
    })
    BCORE:RegisterConfig("beep_unboxing", "EnableCaseBattles", {
        label = "Enable Case Battles", category = "Gambling", type = "bool", default = true,
    })
    BCORE:RegisterConfig("beep_unboxing", "EnableCrash", {
        label = "Enable Crash", category = "Gambling", type = "bool", default = true,
    })
    BCORE:RegisterConfig("beep_unboxing", "EnableMines", {
        label = "Enable Mines", category = "Gambling", type = "bool", default = true,
    })
    BCORE:RegisterConfig("beep_unboxing", "EnableSlots", {
        label = "Enable Slots", category = "Gambling", type = "bool", default = true,
    })
    BCORE:RegisterConfig("beep_unboxing", "JackpotRoundSeconds", {
        label = "Jackpot Round Length (seconds)", category = "Gambling",
        type = "number", min = 5, decimals = 0, default = 45,
    })
    BCORE:RegisterConfig("beep_unboxing", "CrashBettingSeconds", {
        label = "Crash Betting Window (seconds)", category = "Gambling",
        type = "number", min = 3, decimals = 0, default = 12,
    })

    local function RecordsToMap(records, keyField, valueField)
        local out = {}
        for _, rec in ipairs(records or {}) do
            out[rec[keyField]] = rec[valueField]
        end
        return out
    end

    local function SyncUnboxConfigMirror()
        local colors = BCORE:GetConfig("beep_unboxing", "colors")
        if colors then
            for key, col in pairs(colors) do
                cfg.Colors[key] = col
            end
        end

        BCORE.Unbox.RarityWeights = RecordsToMap(BCORE:GetConfig("beep_unboxing", "RarityWeights"), "rarity", "weight")
        BCORE.Unbox.RarityPricing = RecordsToMap(BCORE:GetConfig("beep_unboxing", "RarityPriceMultipliers"), "rarity", "multiplier")

        -- The canonical rarity PROGRESSION (common -> uncommon -> ... -> legendary), derived
        -- from RarityWeights' own registered record order rather than a second hardcoded list -
        -- Trade-Up (sv_tradein.lua) needs this to resolve "the next rarity up" from whatever a
        -- player turns in.
        local order = {}
        for _, rec in ipairs(BCORE:GetConfig("beep_unboxing", "RarityWeights") or {}) do
            if rec.rarity and rec.rarity ~= "" then order[#order + 1] = string.lower(rec.rarity) end
        end
        if #order > 0 then BCORE.Unbox.RarityOrder = order end

        local itemTypes = BCORE:GetConfig("beep_unboxing", "ItemTypes")
        if itemTypes and #itemTypes > 0 then
            BCORE.Unbox.ItemTypes = itemTypes
        end

        local bulk = BCORE:GetConfig("beep_unboxing", "BulkDiscounts") or {}
        table.sort(bulk, function(a, b) return (a.minAmount or 0) > (b.minAmount or 0) end)
        BCORE.Unbox.BulkDiscounts = bulk

        BCORE.Unbox.AnnounceRarity = BCORE:GetConfig("beep_unboxing", "AnnounceRarity")

        BCORE.Unbox.TradeInEnabled = BCORE:GetConfig("beep_unboxing", "TradeInEnabled")
        BCORE.Unbox.ScrapPercent = BCORE:GetConfig("beep_unboxing", "ScrapPercent")
        BCORE.Unbox.TradeUpItemsRequired = BCORE:GetConfig("beep_unboxing", "TradeUpItemsRequired")

        BCORE.Unbox.GamblingEnabled = BCORE:GetConfig("beep_unboxing", "GamblingEnabled")
        BCORE.Unbox.GamblingHouseEdgePercent = BCORE:GetConfig("beep_unboxing", "GamblingHouseEdgePercent")
        BCORE.Unbox.GamblingMinBet = BCORE:GetConfig("beep_unboxing", "GamblingMinBet")
        BCORE.Unbox.GamblingMaxBet = BCORE:GetConfig("beep_unboxing", "GamblingMaxBet")
        BCORE.Unbox.EnableCoinflip = BCORE:GetConfig("beep_unboxing", "EnableCoinflip")
        BCORE.Unbox.EnableDice = BCORE:GetConfig("beep_unboxing", "EnableDice")
        BCORE.Unbox.EnableJackpot = BCORE:GetConfig("beep_unboxing", "EnableJackpot")
        BCORE.Unbox.EnableCaseBattles = BCORE:GetConfig("beep_unboxing", "EnableCaseBattles")
        BCORE.Unbox.EnableCrash = BCORE:GetConfig("beep_unboxing", "EnableCrash")
        BCORE.Unbox.EnableMines = BCORE:GetConfig("beep_unboxing", "EnableMines")
        BCORE.Unbox.EnableSlots = BCORE:GetConfig("beep_unboxing", "EnableSlots")
        BCORE.Unbox.JackpotRoundSeconds = BCORE:GetConfig("beep_unboxing", "JackpotRoundSeconds")
        BCORE.Unbox.CrashBettingSeconds = BCORE:GetConfig("beep_unboxing", "CrashBettingSeconds")
    end

    SyncUnboxConfigMirror()
    hook.Add("BCORE.Config.Synced", "BCORE.Unbox.ConfigSynced", SyncUnboxConfigMirror)
    hook.Add("BCORE.Config.ValueChanged", "BCORE.Unbox.ConfigChanged", function(addonId)
        if addonId == "beep_unboxing" then SyncUnboxConfigMirror() end
    end)
end
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

        local bulk = BCORE:GetConfig("beep_unboxing", "BulkDiscounts") or {}
        table.sort(bulk, function(a, b) return (a.minAmount or 0) > (b.minAmount or 0) end)
        BCORE.Unbox.BulkDiscounts = bulk
    end

    SyncUnboxConfigMirror()
    hook.Add("BCORE.Config.Synced", "BCORE.Unbox.ConfigSynced", SyncUnboxConfigMirror)
    hook.Add("BCORE.Config.ValueChanged", "BCORE.Unbox.ConfigChanged", function(addonId)
        if addonId == "beep_unboxing" then SyncUnboxConfigMirror() end
    end)
end
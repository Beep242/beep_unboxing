local u = BCORE.Unbox

if not sql.TableExists("bcore_unbox") then
    sql.Query([[
        CREATE TABLE bcore_unbox (
            steamid TEXT PRIMARY KEY,
            inventory TEXT,
            cases TEXT
        )
    ]])
end

local function encode(t)
    return util.TableToJSON(t or {})
end

local function decode(s)
    return util.JSONToTable(s or "{}") or {}
end

function u:GetPlayer(ply)
    local id = ply:SteamID64()
    u.Players[id] = u.Players[id] or { inventory = {}, cases = {} }
    return u.Players[id]
end

function u:LoadPlayer(ply)
    local id = ply:SteamID64()
    local row = sql.QueryRow("SELECT * FROM bcore_unbox WHERE steamid = " .. sql.SQLStr(id))

    if row then
        u.Players[id] = {
            inventory = decode(row.inventory),
            cases = decode(row.cases)
        }
    else
        u.Players[id] = { inventory = {}, cases = {} }
        local ok = sql.Query("INSERT INTO bcore_unbox VALUES (" ..
            sql.SQLStr(id) .. "," ..
            sql.SQLStr("{}") .. "," ..
            sql.SQLStr("{}") .. ")"
        )
        if ok == false then
            ErrorNoHalt("[BCORE.Unbox] Failed to insert new player row for " .. id .. ": " .. tostring(sql.LastError()) .. "\n")
        end
    end
end

function u:SavePlayer(ply)
    local id = ply:SteamID64()
    local data = u.Players[id]
    if not data then return end

    local ok = sql.Query("UPDATE bcore_unbox SET " ..
        "inventory = " .. sql.SQLStr(encode(data.inventory)) .. "," ..
        "cases = " .. sql.SQLStr(encode(data.cases)) ..
        " WHERE steamid = " .. sql.SQLStr(id)
    )
    if ok == false then
        ErrorNoHalt("[BCORE.Unbox] Failed to save inventory for " .. id .. ": " .. tostring(sql.LastError()) .. "\n")
    end
end
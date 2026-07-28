-- Gambling hub - all seven games shown on ONE page at once, laid out in a real, deterministic
-- grid (fixed columns computed from the actual frame width, every cell placed by hand) rather
-- than a wrapping DIconLayout - the user's own complaint ("that looks like shit") after the
-- first pass used an auto-wrap layout whose column count/alignment wasn't fully predictable.
-- Each minigame's own builder lives in ui/pages/gambling/cl_<game>.lua and is only ever CALLED
-- here (never referenced at file-scope) - this file is a top-level ui/pages/ file, which loads
-- before the ui/pages/gambling/ subfolder per BCORE's own loader (top-level files in a folder
-- before its subfolders), but that's fine since BCORE.Unbox:Gambling() itself only runs later,
-- when a player actually opens the menu - by then every file has finished loading.
local colors = BCORE.Unbox.config.sh.Colors
local IC = BCORE.Unbox.Icons

local GAMES = {
    { id = "coinflip", label = "COINFLIP", builder = "BuildCoinflipPage" },
    { id = "dice", label = "DICE", builder = "BuildDicePage" },
    { id = "jackpot", label = "JACKPOT", builder = "BuildJackpotPage" },
    { id = "casebattles", label = "CASE BATTLES", builder = "BuildCaseBattlesPage" },
    { id = "crash", label = "CRASH", builder = "BuildCrashPage" },
    { id = "mines", label = "MINES", builder = "BuildMinesPage" },
    { id = "slots", label = "SLOTS", builder = "BuildSlotsPage" },
}

-- Every builder's own internal layout assumes roughly this much room to draw into.
local CELL_W, CELL_H = 440, 480
local TITLE_H = 32
local GAP = 14

function BCORE.Unbox:Gambling()
    local page = BCORE.Unbox:CreatePage("Gambling", IC.gambling)

    local scroll = BUi.Create("BUi.Scroll", page)
    scroll:Stick(FILL, 0, 8, 8, 8, 8)

    local gridHolder = BUi.Create("DPanel", scroll)
    gridHolder:Dock(TOP); gridHolder:SetPaintBackground(false)

    -- Real column count from the actual frame width (known synchronously - frame:SetSize
    -- already ran before this page is ever built), not a guess - guarantees the grid is always
    -- evenly spaced and fully aligned regardless of window/embed size, rather than however many
    -- columns a wrapping layout happens to fit.
    local cellW, cellH, gap = BUi:Scale(CELL_W), BUi:Scale(CELL_H), BUi:Scale(GAP)
    local frameWide = IsValid(BCORE.Unbox.frame) and BCORE.Unbox.frame:GetWide() or ScrW()
    local availableW = frameWide - BUi:Scale(16 + 8 + 8) - BUi:Scale(18) -- page/scroll margins + vbar allowance
    local cols = math.max(1, math.floor((availableW + gap) / (cellW + gap)))
    local rows = math.ceil(#GAMES / cols)
    gridHolder:SetTall(rows * (cellH + gap))

    for i, game in ipairs(GAMES) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)

        local cell = BUi.Create("DPanel", gridHolder)
        cell:SetSize(cellW, cellH)
        cell:SetPos(col * (cellW + gap), row * (cellH + gap))
        cell:ClearPaint():On("Paint", function(s, w, h)
            BCORE.Unbox:PaintCard(w, h, colors.tert, { headerStrip = BUi:Scale(TITLE_H) })
            draw.SimpleText(game.label, "BCORE.Unboxb.16", BUi:Scale(14), BUi:Scale(TITLE_H) / 2,
                color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end)

        local content = BUi.Create("DPanel", cell)
        content:SetPos(BUi:Scale(12), BUi:Scale(TITLE_H) + BUi:Scale(10))
        content:SetSize(cellW - BUi:Scale(24), cellH - BUi:Scale(TITLE_H) - BUi:Scale(22))
        content:SetPaintBackground(false)

        local builderFn = BCORE.Unbox[game.builder]
        if builderFn then
            builderFn(BCORE.Unbox, content)
        else
            content:On("Paint", function(_, w, h)
                draw.SimpleText(game.label .. " unavailable", "BCORE.Unbox.16", w / 2, h / 2,
                    ColorAlpha(colors.cwhite, 150), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end)
        end
    end
end

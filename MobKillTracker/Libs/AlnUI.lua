-- Libs/UI.lua
-- Reusable UI helpers. Can be embedded in any addon.
-- Namespace: AlnUI

AlnUI = AlnUI or {}

local THEMES = {
    gold = {
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
        header   = "Interface\\DialogFrame\\UI-DialogBox-Gold-Header",
    },
    standard = {
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        header   = "Interface\\DialogFrame\\UI-DialogBox-Header",
    },
}

--------------------------------------------------
-- AlnUI:CreateDialog(opts) -> frame
--
-- opts (all optional):
--   name         string  global frame name
--   title        string  title text shown in the header banner
--   titleWidth   number  width of the header banner (default 256)
--   width        number  (default 400)
--   height       number  (default 300)
--   parent       frame   (default UIParent)
--   strata       string  frame strata
--   level        number  frame level
--   theme        string  "gold" (default) or "standard"
--
-- Returns a hidden, movable frame with:
--   frame.titleText    FontString (nil if no title given)
--   frame.titleBanner  Texture    (nil if no title given)
--   frame.closeButton  Button
--------------------------------------------------

function AlnUI:CreateDialog(opts)
    opts = opts or {}

    local theme = THEMES[opts.theme] or THEMES.standard

    local frame = CreateFrame(
        "Frame",
        opts.name or nil,
        opts.parent or UIParent,
        "BackdropTemplate"
    )

    frame:SetSize(opts.width or 400, opts.height or 300)
    frame:SetPoint("CENTER")
    frame:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = theme.edgeFile,
        edgeSize = 32,
        insets   = { left = 8, right = 8, top = 8, bottom = 8 },
    })

    if opts.strata then frame:SetFrameStrata(opts.strata) end
    if opts.level  then frame:SetFrameLevel(opts.level) end

    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop",  frame.StopMovingOrSizing)
    frame:Hide()

    -- Title: header banner + text centered on it
    if opts.title then
        local banner = frame:CreateTexture(nil, "OVERLAY")
        banner:SetTexture(theme.header)
        banner:SetSize(opts.titleWidth or 256, 64)
        banner:SetPoint("TOP", frame, "TOP", 0, 12)
        frame.titleBanner = banner

        local t = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        t:SetPoint("TOP", frame, "TOP", 0, 0)
        t:SetText(opts.title)
        frame.titleText = t

        -- Invisible drag handle sized exactly to the banner so the overflow
        -- area above the frame edge is also draggable
        local dragHandle = CreateFrame("Frame", nil, frame)
        dragHandle:SetSize(opts.titleWidth or 256, 12)
        dragHandle:SetPoint("TOP", frame, "TOP", 0, 12)
        dragHandle:EnableMouse(true)
        dragHandle:RegisterForDrag("LeftButton")
        dragHandle:SetScript("OnDragStart", function() frame:StartMoving() end)
        dragHandle:SetScript("OnDragStop",  function() frame:StopMovingOrSizing() end)
    end

    -- Close button
    local cb = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    cb:SetPoint("TOPRIGHT", -10, -10)
    frame.closeButton = cb

    return frame
end

--------------------------------------------------
-- AlnUI:CreateColumnRow(parent, opts, cols) -> fontstrings[]
--
-- Creates a horizontal row of FontStrings on `parent`.
--
-- opts (all optional):
--   anchorTo  frame   frame to anchor the first column to (default parent)
--   x         number  x offset for the first column (default 0)
--   y         number  y offset for the first column (default 0)
--   font      string  font template for all columns (default "GameFontHighlight")
--
-- cols[i]:
--   width    number  column width
--   justify  string  "LEFT" or "RIGHT" (default "LEFT")
--   gap      number  gap before this column from the previous (default 0)
--   text     string  initial text (optional)
--   wordWrap bool    set to false to disable word wrap (default true)
--
-- Returns an array of FontStrings in column order.
--------------------------------------------------

function AlnUI:CreateColumnRow(parent, opts, cols)
    opts = opts or {}

    local font     = opts.font or "GameFontHighlight"
    local anchorTo = opts.anchorTo or parent
    local x        = opts.x or 0
    local y        = opts.y or 0
    local result   = {}
    local prev     = nil

    for i, col in ipairs(cols) do
        local fs = parent:CreateFontString(nil, "OVERLAY", font)
        fs:SetWidth(col.width)
        fs:SetJustifyH(col.justify or "LEFT")
        if col.wordWrap == false then fs:SetWordWrap(false) end
        if col.text then fs:SetText(col.text) end

        if i == 1 then
            fs:SetPoint("TOPLEFT", anchorTo, "TOPLEFT", x, y)
        else
            fs:SetPoint("LEFT", prev, "RIGHT", col.gap or 0, 0)
        end

        prev      = fs
        result[i] = fs
    end

    return result
end

--------------------------------------------------
-- AlnUI:CreateScrollFrame(parent, opts) -> scroll, content
--
-- Creates a UIPanelScrollFrameTemplate scroll frame with a content
-- child frame inside it.
--
-- opts (all optional):
--   x1, y1  number  TOPLEFT offset from parent (default 0, 0)
--   x2, y2  number  BOTTOMRIGHT offset from parent (default 0, 0)
--   contentWidth   number  initial content width  (default 0)
--   contentHeight  number  initial content height (default 0)
--
-- Returns: scroll, content
--------------------------------------------------

function AlnUI:CreateScrollFrame(parent, opts)
    opts = opts or {}

    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",     opts.x1 or 0,  opts.y1 or 0)
    scroll:SetPoint("BOTTOMRIGHT", opts.x2 or 0,  opts.y2 or 0)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(opts.contentWidth or 0, opts.contentHeight or 0)
    scroll:SetScrollChild(content)

    return scroll, content
end

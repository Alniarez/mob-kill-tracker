-- Libs/AlnUI.lua

--==================================================
-- 1. Setup
--==================================================

local VERSION = 3

if AlnUI and (AlnUI.version or 1) >= VERSION then return end

AlnUI = AlnUI or {}
AlnUI.version    = VERSION
AlnUI.loadedFrom = (...)

local function HasTemplate(name)
    return C_XMLUtil ~= nil
        and C_XMLUtil.GetTemplateInfo ~= nil
        and C_XMLUtil.GetTemplateInfo(name) ~= nil
end

--==================================================
-- 2. Themes
--==================================================

local THEMES = {
    gold = {
        closeOffset = 10,
        gripOffset  = 6,
        header   = "Interface\\DialogFrame\\UI-DialogBox-Gold-Header",
        backdrop = {
            bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
            tile     = true,
            tileEdge = true,
            tileSize = 32,
            edgeSize = 32,
            insets   = { left = 11, right = 12, top = 12, bottom = 11 },
        },
    },
    standard = {
        closeOffset = 10,
        gripOffset  = 6,
        header   = "Interface\\DialogFrame\\UI-DialogBox-Header",
        backdrop = {
            bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile     = true,
            tileEdge = true,
            tileSize = 32,
            edgeSize = 32,
            insets   = { left = 11, right = 12, top = 12, bottom = 11 },
        },
    },
    modern = {
        closeOffset    = 2,
        gripOffset     = 4,
        border         = "DialogBorderTemplate",
        headerTemplate = "DialogHeaderTemplate",
    },
    basic = {
        closeOffset   = 0,
        closePoint    = { 1, 0 },
        gripOffset    = 4,
        border        = "BasicFrameTemplate",
        templateTitle = true,
        toastTheme    = "tooltip",
    },
    panel = {
        closeOffset   = 0,
        closePoint    = { 1, 0 },
        gripOffset    = 4,
        border        = "DefaultPanelTemplate",
        templateTitle = true,
        toastTheme    = "tooltip",
    },
    tooltip = {
        closeOffset = -2,
        gripOffset  = 3,
        border      = "TooltipBackdropTemplate",
    },
}

local function IsThemeAvailable(theme)
    if not theme then return false end
    if theme.border and not HasTemplate(theme.border) then return false end
    if theme.headerTemplate and not HasTemplate(theme.headerTemplate) then return false end
    return true
end

local function ResolveTheme(name, fallback, forToast)
    local theme = THEMES[name]
    if forToast and theme and theme.toastTheme then
        return ResolveTheme(theme.toastTheme, fallback)
    end
    if IsThemeAvailable(theme) then return name end
    return fallback
end

local function TemplateTitleText(border)
    return border.TitleText or (border.TitleContainer and border.TitleContainer.TitleText)
end

local function ApplyThemeBorder(frame, theme)
    if frame.border then frame.border:Hide() end
    frame.border = nil

    if theme.backdrop then
        frame:SetBackdrop(theme.backdrop)
        return
    end

    if frame.ClearBackdrop then frame:ClearBackdrop() else frame:SetBackdrop(nil) end
    frame.alnBorders = frame.alnBorders or {}
    local border = frame.alnBorders[theme.border]
    if not border then
        border = CreateFrame("Frame", nil, frame, theme.border)
        border:SetAllPoints()
        if border.SetUsingParentLevel then
            border:SetUsingParentLevel(true)
        else
            border:SetFrameLevel(frame:GetFrameLevel())
        end
        if border.CloseButton then border.CloseButton:Hide() end
        local ownTitle = TemplateTitleText(border)
        if ownTitle then ownTitle:Hide() end
        for i = 1, select("#", border:GetChildren()) do
            local child = select(i, border:GetChildren())
            if child ~= border.CloseButton then
                if child.SetUsingParentLevel then
                    child:SetUsingParentLevel(true)
                else
                    child:SetFrameLevel(frame:GetFrameLevel())
                end
            end
        end
        frame.alnBorders[theme.border] = border
    end
    border:Show()
    frame.border = border
end

---True when this client can draw the theme `name`.
---@param name string
---@return boolean
function AlnUI:HasTheme(name)
    return IsThemeAvailable(THEMES[name])
end

---The theme names this client can draw.
---@param kind string?
---@return string[]
function AlnUI:GetThemes(kind)
    local names = {}
    for name, theme in pairs(THEMES) do
        if IsThemeAvailable(theme) and not (kind == "toast" and theme.toastTheme) then
            table.insert(names, name)
        end
    end
    table.sort(names)
    return names
end

--==================================================
-- 3. Dialogs
--==================================================

local function PlaceCloseButton(frame)
    local theme = THEMES[frame.alnTheme]
    local o = theme.closeOffset
    local x, y = -o, -o
    if theme.closePoint then x, y = theme.closePoint[1], theme.closePoint[2] end
    frame.closeButton:ClearAllPoints()
    frame.closeButton:SetPoint("TOPRIGHT", x, y)
end

local function PlaceResizeGrip(frame)
    local o = THEMES[frame.alnTheme].gripOffset
    frame.resizeButton:ClearAllPoints()
    frame.resizeButton:SetPoint("BOTTOMRIGHT", -o, o)
end

local BANNER_HEIGHT = 40
local BANNER_END_W  = 30
local BANNER_PAD    = 10

local function CreateBanner(frame)
    local mid = frame:CreateTexture(nil, "OVERLAY")
    mid:SetTexCoord(0.31, 0.67, 0, 0.63)
    mid:SetHeight(BANNER_HEIGHT)
    mid:SetPoint("TOP", frame, "TOP", 0, 12)

    mid.left = frame:CreateTexture(nil, "OVERLAY")
    mid.left:SetTexCoord(0.21, 0.31, 0, 0.63)
    mid.left:SetSize(BANNER_END_W, BANNER_HEIGHT)
    mid.left:SetPoint("RIGHT", mid, "LEFT")

    mid.right = frame:CreateTexture(nil, "OVERLAY")
    mid.right:SetTexCoord(0.67, 0.77, 0, 0.63)
    mid.right:SetSize(BANNER_END_W, BANNER_HEIGHT)
    mid.right:SetPoint("LEFT", mid, "RIGHT")
    return mid
end

local function SetBanner(frame, texture)
    local mid = frame.titleBanner
    for _, piece in ipairs({ mid, mid.left, mid.right }) do
        if texture then piece:SetTexture(texture) end
        piece:SetShown(texture ~= nil)
    end
end

local function NaturalWidth(text)
    if text.GetUnboundedStringWidth then return text:GetUnboundedStringWidth() end
    text:SetWidth(0)
    return text:GetStringWidth()
end

local function TitlePadding(frame, theme)
    if theme.header then return 2 * BANNER_END_W + BANNER_PAD end
    if theme.headerTemplate then return frame.titleHeader.headerTextPadding or 64 end
    return 0
end

local function TitleRoom(frame, theme)
    local reserve = 12
    local cb = frame.closeButton
    if cb then reserve = cb:GetWidth() + math.max(theme.closeOffset, 0) + 4 end
    return math.max(0, frame:GetWidth() - 2 * reserve)
end

local function FitTitle(frame, theme)
    local text    = frame.titleText
    local padding = TitlePadding(frame, theme)
    local natural = NaturalWidth(text)
    local art     = math.min(frame.alnTitleWidth or (natural + padding), TitleRoom(frame, theme))
    local textRoom = math.max(0, art - padding)

    frame.alnTitleTruncated = natural > textRoom
    text:SetWidth(frame.alnTitleTruncated and textRoom or 0)
    return art
end

local function PlaceDragHandle(frame, theme)
    local handle = frame.dragHandle
    handle:ClearAllPoints()
    handle:SetSize(0, 0)
    if theme.header then
        local banner = frame.titleBanner
        handle:SetPoint("TOPLEFT",     banner.left,  "TOPLEFT")
        handle:SetPoint("BOTTOMRIGHT", banner.right, "BOTTOMRIGHT")
    elseif theme.headerTemplate then
        handle:SetAllPoints(frame.titleHeader)
    else
        handle:SetHeight(28)
        handle:SetPoint("TOPLEFT",  frame, "TOPLEFT",  0, 0)
        handle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -24, 0)
    end
end

local function ApplyThemeTitle(frame, theme)
    local text = frame.titleText
    if not theme.header and not theme.headerTemplate then
        SetBanner(frame, nil)
        if frame.titleHeader then frame.titleHeader:Hide() end
        text:SetParent(frame)
        text:ClearAllPoints()
        local own = theme.templateTitle and frame.border and TemplateTitleText(frame.border)
        if own then
            for i = 1, own:GetNumPoints() do
                local point, rel, relPoint, x, y = own:GetPoint(i)
                if point == "TOP" then
                    text:SetPoint("TOP", rel or frame.border, relPoint, x, y)
                end
            end
        else
            text:SetPoint("TOP", frame, "TOP", 0, -12)
        end
        FitTitle(frame, theme)
    elseif theme.header then
        SetBanner(frame, theme.header)
        frame.titleBanner:SetWidth(math.max(0, FitTitle(frame, theme) - 2 * BANNER_END_W))
        if frame.titleHeader then frame.titleHeader:Hide() end
        text:SetParent(frame)
        text:ClearAllPoints()
        text:SetPoint("TOP", frame, "TOP", 0, 0)
    else
        SetBanner(frame, nil)
        local header = frame.titleHeader
        if not header then
            header = CreateFrame("Frame", nil, frame, theme.headerTemplate)
            frame.titleHeader = header
        end
        header:Show()
        text:SetParent(header)
        text:ClearAllPoints()
        text:SetPoint("CENTER", header, "CENTER", 0, 0)
        header:SetWidth(FitTitle(frame, theme))
    end
    PlaceDragHandle(frame, theme)
end

local dialogs = setmetatable({}, { __mode = "k" })

local function TopLevelIn(frame)
    local top = frame:GetFrameLevel()
    for i = 1, select("#", frame:GetChildren()) do
        local child = select(i, frame:GetChildren())
        top = math.max(top, TopLevelIn(child))
    end
    return top
end

local MAX_FRAME_LEVEL = 10000

local function KeepCloseButtonOnTop(frame)
    local close = frame.closeButton
    if not close then return end
    local top = frame:GetFrameLevel()
    for i = 1, select("#", frame:GetChildren()) do
        local child = select(i, frame:GetChildren())
        if child ~= close then top = math.max(top, TopLevelIn(child)) end
    end
    close:SetFrameLevel(math.min(MAX_FRAME_LEVEL, top + 1))
end

local function SetLevelKeepingOffsets(frame, level)
    local delta = level - frame:GetFrameLevel()
    if delta == 0 then return end

    local found = {}
    local function Collect(f, isRoot)
        local followsParent = not isRoot and f.IsUsingParentLevel and f:IsUsingParentLevel()
        if not followsParent then
            table.insert(found, { f, f:GetFrameLevel() })
        end
        for i = 1, select("#", f:GetChildren()) do
            Collect(select(i, f:GetChildren()), false)
        end
    end
    Collect(frame, true)

    for _, entry in ipairs(found) do
        entry[1]:SetFrameLevel(math.max(0, math.min(MAX_FRAME_LEVEL, entry[2] + delta)))
    end
end

local function BringToFront(frame)
    local strata = frame:GetFrameStrata()
    local stack, base = {}, frame:GetFrameLevel()
    for d in pairs(dialogs) do
        if d ~= frame and d:IsShown() and d:GetFrameStrata() == strata then
            table.insert(stack, d)
            base = math.min(base, d:GetFrameLevel())
        end
    end
    table.sort(stack, function(a, b) return a:GetFrameLevel() < b:GetFrameLevel() end)
    table.insert(stack, frame)

    local level = math.max(base, 1)
    for _, d in ipairs(stack) do
        SetLevelKeepingOffsets(d, level)
        KeepCloseButtonOnTop(d)
        level = TopLevelIn(d) + 1
    end
end

local function DialogOf(region)
    while region do
        if region.IsForbidden and region:IsForbidden() then return nil end
        if dialogs[region] then return region end
        region = region.GetParent and region:GetParent()
    end
end

local mouseWatcher
local function WatchMouseDown()
    if mouseWatcher ~= nil then return mouseWatcher ~= false end
    local watcher = CreateFrame("Frame")
    if not pcall(watcher.RegisterEvent, watcher, "GLOBAL_MOUSE_DOWN") then
        mouseWatcher = false
        return false
    end
    watcher:SetScript("OnEvent", function()
        local focus
        if GetMouseFoci then
            focus = GetMouseFoci()[1]
        elseif GetMouseFocus then
            focus = GetMouseFocus()
        end
        local dialog = DialogOf(focus)
        if dialog then BringToFront(dialog) end
    end)
    mouseWatcher = watcher
    return true
end

local GRIP = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-"

local function ApplyResizeBounds(frame)
    local b = frame.alnResizeBounds
    if frame.SetResizeBounds then
        frame:SetResizeBounds(b.minW, b.minH, b.maxW, b.maxH)
    else
        frame:SetMinResize(b.minW, b.minH)
        frame:SetMaxResize(b.maxW, b.maxH)
    end
end

local function CreateResizeGrip(frame)
    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(16, 16)
    grip:SetFrameLevel(frame:GetFrameLevel() + 10)
    grip:SetNormalTexture(GRIP .. "Up")
    grip:SetPushedTexture(GRIP .. "Down")
    grip:SetHighlightTexture(GRIP .. "Highlight")

    grip:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" and frame:IsResizable() then
            frame:StartSizing("BOTTOMRIGHT")
        end
    end)
    grip:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        if frame.alnOnResize then
            frame.alnOnResize(frame:GetWidth(), frame:GetHeight())
        end
    end)

    frame.resizeButton = grip
    PlaceResizeGrip(frame)
    return grip
end

local function SetResizeEnabled(frame, enabled)
    enabled = enabled and true or false
    frame:SetResizable(enabled)
    if enabled then
        ApplyResizeBounds(frame)
        local grip = frame.resizeButton or CreateResizeGrip(frame)
        grip:Show()
        KeepCloseButtonOnTop(frame)
    elseif frame.resizeButton then
        frame.resizeButton:Hide()
    end
end

local function IsResizeEnabled(frame)
    return frame:IsResizable() and true or false
end

local function SetClampedSize(frame, w, h)
    local b = frame.alnResizeBounds
    frame:SetSize(
        math.max(b.minW, math.min(b.maxW, w)),
        math.max(b.minH, math.min(b.maxH, h)))
end

local function IsTitleTruncated(frame)
    return frame.alnTitleTruncated == true
end

local function SetDialogTheme(frame, name)
    name = ResolveTheme(name, "standard")
    local theme = THEMES[name]

    local previous = frame.alnTheme
    frame.alnTheme = name
    ApplyThemeBorder(frame, theme)
    if frame.titleText and name ~= previous then
        local own = theme.templateTitle and TemplateTitleText(frame.border)
        frame.titleText:SetFontObject(own and own:GetFontObject() or "GameFontNormalLarge")
    end
    if frame.titleText    then ApplyThemeTitle(frame, theme) end
    if frame.closeButton  then PlaceCloseButton(frame) end
    if frame.resizeButton then PlaceResizeGrip(frame) end
    KeepCloseButtonOnTop(frame)
end

local function GetDialogTheme(frame)
    return frame.alnTheme
end

---A movable window.
---@param opts table?
---@return Frame
function AlnUI:CreateDialog(opts)
    opts = opts or {}

    local frame = CreateFrame(
        "Frame",
        opts.name or nil,
        opts.parent or UIParent,
        "BackdropTemplate"
    )

    frame:SetSize(opts.width or 400, opts.height or 300)
    frame:SetPoint("CENTER")
    frame.SetTheme = SetDialogTheme
    frame.GetTheme = GetDialogTheme
    frame.IsTitleTruncated = IsTitleTruncated

    if opts.strata then frame:SetFrameStrata(opts.strata) end
    if opts.level  then frame:SetFrameLevel(opts.level) end

    frame:SetMovable(true)
    frame:SetClampedToScreen(true)

    dialogs[frame] = true
    frame.BringToFront = BringToFront
    frame:EnableMouse(true)
    frame:HookScript("OnShow", BringToFront)
    frame:HookScript("OnShow", function(self)
        C_Timer.After(0, function()
            if self:IsShown() then KeepCloseButtonOnTop(self) end
        end)
    end)
    if not WatchMouseDown() then
        frame:HookScript("OnMouseDown", BringToFront)
    end
    frame:Hide()

    if opts.title then
        frame.titleBanner = CreateBanner(frame)

        local t = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        t:SetPoint("TOP", frame, "TOP", 0, 0)
        t:SetWordWrap(false)
        t:SetText(opts.title)
        frame.titleText = t

        frame.alnTitleWidth = opts.titleWidth
        local dragHandle = CreateFrame("Frame", nil, frame)
        dragHandle:EnableMouse(true)
        dragHandle:RegisterForDrag("LeftButton")
        dragHandle:SetScript("OnDragStart", function() frame:StartMoving() end)
        dragHandle:SetScript("OnDragStop",  function() frame:StopMovingOrSizing() end)
        frame.dragHandle = dragHandle

        AlnUI:AddTooltip(dragHandle, function()
            if frame.alnTitleTruncated then return frame.titleText:GetText() end
        end, nil, "ANCHOR_TOP")

        frame:HookScript("OnSizeChanged", function(self)
            if self.alnTheme then ApplyThemeTitle(self, THEMES[self.alnTheme]) end
        end)
    else
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop",  frame.StopMovingOrSizing)
    end

    if not opts.noCloseButton then
        frame.closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    end

    frame:SetTheme(opts.theme)

    frame.alnResizeBounds = {
        minW = opts.minWidth  or math.max(200, math.min(400, (opts.title
            and (opts.titleWidth or NaturalWidth(frame.titleText) + 2 * BANNER_END_W + BANNER_PAD)
            or 0) + 40)),
        minH = opts.minHeight or 150,
        maxW = opts.maxWidth  or math.floor(UIParent:GetWidth()),
        maxH = opts.maxHeight or math.floor(UIParent:GetHeight()),
    }
    frame.alnOnResize      = opts.onResize
    frame.SetResizeEnabled = SetResizeEnabled
    frame.IsResizeEnabled  = IsResizeEnabled
    frame.SetClampedSize   = SetClampedSize
    frame:SetResizeEnabled(opts.resizable)

    return frame
end

--==================================================
-- 4. Layout
--==================================================

---A row of FontStrings in columns.
---@param parent Frame
---@param opts table?
---@param cols table
---@return FontString[]
function AlnUI:CreateColumnRow(parent, opts, cols)
    opts = opts or {}

    local font     = opts.font or "GameFontHighlight"
    local anchorTo = opts.anchorTo or parent
    local x        = opts.x or 0
    local y        = opts.y or 0
    local result   = {}

    local fillIndex
    for i, col in ipairs(cols) do
        if col.fill then
            assert(not fillIndex, "AlnUI:CreateColumnRow: only one column can fill")
            fillIndex = i
        end
    end

    for i, col in ipairs(cols) do
        local fs = parent:CreateFontString(nil, "OVERLAY", font)
        if not col.fill then fs:SetWidth(col.width) end
        fs:SetJustifyH(col.justify or "LEFT")
        if col.wordWrap == false then fs:SetWordWrap(false) end
        if col.text then fs:SetText(col.text) end
        result[i] = fs
    end

    local n = #cols
    for i, fs in ipairs(result) do
        local col = cols[i]
        if not fillIndex or i < fillIndex then
            if i == 1 then
                fs:SetPoint("TOPLEFT", anchorTo, "TOPLEFT", x, y)
            else
                fs:SetPoint("LEFT", result[i - 1], "RIGHT", col.gap or 0, 0)
            end
        elseif i == fillIndex then
            if i == 1 then
                fs:SetPoint("TOPLEFT", anchorTo, "TOPLEFT", x, y)
            else
                fs:SetPoint("TOPLEFT", result[i - 1], "TOPRIGHT", col.gap or 0, 0)
            end
            if i == n then
                fs:SetPoint("TOPRIGHT", anchorTo, "TOPRIGHT", -(opts.right or 0), y)
            else
                fs:SetPoint("TOPRIGHT", result[i + 1], "TOPLEFT", -(cols[i + 1].gap or 0), 0)
            end
        else
            if i == n then
                fs:SetPoint("TOPRIGHT", anchorTo, "TOPRIGHT", -(opts.right or 0), y)
            else
                fs:SetPoint("TOPRIGHT", result[i + 1], "TOPLEFT", -(cols[i + 1].gap or 0), 0)
            end
        end
    end

    return result
end

local SORT_ARROW = "Interface\\Buttons\\UI-SortArrow"

---A column header row that sorts when its columns are clicked.
---@param parent Frame
---@param opts table?
---@param cols table
---@return Frame
function AlnUI:CreateSortHeader(parent, opts, cols)
    opts = opts or {}

    local rowOpts = {}
    for k, v in pairs(opts) do rowOpts[k] = v end
    rowOpts.font = opts.font or "GameFontNormal"

    local header = {
        labels  = self:CreateColumnRow(parent, rowOpts, cols),
        buttons = {},
    }
    local sortKey, ascending = opts.sortKey, opts.ascending

    local function Refresh()
        for i, b in pairs(header.buttons) do
            local arrow, label = b.arrow, header.labels[i]
            if b.key == sortKey then
                if ascending then
                    arrow:SetTexCoord(0, 0.5625, 1, 0)
                else
                    arrow:SetTexCoord(0, 0.5625, 0, 1)
                end
                arrow:ClearAllPoints()
                local offset = label:GetStringWidth() + 4
                if label:GetJustifyH() == "RIGHT" then
                    arrow:SetPoint("RIGHT", label, "RIGHT", -offset, 0)
                else
                    arrow:SetPoint("LEFT", label, "LEFT", offset, 0)
                end
                arrow:Show()
            else
                arrow:Hide()
            end
        end
    end

    for i, col in ipairs(cols) do
        if col.key ~= nil then
            local label = header.labels[i]
            local b = CreateFrame("Button", nil, parent)
            b:SetPoint("TOPLEFT",     label, "TOPLEFT",     -2, 2)
            b:SetPoint("BOTTOMRIGHT", label, "BOTTOMRIGHT",  2, -2)
            b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            b.key = col.key

            b.arrow = b:CreateTexture(nil, "OVERLAY")
            b.arrow:SetTexture(SORT_ARROW)
            b.arrow:SetSize(9, 8)
            b.arrow:Hide()

            b:SetScript("OnClick", function()
                if sortKey ~= col.key then
                    sortKey, ascending = col.key, true
                elseif ascending then
                    ascending = false
                else
                    sortKey, ascending = nil, nil
                end
                if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
                    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
                end
                Refresh()
                if opts.onSort then opts.onSort(sortKey, ascending) end
            end)

            header.buttons[i] = b
        end
    end

    if sortKey ~= nil and ascending == nil then ascending = true end

    function header:SetSort(key, asc)
        if key == nil then
            sortKey, ascending = nil, nil
        else
            sortKey, ascending = key, asc ~= false
        end
        Refresh()
    end

    function header:GetSort()
        return sortKey, ascending
    end

    Refresh()

    return header
end

local DEFAULT_SEPARATOR_COLOR = { 0.6, 0.6, 0.6, 0.6 }

---A horizontal line across `parent`.
---@param parent Frame
---@param opts table?
---@return Texture
function AlnUI:CreateSeparator(parent, opts)
    opts = opts or {}

    local color = opts.color or DEFAULT_SEPARATOR_COLOR
    local y     = opts.y or 0

    local line = parent:CreateTexture(nil, opts.layer or "ARTWORK")
    line:SetColorTexture(1, 1, 1, 1)
    line:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
    line:SetHeight(opts.thickness or 1)
    line:SetPoint("TOPLEFT",  parent, "TOPLEFT",  opts.x1 or 0, y)
    line:SetPoint("TOPRIGHT", parent, "TOPRIGHT", opts.x2 or 0, y)

    if line.SetSnapToPixelGrid then
        line:SetSnapToPixelGrid(false)
        line:SetTexelSnappingBias(0)
    end

    return line
end

---A scroll frame with a content frame.
---@param parent Frame
---@param opts table?
---@return ScrollFrame scroll, Frame content
function AlnUI:CreateScrollFrame(parent, opts)
    opts = opts or {}

    local scroll = CreateFrame("ScrollFrame", nil, parent, "ScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",     opts.x1 or 0,  opts.y1 or 0)
    scroll:SetPoint("BOTTOMRIGHT", opts.x2 or 0,  opts.y2 or 0)

    local bar = scroll.ScrollBar
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT",    scroll, "TOPRIGHT",    6, 0)
    bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 6, 0)

    local content = CreateFrame(opts.childType or "Frame", nil, scroll)
    content:SetSize(opts.contentWidth or 0, opts.contentHeight or 0)
    scroll:SetScrollChild(content)

    return scroll, content
end

---A scrolling list of column rows.
---@param parent Frame
---@param opts table?
---@return Frame
function AlnUI:CreateScrollList(parent, opts)
    opts = opts or {}

    local lib       = self
    local rowHeight = opts.rowHeight or 20
    local columns   = opts.columns or {}
    local font      = opts.font or "GameFontHighlight"

    local fontObject = _G[font]
    local _, fontSize = fontObject and fontObject:GetFont()
    local textY = -math.max(0, math.floor((rowHeight - (fontSize or 12)) / 2))

    local function InitRow(row, data)
        if not row.cols then
            row.cols = lib:CreateColumnRow(row, {
                font  = font,
                x     = opts.x,
                y     = textY,
                right = opts.right,
            }, columns)
        end

        local values = type(data) == "table" and data or { data }
        for i, fs in ipairs(row.cols) do
            local v = values[i]
            fs:SetText(v ~= nil and tostring(v) or "")
        end

        if opts.onRowInit then opts.onRowInit(row, data) end
    end

    local list = CreateFrame("Frame", nil, parent, "WowScrollBoxList")
    list:SetPoint("TOPLEFT",     opts.x1 or 0, opts.y1 or 0)
    list:SetPoint("BOTTOMRIGHT", opts.x2 or 0, opts.y2 or 0)

    local bar = CreateFrame("EventFrame", nil, parent, "MinimalScrollBar")
    bar:SetPoint("TOPLEFT",    list, "TOPRIGHT",    6, 0)
    bar:SetPoint("BOTTOMLEFT", list, "BOTTOMRIGHT", 6, 0)
    list.scrollBar = bar

    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(rowHeight)
    view:SetElementInitializer("Frame", InitRow)
    ScrollUtil.InitScrollBoxListWithScrollBar(list, bar, view)

    function list:SetData(rows, resetScroll)
        self.alnRows = rows
        self:SetDataProvider(CreateDataProvider(rows), not resetScroll)
    end

    function list:GetNumRows()
        return #self.alnRows
    end

    function list:ForEachRow(fn)
        for _, row in ipairs(self:GetFrames()) do
            fn(row, row.GetElementData and row:GetElementData())
        end
    end

    list:SetData(opts.data or {})

    return list
end

--==================================================
-- 5. Text
--==================================================

---A FontString.
---@param parent Frame
---@param opts table?
---@return FontString
function AlnUI:CreateLabel(parent, opts)
    opts = opts or {}

    local fs = parent:CreateFontString(nil, opts.layer or "OVERLAY", opts.font or "GameFontHighlight")
    fs:SetJustifyH(opts.justify or "LEFT")
    if opts.width then fs:SetWidth(opts.width) end
    if opts.wordWrap == false then fs:SetWordWrap(false) end
    if opts.color then
        local c = opts.color
        fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
    end
    if opts.text then fs:SetText(opts.text) end

    return fs
end

---A text box.
---@param parent Frame
---@param opts table?
---@return EditBox
function AlnUI:CreateEditBox(parent, opts)
    opts = opts or {}

    local eb = CreateFrame("EditBox", opts.name or nil, parent, "InputBoxTemplate")
    eb:SetSize(opts.width or 160, opts.height or 20)
    eb:SetAutoFocus(false)
    if opts.maxLetters then eb:SetMaxLetters(opts.maxLetters) end
    if opts.numeric then eb:SetNumeric(true) end
    if opts.text then
        eb:SetText(opts.text)
        eb:SetCursorPosition(0)
    end

    if opts.label then
        eb.label = eb:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        eb.label:SetPoint("BOTTOMLEFT", eb, "TOPLEFT", -4, 2)
        eb.label:SetText(opts.label)
    end

    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    eb:SetScript("OnEnterPressed", function(self)
        if opts.onEnterPressed then opts.onEnterPressed(self:GetText()) end
        self:ClearFocus()
    end)
    eb:SetScript("OnTextChanged", function(self, userInput)
        if userInput and opts.onTextChanged then opts.onTextChanged(self:GetText()) end
    end)

    return eb
end

--==================================================
-- 6. Controls
--==================================================

---A button.
---@param parent Frame
---@param opts table?
---@return Button
function AlnUI:CreateButton(parent, opts)
    opts = opts or {}

    local btn = CreateFrame("Button", opts.name or nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(opts.width or 120, opts.height or 24)
    btn:SetText(opts.text or "")

    if opts.onClick then
        btn:SetScript("OnClick", opts.onClick)
    end

    if opts.tooltip then
        self:AddTooltip(btn, opts.tooltip, opts.tooltipText)
    end

    if opts.disabled then
        btn:Disable()
    end

    return btn
end

---A square button showing an icon.
---@param parent Frame
---@param opts table?
---@return Button
function AlnUI:CreateIconButton(parent, opts)
    opts = opts or {}

    local size = opts.size or 32
    local btn  = CreateFrame("Button", opts.name or nil, parent)
    btn:SetSize(size, size)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(opts.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    btn.icon = icon

    btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

    btn:SetScript("OnMouseDown", function(self)
        if not self:IsEnabled() then return end
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", 1, -1)
    end)
    btn:SetScript("OnMouseUp", function()
        icon:ClearAllPoints()
        icon:SetAllPoints()
    end)
    btn:SetScript("OnDisable", function() icon:SetDesaturated(true) end)
    btn:SetScript("OnEnable",  function() icon:SetDesaturated(false) end)

    if opts.onClick then
        btn:SetScript("OnClick", opts.onClick)
    end

    if opts.tooltip then
        self:AddTooltip(btn, opts.tooltip, opts.tooltipText)
    end

    if opts.disabled then
        btn:Disable()
    end

    return btn
end

---A checkbox with a label to its right.
---@param parent Frame
---@param opts table?
---@return CheckButton
function AlnUI:CreateCheckbox(parent, opts)
    opts = opts or {}

    local cb = CreateFrame("CheckButton", opts.name or nil, parent, "UICheckButtonTemplate")

    cb.label = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    cb.label:SetPoint("LEFT", cb, "RIGHT", 4, 1)
    cb.label:SetText(opts.label or "")

    if opts.checked ~= nil then
        cb:SetChecked(opts.checked)
    end

    cb:SetScript("OnClick", function(self)
        if opts.onChange then opts.onChange(self:GetChecked()) end
    end)

    if opts.tooltip then
        self:AddTooltip(cb, opts.tooltip, opts.tooltipText)
    end

    return cb
end

---A vertical set of radio buttons.
---@param parent Frame
---@param opts table?
---@return Frame
function AlnUI:CreateRadioGroup(parent, opts)
    opts = opts or {}

    local spacing = opts.spacing or 22
    local group   = CreateFrame("Frame", nil, parent)
    group.buttons = {}
    local selected

    local function Apply(value)
        selected = value
        for _, b in ipairs(group.buttons) do
            b:SetChecked(b.value == value)
        end
    end

    for i, opt in ipairs(opts.options or {}) do
        local value, label = opt, opt
        if type(opt) == "table" then
            value = opt.value
            label = opt.label or opt.value
        end

        local b = CreateFrame("CheckButton", nil, group, "UIRadioButtonTemplate")
        b:SetPoint("TOPLEFT", 0, -(i - 1) * spacing)
        b.value = value

        b.label = b:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        b.label:SetPoint("LEFT", b, "RIGHT", 4, 1)
        b.label:SetText(tostring(label))
        b:SetHitRectInsets(0, -(b.label:GetStringWidth() + 4), 0, 0)

        b:SetScript("OnClick", function(self)
            local changed = selected ~= self.value
            Apply(self.value)
            if changed and opts.onChange then opts.onChange(self.value) end
        end)

        group.buttons[i] = b
    end

    group:SetSize(opts.width or 200, math.max(#group.buttons * spacing, 1))

    function group:GetValue() return selected end
    function group:SetValue(value) Apply(value) end

    Apply(opts.selected)

    return group
end

---A slider with a label below it.
---@param parent Frame
---@param opts table?
---@return Slider
function AlnUI:CreateSlider(parent, opts)
    opts = opts or {}

    local slider = CreateFrame("Slider", opts.name or nil, parent, "OptionsSliderTemplate")
    slider:SetWidth(opts.width or 200)
    slider:SetMinMaxValues(opts.min or 0, opts.max or 100)
    slider:SetValueStep(opts.step or 1)
    slider:SetObeyStepOnDrag(true)

    slider.label = slider:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    slider.label:SetPoint("TOP", slider, "BOTTOM", 0, -4)

    local fmt = opts.labelFormat
    slider:SetScript("OnValueChanged", function(_, value)
        if fmt then
            slider.label:SetText(string.format(fmt, value))
        end
        if opts.onChange then opts.onChange(value) end
    end)

    if opts.value ~= nil then
        slider:SetValue(opts.value)
    end

    return slider
end

local TAB_TEMPLATES = {
    top    = "PanelTopTabButtonTemplate",
    bottom = "PanelTabButtonTemplate",
}

---True when the client has the tab template for `style`.
---@param style string?
---@return boolean
function AlnUI:HasTabs(style)
    return HasTemplate(TAB_TEMPLATES[style or "top"] or "")
end

---A row of tabs, each showing its panel.
---@param parent Frame
---@param opts table?
---@return Frame
function AlnUI:CreateTabs(parent, opts)
    opts = opts or {}

    local style    = opts.style or "top"
    local template = TAB_TEMPLATES[style]
    assert(template, "AlnUI:CreateTabs: unknown style " .. tostring(style))
    assert(HasTemplate(template),
        "AlnUI:CreateTabs needs " .. template .. ", which this client does not have")

    local gap = opts.gap or 0

    local tabs = CreateFrame("Frame", nil, parent)
    tabs.buttons = {}
    tabs.panels  = {}
    tabs.Tabs = tabs.buttons
    local selected

    local function Apply(index)
        selected = index
        PanelTemplates_SetTab(tabs, index)
        for i, panel in pairs(tabs.panels) do
            panel:SetShown(i == index)
        end
    end

    local width = 0
    for i, text in ipairs(opts.tabs or {}) do
        local b = CreateFrame("Button", nil, tabs, template)
        b:SetID(i)
        b:SetText(text)
        if opts.tabWidth then
            b:SetWidth(opts.tabWidth)
        else
            PanelTemplates_TabResize(b, 0)
        end

        if i == 1 then
            b:SetPoint("TOPLEFT")
        else
            b:SetPoint("LEFT", tabs.buttons[i - 1], "RIGHT", gap, 0)
        end

        b:SetScript("OnClick", function()
            if SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB then
                PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
            end
            tabs:Select(i)
        end)

        width = width + b:GetWidth() + (i > 1 and gap or 0)
        tabs.buttons[i] = b
    end

    PanelTemplates_SetNumTabs(tabs, #tabs.buttons)
    local height = tabs.buttons[1] and tabs.buttons[1]:GetHeight() or 1
    tabs:SetSize(math.max(width, 1), height)

    for i, panel in pairs(opts.panels or {}) do
        tabs.panels[i] = panel
    end

    function tabs:Select(index)
        if index == selected or not self.buttons[index] then return end
        Apply(index)
        if opts.onSelect then opts.onSelect(index) end
    end

    function tabs:GetSelected()
        return selected
    end

    function tabs:SetPanel(index, frame)
        self.panels[index] = frame
        frame:SetShown(index == selected)
    end

    if #tabs.buttons > 0 then
        Apply(opts.selected or 1)
    end

    return tabs
end

---True when the client has the modern dropdown.
---@return boolean
function AlnUI:HasDropdown()
    return HasTemplate("WowStyle1DropdownTemplate")
end

local function NormalizeOptions(list)
    local out = {}
    for i, opt in ipairs(list or {}) do
        if type(opt) == "table" then
            out[i] = { value = opt.value, label = tostring(opt.label or opt.value) }
        else
            out[i] = { value = opt, label = tostring(opt) }
        end
    end
    return out
end

---A dropdown.
---@param parent Frame
---@param opts table?
---@return DropdownButton
function AlnUI:CreateDropdown(parent, opts)
    opts = opts or {}

    assert(self:HasDropdown(),
        "AlnUI:CreateDropdown needs WowStyle1DropdownTemplate, which this client does not have")

    local dd = CreateFrame("DropdownButton", opts.name or nil, parent, "WowStyle1DropdownTemplate")
    dd:SetWidth(opts.width or 160)
    if dd.SetDefaultText then
        dd:SetDefaultText(opts.placeholder or "Select...")
    end

    local options  = NormalizeOptions(opts.options)
    local selected = opts.selected

    local function Pick(value)
        local changed = value ~= selected
        selected = value
        if changed and opts.onChange then opts.onChange(value) end
    end

    local function Refresh()
        dd:GenerateMenu()
    end

    dd:SetupMenu(function(_, root)
        for _, o in ipairs(options) do
            root:CreateRadio(o.label,
                function() return selected == o.value end,
                function() Pick(o.value) end)
        end
    end)

    if opts.label then
        dd.label = dd:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        dd.label:SetPoint("BOTTOMLEFT", dd, "TOPLEFT", 0, 2)
        dd.label:SetText(opts.label)
    end

    if opts.tooltip then
        self:AddTooltip(dd, opts.tooltip, opts.tooltipText)
    end

    function dd:GetValue()
        return selected
    end

    function dd:SetValue(value)
        selected = value
        Refresh()
    end

    function dd:Choose(value)
        Pick(value)
        Refresh()
    end

    function dd:SetOptions(list)
        options = NormalizeOptions(list)
        Refresh()
    end

    return dd
end

--==================================================
-- 7. Feedback
--==================================================

local DEFAULT_BAR_COLOR = { 0.2, 0.7, 0.2 }

---A progress bar.
---@param parent Frame
---@param opts table?
---@return StatusBar
function AlnUI:CreateProgressBar(parent, opts)
    opts = opts or {}

    local bar = CreateFrame("StatusBar", opts.name or nil, parent)
    bar:SetSize(opts.width or 200, opts.height or 16)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")

    local c = opts.color or DEFAULT_BAR_COLOR
    bar:SetStatusBarColor(c[1], c[2], c[3], c[4] or 1)

    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    bar.bg:SetColorTexture(0, 0, 0, 0.5)

    bar.label = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.label:SetPoint("CENTER")

    local fmt = opts.labelFormat
    local function UpdateLabel()
        if not fmt then return end
        local _, max = bar:GetMinMaxValues()
        bar.label:SetText(string.format(fmt, bar:GetValue(), max))
    end
    bar:SetScript("OnValueChanged",  UpdateLabel)
    bar:SetScript("OnMinMaxChanged", UpdateLabel)

    bar:SetMinMaxValues(opts.min or 0, opts.max or 100)
    bar:SetValue(opts.value or 0)
    UpdateLabel()

    return bar
end

local function ShowTooltip(frame)
    local tip = frame.alnTooltip
    local title, text = tip.title, tip.text
    if type(title) == "function" then title, text = title(frame) end
    if not title then return end

    GameTooltip:SetOwner(frame, tip.anchor or "ANCHOR_RIGHT")
    GameTooltip:SetText(title, 1, 1, 1)
    if text then GameTooltip:AddLine(text, nil, nil, nil, true) end
    GameTooltip:Show()
end

local function HideTooltip(frame)
    if GameTooltip:GetOwner() == frame then GameTooltip:Hide() end
end

---Shows a tooltip while the mouse is over `frame`.
---@param frame Frame
---@param title string|function
---@param text string?
---@param anchor string?
---@return Frame
function AlnUI:AddTooltip(frame, title, text, anchor)
    local hooked = frame.alnTooltip ~= nil
    frame.alnTooltip = { title = title, text = text, anchor = anchor }
    if hooked then return frame end

    if frame.SetMotionScriptsWhileDisabled then
        frame:SetMotionScriptsWhileDisabled(true)
    end
    if not frame:IsMouseEnabled() and frame.SetMouseMotionEnabled then
        frame:SetMouseMotionEnabled(true)
    end

    frame:HookScript("OnEnter", ShowTooltip)
    frame:HookScript("OnLeave", HideTooltip)
    return frame
end

local toastQueue  = {}
local activeToast = nil
local showing     = {}
local PlayNextToast

local TOAST_EDGE     = 16
local TOAST_BAR_H    = 12
local TOAST_TIMER_H  = 3
local TOAST_ICON     = 64

local function BuildToastBars(f, opts)
    local bottom = 12
    local raise  = 0
    local left = opts.icon and (TOAST_EDGE + TOAST_ICON + 12) or TOAST_EDGE

    if opts.timer then
        local timer = AlnUI:CreateProgressBar(f, {
            height = TOAST_TIMER_H,
            color  = { 1, 0.82, 0 },
        })
        timer:ClearAllPoints()
        timer:SetPoint("BOTTOMLEFT",  left, bottom)
        timer:SetPoint("BOTTOMRIGHT", -TOAST_EDGE, bottom)
        f.timerBar = timer
        bottom = bottom + TOAST_TIMER_H + 4
        raise  = raise + 4
    end

    if opts.progress then
        local p = opts.progress
        local labelFormat = p.labelFormat
        if labelFormat == nil then labelFormat = "%d / %d" end
        local bar = AlnUI:CreateProgressBar(f, {
            height      = TOAST_BAR_H,
            min         = p.min or 0,
            max         = p.max or 100,
            value       = p.value or 0,
            color       = p.color,
            labelFormat = labelFormat or nil,
        })
        bar:ClearAllPoints()
        bar:SetPoint("BOTTOMLEFT",  left, bottom)
        bar:SetPoint("BOTTOMRIGHT", -TOAST_EDGE, bottom)
        f.bar = bar
        raise = raise + 10
    end

    return raise
end

local function StartToastTimer(f, duration)
    local bar = f.timerBar
    if not bar then return end
    local left = duration
    bar:SetMinMaxValues(0, duration)
    bar:SetValue(duration)
    f:SetScript("OnUpdate", function(self, elapsed)
        left = math.max(0, left - elapsed)
        bar:SetValue(left)
        if left == 0 then self:SetScript("OnUpdate", nil) end
    end)
end

local function BuildToast(opts)
    local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    f:SetSize(opts.width or 400, opts.height or 100)
    f:SetPoint("TOP", UIParent, "TOP", 0, -200)
    f:SetFrameStrata("HIGH")
    ApplyThemeBorder(f, THEMES[ResolveTheme(opts.theme, "gold", true)])
    f:SetAlpha(0)
    f:Hide()

    local textXOffset = 0
    if opts.icon then
        local icon = f:CreateTexture(nil, "ARTWORK")
        icon:SetSize(TOAST_ICON, TOAST_ICON)
        icon:SetPoint("LEFT", TOAST_EDGE, 0)
        icon:SetTexture(opts.icon)
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        textXOffset = 40
    end

    local raise = BuildToastBars(f, opts)

    if opts.title then
        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("CENTER", f, "CENTER", textXOffset, 12 + raise)
        title:SetJustifyH("CENTER")
        title:SetText(opts.title)
        f.titleText = title
    end

    if opts.text then
        local msg = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        msg:SetPoint("CENTER", f, "CENTER", textXOffset, -10 + raise)
        msg:SetJustifyH("CENTER")
        msg:SetText(opts.text)
        f.text = msg
    end

    local fadeIn = f:CreateAnimationGroup()
    local fi = fadeIn:CreateAnimation("Alpha")
    fi:SetFromAlpha(0)
    fi:SetToAlpha(1)
    fi:SetDuration(opts.fadeIn or 0.3)
    fadeIn:SetToFinalAlpha(true)

    local fadeOut = f:CreateAnimationGroup()
    local fo = fadeOut:CreateAnimation("Alpha")
    fo:SetFromAlpha(1)
    fo:SetToAlpha(0)
    fo:SetDuration(opts.fadeOut or 1)
    fadeOut:SetToFinalAlpha(true)

    f.alnOpts    = opts
    f.alnFadeIn  = fadeIn
    f.alnFadeOut = fadeOut
    return f
end

local function FinishToast(f)
    if f.alnState == "done" then return end
    f.alnState = "done"
    f.alnFadeIn:Stop()
    f.alnFadeOut:Stop()
    f:SetScript("OnUpdate", nil)
    f:Hide()
    showing[f] = nil
    if f == activeToast then
        activeToast = nil
        PlayNextToast()
    end
end

local function PlayToast(f)
    local opts = f.alnOpts
    f.alnState = "showing"
    showing[f] = true
    f:SetAlpha(0)
    f:Show()
    if opts.sound then PlaySound(opts.sound, "Master") end
    f.alnFadeIn:Play()
    StartToastTimer(f, opts.duration or 5)

    f.alnFadeOut:SetScript("OnFinished", function() FinishToast(f) end)
    C_Timer.After(opts.duration or 5, function()
        if f.alnState == "showing" then f.alnFadeOut:Play() end
    end)
end

PlayNextToast = function()
    if activeToast then return end
    activeToast = table.remove(toastQueue, 1)
    if activeToast then PlayToast(activeToast) end
end

---A toast notification.
---@param opts table?
---@return Frame
function AlnUI:ShowToast(opts)
    opts = opts or {}

    local f = BuildToast(opts)
    if opts.queue == false then
        PlayToast(f)
    else
        f.alnState = "queued"
        table.insert(toastQueue, f)
        PlayNextToast()
    end

    return f
end

---The queued toast showing now, or nil.
---@return Frame?
function AlnUI:GetActiveToast()
    return activeToast
end

---The number of toasts waiting their turn.
---@return number
function AlnUI:GetNumQueuedToasts()
    return #toastQueue
end

---Hides every toast showing and drops the queue.
function AlnUI:ClearToasts()
    local queued = toastQueue
    toastQueue = {}
    for _, f in ipairs(queued) do FinishToast(f) end

    local current = activeToast
    activeToast = nil
    if current then FinishToast(current) end

    local others = {}
    for f in pairs(showing) do table.insert(others, f) end
    for _, f in ipairs(others) do FinishToast(f) end
end


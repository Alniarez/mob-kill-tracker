-- Libs/AlnUI.lua
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
-- AlnUI:GetThemes() -> names
--
-- Returns the theme names CreateDialog, SetTheme and ShowToast accept,
-- sorted alphabetically.
--------------------------------------------------

function AlnUI:GetThemes()
    local names = {}
    for name in pairs(THEMES) do table.insert(names, name) end
    table.sort(names)
    return names
end

--------------------------------------------------
-- AlnUI:CreateDialog(opts) -> frame
--
-- opts (all optional):
--   name          string  global frame name
--   title         string  title text shown in the header banner
--   titleWidth    number  width of the header banner (default 256)
--   width         number  (default 400)
--   height        number  (default 300)
--   parent        frame   (default UIParent)
--   strata        string  frame strata
--   level         number  frame level
--   theme         string  "standard" (default) or "gold"
--   noCloseButton bool    omit the close button (default false)
--   resizable     bool    show a grip in the bottom-right corner that
--                         resizes the frame (default false)
--   minWidth      number  smallest width while resizing
--                         (default: titleWidth + 40, at least 200)
--   minHeight     number  smallest height while resizing (default 150)
--   maxWidth      number  largest width (default: screen width)
--   maxHeight     number  largest height (default: screen height)
--   onResize      func    onResize(width, height) when the player lets go
--                         of the grip; use it to save the size
--
-- Returns a hidden, movable frame anchored to CENTER with:
--   frame:SetTheme(name)         switch theme; unknown names use "standard"
--   frame:GetTheme()             current theme name
--   frame:SetResizeEnabled(bool) turn resizing (and the grip) on or off
--   frame:IsResizeEnabled()      whether resizing is on
--   frame:SetClampedSize(w, h)   set the size, kept within the resize
--                                bounds; use it to restore a saved size
--   frame.resizeButton           the grip Button (nil until resizing is
--                                first turned on)
--   frame.titleText       FontString (nil if no title given)
--   frame.titleBanner     Texture    (nil if no title given)
--   frame.closeButton     Button     (nil if noCloseButton)
--------------------------------------------------

local function SetDialogTheme(frame, name)
    if not THEMES[name] then name = "standard" end
    local theme = THEMES[name]

    frame:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = theme.edgeFile,
        edgeSize = 32,
        insets   = { left = 8, right = 8, top = 8, bottom = 8 },
    })
    if frame.titleBanner then
        frame.titleBanner:SetTexture(theme.header)
    end
    frame.alnTheme = name
end

local function GetDialogTheme(frame)
    return frame.alnTheme
end

local GRIP = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-"

local function ApplyResizeBounds(frame)
    local b = frame.alnResizeBounds
    if frame.SetResizeBounds then
        frame:SetResizeBounds(b.minW, b.minH, b.maxW, b.maxH)
    else
        -- clients from before SetResizeBounds
        frame:SetMinResize(b.minW, b.minH)
        frame:SetMaxResize(b.maxW, b.maxH)
    end
end

local function CreateResizeGrip(frame)
    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -6, 6)
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
    return grip
end

local function SetResizeEnabled(frame, enabled)
    enabled = enabled and true or false
    frame:SetResizable(enabled)
    if enabled then
        ApplyResizeBounds(frame)
        local grip = frame.resizeButton or CreateResizeGrip(frame)
        grip:Show()
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

    if opts.strata then frame:SetFrameStrata(opts.strata) end
    if opts.level  then frame:SetFrameLevel(opts.level) end

    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:Hide()

    if opts.title then
        local banner = frame:CreateTexture(nil, "OVERLAY")
        banner:SetSize(opts.titleWidth or 256, 64)
        banner:SetPoint("TOP", frame, "TOP", 0, 12)
        frame.titleBanner = banner

        local t = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        t:SetPoint("TOP", frame, "TOP", 0, 0)
        t:SetText(opts.title)
        frame.titleText = t

        local dragHandle = CreateFrame("Frame", nil, frame)
        dragHandle:SetSize(opts.titleWidth or 256, 64)
        dragHandle:SetPoint("TOP", frame, "TOP", 0, 12)
        dragHandle:EnableMouse(true)
        dragHandle:RegisterForDrag("LeftButton")
        dragHandle:SetScript("OnDragStart", function() frame:StartMoving() end)
        dragHandle:SetScript("OnDragStop",  function() frame:StopMovingOrSizing() end)
        frame.dragHandle = dragHandle
    else
        -- no title banner — drag from the whole frame
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop",  frame.StopMovingOrSizing)
    end

    if not opts.noCloseButton then
        local cb = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        cb:SetPoint("TOPRIGHT", -10, -10)
        frame.closeButton = cb
    end

    -- after the banner exists, so the theme can set its texture
    frame:SetTheme(opts.theme)

    frame.alnResizeBounds = {
        minW = opts.minWidth  or math.max(200, (opts.titleWidth or 0) + 40),
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

--------------------------------------------------
-- AlnUI:CreateColumnRow(parent, opts, cols) -> fontstrings[]
--
-- Creates a horizontal row of FontStrings on `parent`.
--
-- opts (all optional):
--   anchorTo  frame   frame to anchor the row to (default parent)
--   x         number  x offset for the first column (default 0)
--   y         number  y offset for the row (default 0)
--   right     number  inset of the last column from anchorTo's right edge;
--                     only used when a column has fill (default 0)
--   font      string  font template for all columns (default "GameFontHighlight")
--
-- cols[i]:
--   width    number  column width (ignored for the fill column)
--   fill     bool    this column takes whatever width is left between its
--                    neighbours and follows anchorTo when it resizes; the
--                    columns after it line up from the right edge. At most
--                    one column may fill.
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
            -- left to right from the first column
            if i == 1 then
                fs:SetPoint("TOPLEFT", anchorTo, "TOPLEFT", x, y)
            else
                fs:SetPoint("LEFT", result[i - 1], "RIGHT", col.gap or 0, 0)
            end
        elseif i == fillIndex then
            -- stretch between the column before it and the one after it
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
            -- right to left from the last column
            if i == n then
                fs:SetPoint("TOPRIGHT", anchorTo, "TOPRIGHT", -(opts.right or 0), y)
            else
                fs:SetPoint("TOPRIGHT", result[i + 1], "TOPLEFT", -(cols[i + 1].gap or 0), 0)
            end
        end
    end

    return result
end

--------------------------------------------------
-- AlnUI:CreateSortHeader(parent, opts, cols) -> header
--
-- A column header row whose columns sort when clicked. Lays out exactly
-- like CreateColumnRow (same opts and cols), so it lines up with rows made
-- the same way. Clicking a column cycles it through ascending, descending
-- and unsorted; unsorted means "use your default order". The sorted column
-- shows the native sort arrow.
--
-- opts: everything CreateColumnRow takes (font defaults to
-- "GameFontNormal" here), plus (all optional):
--   sortKey    any     initially sorted column key (default none)
--   ascending  bool    initial direction (default true)
--   onSort     func    onSort(key, ascending) when a click changes the
--                      sort; both are nil when the sort was cleared
--
-- cols[i]: everything CreateColumnRow takes, plus
--   key        any     sort key; columns without one are not clickable
--
-- Returns a table with:
--   header:SetSort(key, ascending)  change the sort without calling onSort;
--                                   key nil clears it, ascending defaults
--                                   to true
--   header:GetSort()                key, ascending (nil, nil when unsorted)
--   header.labels                   the column FontStrings
--   header.buttons                  clickable Buttons by column index, each
--                                   with .key and .arrow (the arrow Texture)
--------------------------------------------------

local SORT_ARROW = "Interface\\Buttons\\UI-SortArrow"

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
                -- the texture points down; flip it for ascending
                if ascending then
                    arrow:SetTexCoord(0, 0.5625, 1, 0)
                else
                    arrow:SetTexCoord(0, 0.5625, 0, 1)
                end
                -- beside the text: after it when left-aligned, before it when right-aligned
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

            -- ascending -> descending -> unsorted
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

--------------------------------------------------
-- AlnUI:CreateScrollFrame(parent, opts) -> scroll, content
--
-- Creates a ScrollFrameTemplate scroll frame (the modern slim scroll bar)
-- with a content child frame inside it. For lists of rows, prefer
-- CreateScrollList.
--
-- opts (all optional):
--   x1, y1        number  TOPLEFT offset from parent (default 0, 0)
--   x2, y2        number  BOTTOMRIGHT offset from parent (default 0, 0);
--                         the scroll bar sits outside the right edge
--   contentWidth  number  initial content width  (default 0)
--   contentHeight number  initial content height (default 0)
--   childType     string  type for the child frame (default "Frame")
--
-- Returns: scroll, content
--   scroll.ScrollBar  the scroll bar
--------------------------------------------------

function AlnUI:CreateScrollFrame(parent, opts)
    opts = opts or {}

    local scroll = CreateFrame("ScrollFrame", nil, parent, "ScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",     opts.x1 or 0,  opts.y1 or 0)
    scroll:SetPoint("BOTTOMRIGHT", opts.x2 or 0,  opts.y2 or 0)

    -- same scroll bar placement as CreateScrollList
    local bar = scroll.ScrollBar
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT",    scroll, "TOPRIGHT",    6, 0)
    bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 6, 0)

    local content = CreateFrame(opts.childType or "Frame", nil, scroll)
    content:SetSize(opts.contentWidth or 0, opts.contentHeight or 0)
    scroll:SetScrollChild(content)

    return scroll, content
end

--------------------------------------------------
-- AlnUI:CreateScrollList(parent, opts) -> list
--
-- A scrolling list of column rows, built on the ScrollBox system: only
-- visible rows exist, and they are recycled while scrolling.
--
-- opts (all optional):
--   x1, y1     number  TOPLEFT offset from parent (default 0, 0)
--   x2, y2     number  BOTTOMRIGHT offset from parent (default 0, 0);
--                      the scroll bar sits outside the right edge
--   rowHeight  number  (default 20)
--   x          number  x offset of the first column in a row (default 0)
--   right      number  inset of the last column from the row's right edge,
--                      used with a fill column (default 0)
--   font       string  font template for all columns (default "GameFontHighlight")
--   columns    table   column specs, same as CreateColumnRow's cols; give
--                      one column fill = true to have it take the width
--                      left over as the list resizes
--   onRowInit  func    called as onRowInit(row, data) after the column
--                      text is set. Rows are recycled, so reset anything
--                      you change here on every call.
--   data       table   initial rows
--
-- Each data row is an array with one value per column (shown with
-- tostring). A non-table value is shown as a single-column row.
--
-- Returns the list frame with:
--   list:SetData(rows, resetScroll)  replace all rows; keeps the scroll
--                                    position unless resetScroll is true
--   list:GetNumRows()                number of data rows
--   list:ForEachRow(fn)              calls fn(row, data) for each row frame
--                                    currently showing data
--   list.scrollBar                   the scroll bar
--   row.cols                         a row's FontStrings, in column order
--------------------------------------------------

function AlnUI:CreateScrollList(parent, opts)
    opts = opts or {}

    local lib       = self
    local rowHeight = opts.rowHeight or 20
    local columns   = opts.columns or {}
    local font      = opts.font or "GameFontHighlight"

    -- push the text down so a single line sits in the middle of the row
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

--------------------------------------------------
-- AlnUI:CreateSeparator(parent, opts) -> texture
--
-- A horizontal line across `parent`, like <hr> in HTML.
--
-- opts (all optional):
--   y          number  offset from the top of parent (default 0)
--   x1         number  offset from parent's left edge (default 0)
--   x2         number  offset from parent's right edge; negative insets
--                      the line (default 0)
--   thickness  number  line height (default 1)
--   color      table   { r, g, b, a } (default { 0.6, 0.6, 0.6, 0.6 })
--   layer      string  draw layer (default "ARTWORK")
--
-- Returns the Texture.
--------------------------------------------------

local DEFAULT_SEPARATOR_COLOR = { 0.6, 0.6, 0.6, 0.6 }

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

    -- keep thin lines from blurring or vanishing at odd UI scales
    if line.SetSnapToPixelGrid then
        line:SetSnapToPixelGrid(false)
        line:SetTexelSnappingBias(0)
    end

    return line
end

--------------------------------------------------
-- AlnUI:CreateSlider(parent, opts) -> slider
--
-- Wraps OptionsSliderTemplate with a label below it.
--
-- opts (all optional):
--   name        string  global frame name
--   width       number  slider width (default 200)
--   min         number  minimum value (default 0)
--   max         number  maximum value (default 100)
--   step        number  value step (default 1)
--   value       number  initial value; also fires onChange once on init
--   labelFormat string  format string passed to string.format(fmt, value)
--                       to auto-update the label on value change
--   onChange    func    called as onChange(value) on every value change
--
-- Returns the slider frame with:
--   slider.label  FontString below the slider
--------------------------------------------------

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

--------------------------------------------------
-- AlnUI:CreateCheckbox(parent, opts) -> checkbutton
--
-- Wraps UICheckButtonTemplate with a label to its right.
--
-- opts (all optional):
--   name      string  global frame name
--   label     string  label text
--   checked      bool    initial checked state
--   onChange     func    called as onChange(checked) on click
--   tooltip      string  tooltip title (see AddTooltip)
--   tooltipText  string  tooltip body
--
-- Returns the CheckButton with:
--   checkbox.label  FontString to the right of the button
--------------------------------------------------

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

--------------------------------------------------
-- AlnUI:CreateButton(parent, opts) -> button
--
-- Wraps UIPanelButtonTemplate.
--
-- opts (all optional):
--   name    string  global frame name
--   width   number  (default 120)
--   height  number  (default 24)
--   text         string  button label
--   onClick      func    OnClick handler
--   disabled     bool    start disabled (default false)
--   tooltip      string  tooltip title (see AddTooltip)
--   tooltipText  string  tooltip body
--
-- Returns the Button.
--------------------------------------------------

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

--------------------------------------------------
-- AlnUI:ShowToast(opts) -> frame
--
-- Shows a temporary centered-top notification that fades in, holds, then
-- fades out and hides itself. Only one toast shows at a time: while one
-- is up, new toasts wait in a queue and play in order.
--
-- opts (all optional):
--   width    number  (default 400)
--   height   number  (default 100)
--   icon     string  texture path; shown on the left at 64x64
--   title    string  large text centered slightly above middle
--   text     string  body text centered at middle
--   sound    number  sound ID played when the toast appears
--   theme    string  "gold" (default) or "standard"
--   fadeIn   number  fade-in duration in seconds (default 0.3)
--   duration number  seconds from appearing until fade-out begins (default 5)
--   fadeOut  number  fade-out duration in seconds (default 1)
--   queue    bool    set to false to show right away, on top of any
--                    toast already showing (default true)
--
-- Returns the toast frame right away; a queued toast stays hidden until
-- its turn. frame.alnState is "queued", "showing" or "done".
--
-- Related:
--   AlnUI:GetActiveToast()      the queued toast showing now, or nil
--   AlnUI:GetNumQueuedToasts()  toasts waiting their turn
--   AlnUI:ClearToasts()         hide the active toast and drop the queue
--------------------------------------------------

local toastQueue  = {}
local activeToast = nil
local PlayNextToast

local function BuildToast(opts)
    local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    f:SetSize(opts.width or 400, opts.height or 100)
    f:SetPoint("TOP", UIParent, "TOP", 0, -200)
    f:SetFrameStrata("HIGH")
    local theme = THEMES[opts.theme] or THEMES.gold
    f:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = theme.edgeFile,
        edgeSize = 32,
        insets   = { left = 8, right = 8, top = 8, bottom = 8 },
    })
    f:SetAlpha(0)
    f:Hide()

    -- When an icon is present, shift text right so it sits beside the icon.
    -- Pass opts.icon = nil to keep text fully centered with no icon.
    local textXOffset = 0
    if opts.icon then
        local icon = f:CreateTexture(nil, "ARTWORK")
        icon:SetSize(64, 64)
        icon:SetPoint("LEFT", 16, 0)
        icon:SetTexture(opts.icon)
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        textXOffset = 40
    end

    if opts.title then
        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("CENTER", f, "CENTER", textXOffset, 12)
        title:SetJustifyH("CENTER")
        title:SetText(opts.title)
    end

    if opts.text then
        local msg = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        msg:SetPoint("CENTER", f, "CENTER", textXOffset, -10)
        msg:SetJustifyH("CENTER")
        msg:SetText(opts.text)
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

-- Ends a toast; if it was the queued one showing, starts the next
local function FinishToast(f)
    if f.alnState == "done" then return end
    f.alnState = "done"
    f.alnFadeIn:Stop()
    f.alnFadeOut:Stop()
    f:Hide()
    if f == activeToast then
        activeToast = nil
        PlayNextToast()
    end
end

local function PlayToast(f)
    local opts = f.alnOpts
    f.alnState = "showing"
    f:SetAlpha(0)
    f:Show()
    if opts.sound then PlaySound(opts.sound, "Master") end
    f.alnFadeIn:Play()

    f.alnFadeOut:SetScript("OnFinished", function() FinishToast(f) end)
    C_Timer.After(opts.duration or 5, function()
        -- skip if the toast was cleared in the meantime
        if f.alnState == "showing" then f.alnFadeOut:Play() end
    end)
end

PlayNextToast = function()
    if activeToast then return end
    activeToast = table.remove(toastQueue, 1)
    if activeToast then PlayToast(activeToast) end
end

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

function AlnUI:GetActiveToast()
    return activeToast
end

function AlnUI:GetNumQueuedToasts()
    return #toastQueue
end

function AlnUI:ClearToasts()
    local queued = toastQueue
    toastQueue = {}
    for _, f in ipairs(queued) do FinishToast(f) end

    local current = activeToast
    activeToast = nil
    if current then FinishToast(current) end
end

--------------------------------------------------
-- AlnUI:AddTooltip(frame, title, text, anchor) -> frame
--
-- Shows a GameTooltip while the mouse is over `frame`. Hooks OnEnter and
-- OnLeave, so existing handlers keep working.
--
--   title   string  tooltip title, or a function(frame) returning
--                   title, text for tooltips that change (return nil to
--                   show nothing)
--   text    string  body text, wrapped (optional)
--   anchor  string  GameTooltip anchor (default "ANCHOR_RIGHT")
--
-- Sets frame.alnTooltip = { title, text, anchor }. Tooltips also show on
-- disabled buttons.
--------------------------------------------------

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
    -- leave other frames' tooltips alone
    if GameTooltip:GetOwner() == frame then GameTooltip:Hide() end
end

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

--------------------------------------------------
-- AlnUI:CreateLabel(parent, opts) -> fontstring
--
-- opts (all optional):
--   text      string  initial text
--   font      string  font template (default "GameFontHighlight")
--   color     table   { r, g, b, a }
--   width     number  fixed width (default: fits the text)
--   justify   string  "LEFT" (default), "CENTER" or "RIGHT"
--   wordWrap  bool    set to false to disable word wrap (default true)
--   layer     string  draw layer (default "OVERLAY")
--
-- Returns the FontString.
--------------------------------------------------

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

--------------------------------------------------
-- AlnUI:CreateEditBox(parent, opts) -> editbox
--
-- Wraps InputBoxTemplate. Escape and Enter clear focus.
--
-- opts (all optional):
--   name            string  global frame name
--   width           number  (default 160)
--   height          number  (default 20)
--   text            string  initial text
--   label           string  label shown above the box
--   maxLetters      number  maximum length
--   numeric         bool    digits only
--   onTextChanged   func    onTextChanged(text), for player typing only
--   onEnterPressed  func    onEnterPressed(text)
--
-- Returns the EditBox with:
--   editbox.label  FontString above the box (nil if no label given)
--------------------------------------------------

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
        -- InputBoxTemplate's border sticks out ~5px to the left
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

--------------------------------------------------
-- AlnUI:CreateIconButton(parent, opts) -> button
--
-- A square button showing an icon, with a hover highlight. The icon
-- nudges down while pressed and turns grey while disabled.
--
-- opts (all optional):
--   name         string  global frame name
--   size         number  width and height (default 32)
--   icon         string  texture path or file ID (default question mark)
--   onClick      func    OnClick handler
--   disabled     bool    start disabled (default false)
--   tooltip      string  tooltip title (see AddTooltip)
--   tooltipText  string  tooltip body
--
-- Returns the Button with:
--   button.icon  Texture
--------------------------------------------------

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

--------------------------------------------------
-- AlnUI:CreateProgressBar(parent, opts) -> statusbar
--
-- opts (all optional):
--   name         string  global frame name
--   width        number  (default 200)
--   height       number  (default 16)
--   min          number  (default 0)
--   max          number  (default 100)
--   value        number  (default 0)
--   color        table   { r, g, b, a } (default green)
--   labelFormat  string  string.format(fmt, value, max) shown centered on
--                        the bar, updated on every change
--
-- Returns the StatusBar with:
--   bar.label  FontString centered on the bar
--   bar.bg     background Texture
--------------------------------------------------

local DEFAULT_BAR_COLOR = { 0.2, 0.7, 0.2 }

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

--------------------------------------------------
-- AlnUI:CreateRadioGroup(parent, opts) -> group
--
-- A vertical set of radio buttons where only one can be selected.
--
-- opts (all optional):
--   options   table   list of { value = v, label = "text" }, or plain
--                     values used as both value and label
--   selected  any     initially selected value (default none)
--   onChange  func    onChange(value) when a click changes the selection
--   spacing   number  vertical distance between buttons (default 22)
--   width     number  group width (default 200)
--
-- Returns a Frame sized to fit its buttons, with:
--   group:GetValue()       selected value, or nil
--   group:SetValue(value)  select without calling onChange
--   group.buttons          CheckButtons, each with .value and .label
--------------------------------------------------

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
        -- make the label clickable too
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

--------------------------------------------------
-- Native template checks
--------------------------------------------------

local function HasTemplate(name)
    return C_XMLUtil ~= nil
        and C_XMLUtil.GetTemplateInfo ~= nil
        and C_XMLUtil.GetTemplateInfo(name) ~= nil
end

local TAB_TEMPLATES = {
    top    = "PanelTopTabButtonTemplate",
    bottom = "PanelTabButtonTemplate",
}

--------------------------------------------------
-- AlnUI:HasTabs(style) -> bool
--
-- True when the client has the native tab template CreateTabs needs for
-- `style` ("top" by default, or "bottom").
--------------------------------------------------

function AlnUI:HasTabs(style)
    return HasTemplate(TAB_TEMPLATES[style or "top"] or "")
end

--------------------------------------------------
-- AlnUI:CreateTabs(parent, opts) -> tabs
--
-- A row of native WoW tabs (PanelTopTabButtonTemplate or
-- PanelTabButtonTemplate, driven by PanelTemplates_*). Selecting a tab
-- shows its panel and hides the others. Errors on clients without the
-- template; check AlnUI:HasTabs(style).
--
-- opts (all optional):
--   tabs      table   tab labels
--   style     string  "top" (default): tabs on top of the content, or
--                     "bottom": tabs that hang below a frame, like the
--                     Character window. Anchor bottom tabs with e.g.
--                     tabs:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 12, 2)
--   panels    table   frames to show per tab index (can also be set
--                     later with tabs:SetPanel)
--   selected  number  initially selected index (default 1)
--   onSelect  func    onSelect(index) when the selection changes
--   tabWidth  number  fixed width for every tab (default: fit the text)
--   gap       number  horizontal space between tabs; negative overlaps
--                     them (default 0)
--
-- Returns a Frame sized to fit the row, with:
--   tabs:Select(index)          select a tab, calling onSelect if it changed
--   tabs:GetSelected()          selected index
--   tabs:SetPanel(index, frame) attach a panel to a tab
--   tabs.buttons                the tab Buttons
--   tabs.panels                 panels by tab index
--------------------------------------------------

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
    -- PanelTemplates_* look up a frame's tabs in .Tabs
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

--------------------------------------------------
-- AlnUI:HasDropdown() -> bool
--
-- True when the client has the modern dropdown (WowStyle1DropdownTemplate)
-- that CreateDropdown needs.
--------------------------------------------------

function AlnUI:HasDropdown()
    return HasTemplate("WowStyle1DropdownTemplate")
end

--------------------------------------------------
-- AlnUI:CreateDropdown(parent, opts) -> dropdown
--
-- A <select> built on the modern dropdown (WowStyle1DropdownTemplate +
-- SetupMenu). Errors on clients without it; check AlnUI:HasDropdown().
--
-- opts (all optional):
--   name         string  global frame name
--   width        number  (default 160)
--   label        string  label shown above the dropdown
--   options      table   list of { value = v, label = "text" }, or plain
--                        values used as both value and label
--   selected     any     initially selected value (default none)
--   placeholder  string  text shown while nothing is selected
--                        (default "Select...")
--   onChange     func    onChange(value) when the player picks a
--                        different option
--   tooltip      string  tooltip title (see AddTooltip)
--   tooltipText  string  tooltip body
--
-- Returns the dropdown with:
--   dropdown:GetValue()          selected value, or nil
--   dropdown:SetValue(value)     select without calling onChange
--   dropdown:Choose(value)       select as if the player picked it
--                                (calls onChange if it changed)
--   dropdown:SetOptions(list)    replace the options
--   dropdown.label               FontString above (nil if no label given)
--------------------------------------------------

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

    -- re-runs the menu generator so the shown text matches the selection
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

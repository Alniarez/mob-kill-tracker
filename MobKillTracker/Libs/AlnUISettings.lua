-- Libs/AlnUISettings.lua

local VERSION = 1

if AlnUI and (AlnUI.settingsVersion or 0) >= VERSION then return end

AlnUI = AlnUI or {}
AlnUI.settingsVersion    = VERSION
AlnUI.settingsLoadedFrom = (...)

local function HasTemplate(name)
    return C_XMLUtil ~= nil
        and C_XMLUtil.GetTemplateInfo ~= nil
        and C_XMLUtil.GetTemplateInfo(name) ~= nil
end

local function CreateFallbackSlider(parent, min, max, step, width)
    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetWidth(width)
    slider:SetMinMaxValues(min, max)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider.label = slider:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    slider.label:SetPoint("TOP", slider, "BOTTOM", 0, -4)
    return slider
end

local SP_ROW_H     = 26
local SP_HEADER_H  = 45
local SP_SPACING   = 9
local SP_PAD_TOP   = 10
local SP_PAD_LEFT  = 25
local SP_LABEL_X   = 37
local SP_INDENT    = 15
local SP_CONTROL_X = -80
local SP_CONTROL_W = 250

local function AtlasExists(atlas)
    return C_Texture ~= nil and C_Texture.GetAtlasInfo ~= nil and C_Texture.GetAtlasInfo(atlas) ~= nil
end

local function ShowRowTooltip(row, owner)
    row.hoverBackground:Show()
    if not row.alnLabel or row.alnLabel == "" then
        return
    end
    GameTooltip:SetOwner(owner or row, "ANCHOR_RIGHT")
    GameTooltip:SetText(row.alnLabel, 1, 1, 1)
    local tip = row.alnTooltip
    if type(tip) == "function" then tip = tip() end
    if tip then
        GameTooltip:AddLine(tip, 1, 0.82, 0, true)
    end
    GameTooltip:Show()
end

local function HideRowTooltip(row, owner)
    row.hoverBackground:Hide()
    if GameTooltip:GetOwner() == (owner or row.hover) then
        GameTooltip:Hide()
    end
end

local function HoverWithRow(row, frame)
    if frame.SetMotionScriptsWhileDisabled then
        frame:SetMotionScriptsWhileDisabled(true)
    end
    frame:HookScript("OnEnter", function(self) ShowRowTooltip(row, self) end)
    frame:HookScript("OnLeave", function(self) HideRowTooltip(row, self) end)
end

local SettingsPageMethods = {}

local function NewRow(page, height)
    local row = CreateFrame("Frame", nil, page.content)
    row:SetHeight(height)
    row:SetPoint("TOPLEFT", page.content, "TOPLEFT", SP_PAD_LEFT, -page.alnNextY)
    row:SetPoint("RIGHT", page.content, "RIGHT")
    page.alnNextY = page.alnNextY + height + SP_SPACING
    page.content:SetHeight(page.alnNextY - SP_SPACING + SP_PAD_TOP)
    table.insert(page.rows, row)
    return row
end

local function NewControlRow(page, o)
    local row = NewRow(page, SP_ROW_H)
    row.alnLabel   = o.label
    row.alnTooltip = o.tooltip
    row.alnEnabled = o.enabled

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)
    row.text:SetPoint("LEFT", SP_LABEL_X + (o.indent and SP_INDENT or 0), 0)
    row.text:SetPoint("RIGHT", row, "CENTER", -85, 0)
    row.text:SetText(o.label or "")

    row.hover = CreateFrame("Frame", nil, row)
    row.hover:SetPoint("TOPLEFT")
    row.hover:SetPoint("BOTTOMRIGHT", row, "BOTTOM", -80, 0)
    row.hover:SetFrameLevel(row:GetFrameLevel())
    row.hover:EnableMouse(true)
    row.hover:SetScript("OnEnter", function(self) ShowRowTooltip(row, self) end)
    row.hover:SetScript("OnLeave", function(self) HideRowTooltip(row, self) end)

    row.hoverBackground = row:CreateTexture(nil, "BACKGROUND")
    row.hoverBackground:SetPoint("TOPLEFT", row, "TOPLEFT", -10, 0)
    row.hoverBackground:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -5, 0)
    row.hoverBackground:SetColorTexture(1, 1, 1, 0.1)
    row.hoverBackground:Hide()

    function row:SetEnabled(enabled)
        if enabled then
            self.text:SetTextColor(1, 0.82, 0)
        else
            self.text:SetTextColor(0.5, 0.5, 0.5)
        end
        if self.alnSetControlEnabled then
            self.alnSetControlEnabled(enabled)
        end
    end

    return row
end

local function CreateSettingsCheckbox(row)
    if not AtlasExists("checkbox-minimal") then
        local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        cb:SetSize(26, 26)
        return cb
    end
    local cb = CreateFrame("CheckButton", nil, row)
    cb:SetSize(30, 29)
    local function Tex(atlas)
        local t = cb:CreateTexture()
        t:SetAtlas(atlas, true)
        return t
    end
    cb:SetNormalTexture(Tex("checkbox-minimal"))
    cb:SetPushedTexture(Tex("checkbox-minimal"))
    cb:SetCheckedTexture(Tex("checkmark-minimal"))
    if AtlasExists("checkmark-minimal-disabled") then
        cb:SetDisabledCheckedTexture(Tex("checkmark-minimal-disabled"))
    end
    for _, t in ipairs({ cb:GetNormalTexture(), cb:GetPushedTexture(), cb:GetCheckedTexture(),
        cb:GetDisabledCheckedTexture() }) do
        t:ClearAllPoints()
        t:SetPoint("CENTER")
    end
    return cb
end

---An options page in the game's Settings.
---@param opts table?
---@return Frame
function AlnUI:CreateSettingsPage(opts)
    opts = opts or {}

    local page = CreateFrame("Frame")
    page:Hide()
    page.name = opts.name or ""
    page.rows = {}
    page.alnNextY = SP_PAD_TOP

    page.title = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
    page.title:SetPoint("TOPLEFT", 7, -22)
    page.title:SetJustifyH("LEFT")
    page.title:SetText(page.name)

    if AtlasExists("Options_HorizontalDivider") then
        page.divider = page:CreateTexture(nil, "ARTWORK")
        page.divider:SetAtlas("Options_HorizontalDivider", true)
        page.divider:SetPoint("TOP", 0, -50)
    end

    local hasTemplate = HasTemplate("ScrollFrameTemplate")
    local scroll = CreateFrame("ScrollFrame", nil, page, hasTemplate and "ScrollFrameTemplate" or nil)
    scroll:SetPoint("TOPLEFT", -15, -52)
    scroll:SetPoint("BOTTOMRIGHT", -20, 2)
    if scroll.ScrollBar then
        local bar = scroll.ScrollBar
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 0, -4)
        bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", -1, 7)
        if bar.SetHideIfUnscrollable then
            bar:SetHideIfUnscrollable(true)
        end
    else
        scroll:EnableMouseWheel(true)
        scroll:SetScript("OnMouseWheel", function(self, delta)
            local y = self:GetVerticalScroll() - delta * (SP_ROW_H + SP_SPACING) * 2
            self:SetVerticalScroll(math.max(0, math.min(y, self:GetVerticalScrollRange())))
        end)
    end
    page.scroll = scroll

    page.content = CreateFrame("Frame", nil, scroll)
    page.content:SetSize(1, SP_PAD_TOP)
    scroll:SetScrollChild(page.content)
    scroll:SetScript("OnSizeChanged", function(self, width)
        page.content:SetWidth(width)
    end)

    for name, fn in pairs(SettingsPageMethods) do
        page[name] = fn
    end
    page:SetScript("OnShow", function(self)
        page.content:SetWidth(scroll:GetWidth())
        self:Refresh()
    end)

    return page
end

function SettingsPageMethods:AddHeader(text)
    local row = NewRow(self, SP_HEADER_H)
    row.title = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    row.title:SetJustifyH("LEFT")
    row.title:SetJustifyV("TOP")
    row.title:SetPoint("TOPLEFT", 7, -16)
    row.title:SetText(text or "")
    return row
end

function SettingsPageMethods:AddCheckbox(o)
    local row = NewControlRow(self, o)
    local cb = CreateSettingsCheckbox(row)
    cb:SetPoint("LEFT", row, "CENTER", SP_CONTROL_X, 0)
    cb:SetScript("OnClick", function(self)
        local checked = self:GetChecked() and true or false
        PlaySound(checked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        if o.set then o.set(checked) end
    end)
    HoverWithRow(row, cb)
    row.control = cb
    row.alnSetControlEnabled = function(enabled) cb:SetEnabled(enabled) end
    row.alnRefresh = function()
        cb:SetChecked(o.get and o.get() and true or false)
    end
    return row
end

local function DropdownOptions(o)
    local list = o.options
    if type(list) == "function" then list = list() end
    local out = {}
    for i, opt in ipairs(list or {}) do
        if type(opt) == "table" then
            out[i] = { value = opt.value, label = tostring(opt.label or opt.value), tooltip = opt.tooltip }
        else
            out[i] = { value = opt, label = tostring(opt) }
        end
    end
    return out
end

function SettingsPageMethods:AddDropdown(o)
    local row = NewControlRow(self, o)
    local dd, holder
    if HasTemplate("SettingsDropdownWithButtonsTemplate") then
        holder = CreateFrame("Frame", nil, row, "SettingsDropdownWithButtonsTemplate")
        holder:SetWidth(SP_CONTROL_W)
        holder:SetPoint("LEFT", row, "CENTER", SP_CONTROL_X, 3)
        dd = holder.Dropdown
        local left, right = holder.DecrementButton:GetWidth(), holder.IncrementButton:GetWidth()
        dd:ClearAllPoints()
        dd:SetPoint("LEFT", holder, "LEFT", left + 5, 0)
        dd:SetWidth(SP_CONTROL_W - left - 5 - right - 4)
    elseif HasTemplate("WowStyle1DropdownTemplate") then
        dd = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
        dd:SetWidth(SP_CONTROL_W)
        dd:SetPoint("LEFT", row, "CENTER", SP_CONTROL_X, 0)
    end
    if not dd then
        local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        text:SetPoint("LEFT", row, "CENTER", SP_CONTROL_X, 0)
        row.control = text
        row.alnRefresh = function()
            local current = o.get and o.get()
            for _, opt in ipairs(DropdownOptions(o)) do
                if opt.value == current then
                    text:SetText(opt.label)
                end
            end
        end
        return row
    end

    dd:SetupMenu(function(_, root)
        for _, opt in ipairs(DropdownOptions(o)) do
            local radio = root:CreateRadio(opt.label,
                function() return o.get and o.get() == opt.value end,
                function()
                    if o.set and o.get() ~= opt.value then
                        o.set(opt.value)
                    end
                end,
                opt.value)
            if opt.tooltip and radio.SetTooltip then
                radio:SetTooltip(function(tooltip)
                    GameTooltip_SetTitle(tooltip, opt.label)
                    GameTooltip_AddNormalLine(tooltip, opt.tooltip)
                end)
            end
        end
    end)
    HoverWithRow(row, dd)

    row.control = holder or dd
    row.dropdown = dd
    row.alnSetControlEnabled = function(enabled)
        if holder then
            holder:SetEnabled(enabled)
        else
            dd:SetEnabled(enabled)
        end
    end
    row.alnRefresh = function()
        dd:GenerateMenu()
        if holder and holder.UpdateSteppers then
            holder:UpdateSteppers()
        end
    end
    return row
end

function SettingsPageMethods:AddSlider(o)
    local row = NewControlRow(self, o)
    local min, max, step = o.min or 0, o.max or 100, o.step or 1
    local format = o.format or tostring
    local updating = false

    local function Snap(value)
        return min + math.floor((value - min) / step + 0.5) * step
    end

    local slider
    if HasTemplate("MinimalSliderWithSteppersTemplate") and MinimalSliderWithSteppersMixin then
        slider = CreateFrame("Frame", nil, row, "MinimalSliderWithSteppersTemplate")
        slider:SetWidth(SP_CONTROL_W)
        slider:SetPoint("LEFT", row, "CENTER", SP_CONTROL_X, 3)
        local steps = math.floor((max - min) / step + 0.5)
        local value = o.get and o.get() or min
        slider:Init(value, min, max, steps, { [MinimalSliderWithSteppersMixin.Label.Right] = format })
        slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, v)
            if not updating and o.set then
                o.set(Snap(v))
            end
        end, row)
        HoverWithRow(row, slider.Slider)
        row.alnSetControlEnabled = function(enabled) slider:SetEnabled(enabled) end
    else
        slider = CreateFallbackSlider(row, min, max, step, SP_CONTROL_W)
        slider:SetPoint("LEFT", row, "CENTER", SP_CONTROL_X, 0)
        slider:HookScript("OnValueChanged", function(_, v)
            slider.label:SetText(format(Snap(v)))
            if not updating and o.set then
                o.set(Snap(v))
            end
        end)
        HoverWithRow(row, slider)
        row.alnSetControlEnabled = function(enabled) slider:SetEnabled(enabled) end
    end

    row.control = slider
    row.alnRefresh = function()
        local value = o.get and o.get()
        if value == nil then
            return
        end
        updating = true
        slider:SetValue(value)
        updating = false
    end
    return row
end

function SettingsPageMethods:AddButton(o)
    local row = NewControlRow(self, o)
    local btn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    btn:SetSize(o.width or SP_CONTROL_W, SP_ROW_H)
    btn:SetText(o.text or "")
    if o.label and o.label ~= "" then
        btn:SetPoint("LEFT", row, "CENTER", SP_CONTROL_X, 0)
    else
        btn:SetPoint("LEFT", row.text, "LEFT", 0, 0)
    end
    btn:SetScript("OnClick", function(self)
        if o.onClick then o.onClick(self) end
    end)
    HoverWithRow(row, btn)
    row.control = btn
    row.alnSetControlEnabled = function(enabled) btn:SetEnabled(enabled) end
    return row
end

function SettingsPageMethods:Refresh()
    for _, row in ipairs(self.rows) do
        if row.alnRefresh then
            row.alnRefresh()
        end
        if row.SetEnabled and row.alnEnabled then
            row:SetEnabled(row.alnEnabled() and true or false)
        end
    end
end

function SettingsPageMethods:Register(parent)
    if not (Settings and Settings.RegisterCanvasLayoutCategory) then
        return nil
    end
    local category
    if parent then
        category = Settings.RegisterCanvasLayoutSubcategory(parent, self, self.name)
    else
        category = Settings.RegisterCanvasLayoutCategory(self, self.name)
        Settings.RegisterAddOnCategory(category)
    end
    self.category = category
    return category
end

function SettingsPageMethods:Open()
    if self.category and Settings.OpenToCategory then
        Settings.OpenToCategory(self.category:GetID())
    end
end

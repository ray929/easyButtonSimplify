-- easyButtonSimplify/easyButtonSimplify.lua
-- 原生动作条简化：单文件合并三个来源模块，常驻生效、无配置界面、无存档、无游戏内开关
--（停用方式 = 插件列表禁用本插件）。
--   A. 隐藏原生动作条边框 + 图标放大去边框 + 1 像素黑色描边（← HideActionBarBorders.lua）
--   B. 调整按钮原生文字（按键 / 层数 / 宏文字）字号与描边（← ButtonText.lua）
--   C. 移除额外动作条按钮（区域技能）的装饰材质与边框（← RemoveExtraActionButtonTexture.lua）
-- 依赖二进制纹理：Resources/uiactionbar2x.tga（提供方块覆盖层与悬停方槽）。

-- =========================================================
-- 公共样式常量（来源 ActionbarEnhanced/Settings.lua，此处内联为局部常量）
-- =========================================================
local FONT       = STANDARD_TEXT_FONT
local FONT_SIZE  = 16
local OUTLINE    = "THICKOUTLINE"   -- 一律加厚描边

-- =========================================================
-- A. 隐藏原生动作条边框（忠实移植自 HideActionBarBorders / emallson）
--    隐藏 NormalTexture、去掉图标圆角蒙版、把高亮/选中等覆盖层纹理重映射到动作条图集的
--    方块区域（保留悬停时的淡方槽效果）、冷却扫光铺满整钮、隐藏施法/打断边框 →
--    图标呈纯方块、无外框；并给按钮加 1 像素黑色描边（紧贴按钮内缘，盖在放大图标之上）。
-- =========================================================

local BARS = {
    "Action",
    "MultiBarBottomLeft",
    "MultiBarBottomRight",
    "MultiBarLeft",
    "MultiBarRight",
    "MultiBar5",
    "MultiBar6",
    "MultiBar7",
    "PetAction",
    "Stance",
}

local function ButtonCount(bar)
    if bar == "PetAction" or bar == "Stance" then
        return 10
    else
        return 12
    end
end

-- 动作条图集（移植自原插件）：提供方块覆盖层与各状态区域（含悬停方槽 Mouseover）。
local replacementTexture = "interface/addons/easyButtonSimplify/Resources/uiactionbar2x"

local replacementAtlas = {
    ["UI-HUD-ActionBar-IconFrame-Slot"] = { 64, 31, 0.701172, 0.951172, 0.102051, 0.162598, false, false, "2x" },
    ["UI-HUD-ActionBar-IconFrame"] = { 46, 22, 0.701172, 0.880859, 0.316895, 0.36084, false, false, "2x" },
    ["UI-HUD-ActionBar-IconFrame-AddRow"] = { 51, 25, 0.701172, 0.900391, 0.215332, 0.265137, false, false, "2x" },
    ["UI-HUD-ActionBar-IconFrame-Down"] = { 46, 22, 0.701172, 0.880859, 0.430176, 0.474121, false, false, "2x" },
    ["UI-HUD-ActionBar-IconFrame-Flash"] = { 46, 22, 0.701172, 0.880859, 0.475098, 0.519043, false, false, "2x" },
    ["UI-HUD-ActionBar-IconFrame-FlyoutBorderShadow"] = { 52, 26, 0.701172, 0.904297, 0.163574, 0.214355, false, false, "2x" },
    ["UI-HUD-ActionBar-IconFrame-Mouseover"] = { 46, 22, 0.701172, 0.880859, 0.52002, 0.563965, false, false, "2x" },
    ["UI-HUD-ActionBar-IconFrame-Border"] = { 46, 22, 0.701172, 0.880859, 0.361816, 0.405762, false, false, "2x" },
    ["UI-HUD-ActionBar-IconFrame-AddRow-Down"] = { 51, 25, 0.701172, 0.900391, 0.266113, 0.315918, false, false, "2x" },
}

-- 把覆盖层纹理重映射到图集的对应方块区域（保留悬停方槽等观感）。
local function RemapTexture(texture)
    if not texture then return end
    local atlasId = texture:GetAtlas()
    local atlas = replacementAtlas[atlasId]
    if atlas == nil then return end  -- 该纹理不是动作条图集区域则不动
    local width = texture:GetWidth()
    local height = texture:GetHeight()
    texture:SetTexture(replacementTexture)
    texture:SetTexCoord(atlas[3], atlas[4], atlas[5], atlas[6])
    texture:SetWidth(width)
    texture:SetHeight(height)
end

local function HideBorder(button)
    if button.NormalTexture then button.NormalTexture:Hide() end
    if button.icon and button.IconMask then
        pcall(button.icon.RemoveMaskTexture, button.icon, button.IconMask)
    end
end

-- 图标素材放大 1.15 倍：暴雪自带图标四周有一圈边框，放大使其溢出按钮即可裁掉。
-- 等效实现：图标与按钮同尺寸 + SetTexCoord 只取素材中央 1/ICON_SCALE 区域
--（与"放大后裁切"数学等价，视觉一致），只动 icon 纹理本身，不改按钮尺寸/位置/点击范围。
-- ⚠️ 绝不能用 button:SetClipsChildren(true) 裁整个按钮：法术弹出菜单（猎人召唤宠物、
-- 法师传送等 SpellFlyout）打开时会被暴雪 SetParent 到源按钮上（FlyoutPopupMixin:
-- AttachToButton，12.1.0 源码核实），整钮裁切会把弹出菜单一起裁掉 → 菜单被截断隐藏。
local ICON_SCALE = 1.15
local function EnlargeIcon(button)
    local icon = button.icon
    if not icon then return end
    local bw = button:GetWidth()
    if not bw or bw <= 0 then return end
    icon:ClearAllPoints()
    icon:SetAllPoints(button)
    -- 裁掉素材自带边框：只显示中央 1/ICON_SCALE 区域，铺满按钮
    local inset = (1 - 1 / ICON_SCALE) / 2
    icon:SetTexCoord(inset, 1 - inset, inset, 1 - inset)
end

-- 给按钮加 1 像素黑色描边：用 4 条 WHITE8X8 纹理紧贴按钮内缘，
-- 层级 OVERLAY 保证盖在放大图标之上；幂等，按钮尺寸自适应。
local function AddBlackBorder(button)
    if button._EBSBorderAdded then return end
    button._EBSBorderAdded = true
    local tex = "Interface\\Buttons\\WHITE8X8"
    local edges = {
        { "TOPLEFT", "TOPRIGHT", "height" },
        { "BOTTOMLEFT", "BOTTOMRIGHT", "height" },
        { "TOPLEFT", "BOTTOMLEFT", "width" },
        { "TOPRIGHT", "BOTTOMRIGHT", "width" },
    }
    for _, e in ipairs(edges) do
        local t = button:CreateTexture(nil, "OVERLAY")
        t:SetTexture(tex)
        t:SetVertexColor(0, 0, 0, 1)
        t:SetPoint(e[1], button, e[1], 0, 0)
        t:SetPoint(e[2], button, e[2], 0, 0)
        if e[3] == "height" then t:SetHeight(1) else t:SetWidth(1) end
    end
end

local function AdjustButtonOverlays(button)
    if button.cooldown then button.cooldown:SetAllPoints(button) end
    RemapTexture(button.HighlightTexture)
    RemapTexture(button.CheckedTexture)
    RemapTexture(button.SpellHighlightTexture)
    RemapTexture(button.NewActionTexture)
    RemapTexture(button.PushedTexture)
    RemapTexture(button.Border)
    if button.SlotBackground then button.SlotBackground:SetDrawLayer("BACKGROUND", -1) end
    if button.SpellCastAnimFrame then
        button.SpellCastAnimFrame:SetScript("OnShow", function(self) self:Hide() end)
    end
    if button.InterruptDisplay then
        button.InterruptDisplay:SetScript("OnShow", function(self) self:Hide() end)
    end
end

local function HideSelf(self) self:Hide() end

local function SetupBorders()
    for _, bar in ipairs(BARS) do
        for i = 1, ButtonCount(bar) do
            local key = bar .. "Button" .. i
            local button = _G[key]
            if button then
                HideBorder(button)
                EnlargeIcon(button)
                AddBlackBorder(button)
                button:HookScript("OnShow", function()
                    HideBorder(button)
                    EnlargeIcon(button)
                    AddBlackBorder(button)
                end)
                AdjustButtonOverlays(button)
                if button.NormalTexture then
                    button.NormalTexture:HookScript("OnShow", HideSelf)
                end
            end
        end
    end
end

-- =========================================================
-- B. 调整按钮原生文字（← ButtonText.lua，机制参考 MattActionBarFont，已验证战斗安全）
--    · button.HotKey  （按键绑定）   — 字号倍率 + 锚点位置 + 加厚描边
--    · button.Count   （层数）       — 字号倍率 + 锚点位置 + 加厚描边
--    · button.Name    （宏文本）     — 仅字号倍率 + 加厚描边，位置固定（按钮下方，不改）
--    直接改写按钮非安全子 FontString，并在原生刷新（UpdateHotkeys / UpdateCount / Update）
--    后重新套用，防止被原生重置冲掉。字号用「倍率」：实际像素 = round(倍率 × FONT_SIZE)。
-- =========================================================

-- 硬编码布局（倍率相对基准字号）：
--   HotKey 0.7 倍，右下角；Count 0.9 倍，右上角；宏文本 0.5 倍（位置保持原生按钮下方）。
local LAYOUT = {
    hotkey = { scale = 0.7, anchor = "BOTTOMRIGHT", x = 1, y = 1 },
    count  = { scale = 0.9, anchor = "TOPRIGHT",  x = 2, y = -4 },
    macro  = { scale = 0.5 },
}

-- 基准字号（=1.0 单位）
local function BaseSize()
    return (FONT_SIZE and FONT_SIZE > 0) and FONT_SIZE or 16
end

-- 倍率 -> 实际像素（四舍五入，至少 1）
local function Px(scale)
    return math.max(1, math.floor((scale or 1) * BaseSize() + 0.5))
end

-- 枚举所有原生动作条按钮
local STANDARD_BARS = {
    "ActionButton",
    "MultiBarBottomLeftButton",
    "MultiBarBottomRightButton",
    "MultiBarRightButton",
    "MultiBarLeftButton",
    "MultiBar5Button",
    "MultiBar6Button",
    "MultiBar7Button",
    "StanceButton",
    "PetActionButton",
    "PossessButton",
    "ExtraActionButton",
}

local function EnumerateButtons()
    local list = {}
    for _, bar in ipairs(STANDARD_BARS) do
        for i = 1, 12 do
            local button = _G[bar .. i]
            if button then
                list[#list + 1] = button
            end
        end
    end
    return list
end

-- 仅在变化时 SetFont，避免每帧重设导致文字 reflow 闪烁
local function SetFontSafe(fs, size, flags)
    if not fs or not fs.GetFont then return end
    local f, s, fl = fs:GetFont()
    local curFlags = fl or ""
    local wantFlags = flags or ""
    if f ~= FONT or s ~= size or curFlags ~= wantFlags then
        fs:SetFont(FONT, size, flags)
    end
end

local function ApplyHotKey(button)
    if not button then return end
    local fs = button.HotKey or button.bind   -- 宠物栏用 bind
    if not fs then return end
    local L = LAYOUT.hotkey
    SetFontSafe(fs, Px(L.scale), OUTLINE)
    fs:ClearAllPoints()
    fs:SetPoint(L.anchor, button, L.anchor, L.x, L.y)
end

local function ApplyCount(button)
    if not button then return end
    local fs = button.Count or _G[button:GetName() .. "Count"]
    if not fs then return end
    local L = LAYOUT.count
    SetFontSafe(fs, Px(L.scale), OUTLINE)
    fs:ClearAllPoints()
    fs:SetPoint(L.anchor, button, L.anchor, L.x, L.y)
end

-- 宏文本：只改字号 + 描边，不动位置（保留原生「按钮下方」锚点）
local function ApplyMacro(button)
    if not button then return end
    local fs = button.Name
    if not fs then return end
    SetFontSafe(fs, Px(LAYOUT.macro.scale), OUTLINE)
end

-- 遍历所有按钮，同时套用 HotKey + Count + 宏文本
local function ApplyAll()
    for _, button in ipairs(EnumerateButtons()) do
        ApplyHotKey(button)
        ApplyCount(button)
        ApplyMacro(button)
    end
end

-- Hook 持久化：原生刷新后会把 HotKey / Count / 宏文本 重置回默认，
-- 必须在其后重新套用，样式才不会被冲掉。
local hooked = false
local function EnsureHooks()
    if hooked then return end
    -- HotKey：主刷新入口
    if ActionBarActionButtonMixin and ActionBarActionButtonMixin.UpdateHotkeys then
        hooksecurefunc(ActionBarActionButtonMixin, "UpdateHotkeys", ApplyHotKey)
    end
    if type(_G.ActionButton_UpdateHotkeys) == "function" then
        hooksecurefunc("ActionButton_UpdateHotkeys", ApplyHotKey)
    end
    if type(_G.PetActionButton_UpdateHotkeys) == "function" then
        hooksecurefunc("PetActionButton_UpdateHotkeys", ApplyHotKey)
    end
    -- Count：原生刷新入口（若有）
    if ActionBarActionButtonMixin and ActionBarActionButtonMixin.UpdateCount then
        hooksecurefunc(ActionBarActionButtonMixin, "UpdateCount", ApplyCount)
    end
    if type(_G.ActionButton_UpdateCount) == "function" then
        hooksecurefunc("ActionButton_UpdateCount", ApplyCount)
    end
    -- 宏文本：按钮 action 变化时（含文字内容刷新）重套字体（位置不动，原生不会冲掉）
    if ActionBarActionButtonMixin and ActionBarActionButtonMixin.Update then
        hooksecurefunc(ActionBarActionButtonMixin, "Update", ApplyMacro)
    end
    if type(_G.ActionButton_Update) == "function" then
        hooksecurefunc("ActionButton_Update", ApplyMacro)
    end
    hooked = true
end

-- =========================================================
-- C. 移除额外动作条按钮装饰（← RemoveExtraActionButtonTexture.lua）
--    隐藏 .style/.Style 主装饰材质、NormalTexture、Border，去掉图标圆角蒙版 IconMask。
--    额外动作条/区域技能在进入特定场景时才出现，且暴雪会在更新时重新设置 style，
--    故用 0.5s 轻量 ticker 持续重施，保证装饰不重新出现。
-- =========================================================

local function StripStyle(frame)
    if not frame then return end
    -- 主装饰材质（ExtraActionButton 用 .style，ZoneAbilityFrame 用 .Style）
    local style = frame.style or frame.Style
    if style then
        style:SetAlpha(0)
        style:Hide()
    end
    -- 边框类
    if frame.NormalTexture then frame.NormalTexture:Hide() end
    if frame.Border then frame.Border:Hide() end
    -- 去掉图标圆角蒙版（移除后无法无损还原 → 停用需重载界面）
    if frame.icon and frame.IconMask then
        pcall(frame.icon.RemoveMaskTexture, frame.icon, frame.IconMask)
    end
end

local function ApplyExtraAction()
    StripStyle(ExtraActionButton1)
    if ZoneAbilityFrame then
        StripStyle(ZoneAbilityFrame)
        -- ZoneAbilityFrame 内部可能含子按钮
        if ZoneAbilityFrame.buttons then
            for _, b in ipairs(ZoneAbilityFrame.buttons) do StripStyle(b) end
        end
    end
end

-- =========================================================
-- 事件驱动（统一一个事件帧）
--   PLAYER_LOGIN          → 挂 hook + 延迟多次套用文字 + 启动额外按钮装饰 ticker
--   PLAYER_ENTERING_WORLD → 边框/图标处理（此时按钮已全部存在）+ 延迟套用文字
--   其余（翻页 / 改键）    → 重新套用文字
-- =========================================================
local extraTicker = nil
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
ev:RegisterEvent("UPDATE_BINDINGS")
ev:SetScript("OnEvent", function(_, e)
    if e == "PLAYER_LOGIN" then
        EnsureHooks()
        C_Timer.After(0.2, ApplyAll)
        C_Timer.After(1.0, ApplyAll)
        C_Timer.After(3.0, ApplyAll)
        ApplyExtraAction()
        if not extraTicker then
            extraTicker = C_Timer.NewTicker(0.5, ApplyExtraAction)
        end
    elseif e == "PLAYER_ENTERING_WORLD" then
        SetupBorders()
        C_Timer.After(0.2, ApplyAll)
        C_Timer.After(1.0, ApplyAll)
    else
        ApplyAll()
    end
end)

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
    -- 按钮尚未布局时宽高为 0：此时 SetWidth(0) 会把纹理永久压成 0，下次取宽还是 0 → 死循环。
    if not width or width <= 0 or not height or height <= 0 then return end
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

-- 覆盖层纹理重映射（幂等，只动纹理、不动布局，战斗中调用安全）。
-- ⚠️ 必须能重复执行：暴雪 BaseActionButtonMixin:UpdateButtonArt()（ActionButtonOverrides.lua）
--    会按 hideBarArt 分支无条件 SetNormalAtlas / SetPushedAtlas，把这里的 SetTexture 换成
--    暴雪图集。而 SetAtlas **不重置已有的 texcoord** → 形成「暴雪图集 + 本插件图集坐标」，
--    按下层会去采暴雪 UI 图集里一块无关区域再拉伸铺满按钮，观感就是覆盖层扭曲
--    （2026-11-11 用户实测：登录后按住快捷键扭曲、reload 后正常；dump 证据为
--     atlas="UI-HUD-ActionBar-IconFrame-AddRow-Down" + texcoord 仍是本插件值）。
--    因此本函数被 UpdateButtonArt 的 hook 与按钮 OnShow 各调一次。
local function RemapOverlays(button)
    if not button then return end
    RemapTexture(button.HighlightTexture)
    RemapTexture(button.CheckedTexture)
    RemapTexture(button.SpellHighlightTexture)
    RemapTexture(button.NewActionTexture)
    RemapTexture(button.PushedTexture)
    RemapTexture(button.Border)
end

local function AdjustButtonOverlays(button)
    if button.cooldown then button.cooldown:SetAllPoints(button) end
    RemapOverlays(button)
    if button.SlotBackground then button.SlotBackground:SetDrawLayer("BACKGROUND", -1) end
    if button.SpellCastAnimFrame then
        button.SpellCastAnimFrame:SetScript("OnShow", function(self) self:Hide() end)
    end
    if button.InterruptDisplay then
        button.InterruptDisplay:SetScript("OnShow", function(self) self:Hide() end)
    end
end

local function HideSelf(self) self:Hide() end

-- 前向声明：函数体定义在 B 段（ApplyAll 之后），SetupBorders 只在进世界时执行，
-- 那时已赋值；提前声明是为了让 SetupBorders 里能用 upvalue 而不是误判成全局。
local HookButtonText

local function SetupBorders()
    for _, bar in ipairs(BARS) do
        for i = 1, ButtonCount(bar) do
            local key = bar .. "Button" .. i
            local button = _G[key]
            if button then
                HideBorder(button)
                EnlargeIcon(button)
                AddBlackBorder(button)
                if HookButtonText then HookButtonText(button) end
                button:HookScript("OnShow", function()
                    HideBorder(button)
                    -- 暴雪可能在按钮显示前重设过图集（UpdateButtonArt），这里补一次
                    RemapOverlays(button)
                    -- ⚠️ 布局类操作（放大图标 / 加黑边）战斗内不做：按钮是保护帧，
                    --    战斗内改它会让安全路径上的数值变成 secret。脱战后 EnsureTick 会补。
                    if InCombatLockdown() then return end
                    EnlargeIcon(button)
                    AddBlackBorder(button)
                end)
                AdjustButtonOverlays(button)
                -- ⚠️ 必须 hook【按钮实例】而不是 BaseActionButtonMixin 表：XML 的 mixin 是逐键
                --    拷贝进按钮的（按钮调用的是 self:UpdateButtonArt()），改 mixin 表只换掉表里
                --    那个字段，实例仍持有旧函数引用 → 挂在表上的 hook 永不触发。同理，本文件
                --    其余挂在 ActionBarActionButtonMixin 上的 hook 也可能因此失效。
                if not button._EBSArtHooked then
                    button._EBSArtHooked = true
                    if button.UpdateButtonArt then
                        hooksecurefunc(button, "UpdateButtonArt", RemapOverlays)
                    end
                end
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

-- 逐个按钮挂文字刷新 hook（幂等）。
-- ⚠️ 必须 hook【按钮实例】：XML 的 mixin 是逐键拷贝进按钮的，按钮刷新走的是
--    self:UpdateCount() / self:UpdateHotkeys()，挂在 ActionBarActionButtonMixin 表上的
--    hooksecurefunc 只换掉表里的字段，实例仍持有旧函数引用 → 回调永不触发
--    （层数至今留在右下角、没挪到右上角，就是这么来的）。
-- 全局函数形态（ActionButton_UpdateCount 等）仍由 EnsureHooks 兜一层，两条路互不冲突。
function HookButtonText(button)
    if not button or button._EBSTextHooked then return end
    button._EBSTextHooked = true
    if type(button.UpdateHotkeys) == "function" then
        hooksecurefunc(button, "UpdateHotkeys", ApplyHotKey)
    end
    if type(button.UpdateCount) == "function" then
        hooksecurefunc(button, "UpdateCount", ApplyCount)
    end
    if type(button.Update) == "function" then
        hooksecurefunc(button, "Update", ApplyMacro)
    end
    -- 首次挂上时立刻套一次，免得新按钮要等下一次原生刷新才生效
    ApplyHotKey(button)
    ApplyCount(button)
    ApplyMacro(button)
end

-- Hook 持久化：原生刷新后会把 HotKey / Count / 宏文本 重置回默认，
-- 必须在其后重新套用，样式才不会被冲掉。
local hooked = false
local function EnsureHooks()
    if hooked then return end
    -- 兜底层：全局函数形态确实会被调用，留着；挂在 mixin 表上的这三条对**拷贝了方法的
    -- 按钮实例**无效（见 HookButtonText 的注释），真正起作用的是逐按钮注册的实例 hook。
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
    -- 覆盖层图集：BaseActionButtonMixin:UpdateButtonArt 会按 hideBarArt 分支无条件
    -- SetNormalAtlas / SetPushedAtlas，把本插件的 SetTexture 换回暴雪图集；而 SetAtlas 不重置
    -- 已有 texcoord（2026-11-11 dump 实证），于是按下层用本插件图集坐标去采暴雪 UI 图集，
    -- 表现为按住快捷键时覆盖层扭曲、reload 后正常。hook 在其后立刻重施（只动纹理，战斗安全）。
    if BaseActionButtonMixin and BaseActionButtonMixin.UpdateButtonArt then
        hooksecurefunc(BaseActionButtonMixin, "UpdateButtonArt", RemapOverlays)
    end
    if type(_G.ActionButton_UpdateButtonArt) == "function" then
        hooksecurefunc("ActionButton_UpdateButtonArt", RemapOverlays)
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
-- D. 第三方「动作条类」按钮的边框清理（通用识别，2026-11-12）
--    背景：TotemTimers 的计时器按钮（XiTimers_Timer1..N）用 `inherits="ActionButtonTemplate"`
--    建出来的 CheckButton，结构上带 .icon / .NormalTexture / IconMask，所以跟原生按钮一样
--    会画出动作条那圈灰边框。这类插件不止一个，故按**结构签名**识别，不写死名字。
--
--    识别：Button/CheckButton 且同时有 .icon 与 .NormalTexture（这是 ActionButtonTemplate 的特征）。
--    跳过：原生动作条按钮（A 段已经处理过，且它们要走 EnlargeIcon，不能在同一处混着做）。
--
--    ⚠️ 对第三方按钮只做两件事：隐藏 NormalTexture（顺带 Border）+ 加 1 像素黑色描边。
--       **绝不调用 EnlargeIcon**：这类按钮常把按钮切成两个半宽图标（TotemTimers 就是
--       18+18 两个半图 + 一条状态条），把 icon 拉满会盖掉另一半、毁掉原布局。
--
--    ⚠️ 必须脱战处理：目标可能继承 SecureActionButtonTemplate（保护帧）。
--       战斗内扫到就跳过，等下个 tick（2 秒）。
--
--    ⚠️ 光隐藏一次不够：`BaseActionButtonMixin:UpdateButtonArt` 会用 SetNormalAtlas 把边框
--       图集重新设回来（TotemTimers 自己在初始化时也调过 HideNormalTexture，边框照样回来）。
--       所以除 OnShow 重施外，还挂 UpdateButtonArt 的 hook 兜底。
-- =========================================================

local GENERIC_TARGET = setmetatable({}, { __mode = "k" })   -- 已处理（弱键：按钮销毁后自动释放）

-- 原生动作条按钮按名字前缀排除（按钮可能晚于本插件创建，所以按前缀判、不按对象快照）
local function IsStandardName(name)
    if not name then return false end
    for _, bar in ipairs(STANDARD_BARS) do
        if name:sub(1, #bar) == bar then return true end
    end
    return false
end

local function IsGenericCandidate(f)
    if not f then return false end
    local okT, otype = pcall(f.GetObjectType, f)
    if not okT or (otype ~= "Button" and otype ~= "CheckButton") then return false end
    if not (f.icon and f.NormalTexture) then return false end
    local name
    if f.GetName then name = f:GetName() end
    if IsStandardName(name) then return false end
    return true
end

-- 判断图标是否「本来就铺满按钮」（模板默认布局）。
-- 只有这种才敢放大裁切：第三方插件可能把按钮切成两个半宽图标、或把 icon 缩到一角，
-- 那种布局放大后会盖掉别的元素。实测 TotemTimers 的 icon 就是 36×36 铺满按钮。
local function IconFillsButton(button)
    local icon = button.icon
    if not icon then return false end
    local bw, bh = button:GetWidth(), button:GetHeight()
    local iw, ih = icon:GetWidth(), icon:GetHeight()
    if not (bw and bh and iw and ih and bw > 0 and bh > 0) then return false end
    return math.abs(iw - bw) < 1 and math.abs(ih - bh) < 1
end

-- 图标上现在是否真的挂着 IconMask（只看 button.IconMask 是否存在没用：它一直在，
-- 关键是它有没有被 AddMaskTexture 套到 icon 上；暴雪之后可能重新套上）
local function IconHasMask(button)
    local icon = button.icon
    if not (icon and button.IconMask and icon.GetMaskTexture) then return false end
    local ok, cur = pcall(icon.GetMaskTexture, icon)
    return ok and cur == button.IconMask
end

-- 图标是否还没做「放大裁切」（texcoord 仍是全图）。每轮补做时用来避免重复 SetTexCoord。
local function IconNeedsEnlarge(button)
    local icon = button.icon
    if not (icon and icon.GetTexCoord and IconFillsButton(button)) then return false end
    local inset = (1 - 1 / ICON_SCALE) / 2
    local ok, l = pcall(icon.GetTexCoord, icon)
    if not ok or type(l) ~= "number" then return false end
    return math.abs(l - inset) > 0.001
end

-- 幂等：把「去框 + 放大裁切 + 黑边」重施一遍。
-- ⚠️ 必须能反复跑：按钮可能在首次处理之后才完成布局（那时宽高还是 0，EnlargeIcon 会直接
--    返回），也可能被暴雪重新套上 IconMask / 重设图集。用户实测「就那一个图标有边框、别的没有」
--    就是首次处理时 GetWidth() 还是 0、之后没人补。
local function EnsureGeneric(button)
    if not button then return end
    -- 战斗中只做「隐藏」这一类只读操作；Layout/创建纹理/改 texcoord 一律推迟到脱战。
    -- ⚠️ 这些按钮可能继承 SecureActionButtonTemplate，战斗中改它们的布局会污染安全代码路径，
    --    12.x 下表现为暴雪那边的数值突然变成 secret（TotemTimers 因此抛
    --    「cannot be indexed with secret keys」，用户实测战斗中换图腾必现）。
    if button.NormalTexture and button.NormalTexture:IsShown() then
        button.NormalTexture:Hide()
    end
    if button.Border and button.Border:IsShown() then button.Border:Hide() end
    if InCombatLockdown() then return end
    if IconHasMask(button) then HideBorder(button) end    -- 摘 IconMask 也算改布局，脱战才做
    if IconNeedsEnlarge(button) then EnlargeIcon(button) end
    AddBlackBorder(button)
end

local function ApplyGeneric(button)
    if not button or GENERIC_TARGET[button] then return end
    GENERIC_TARGET[button] = true
    EnsureGeneric(button)
    if button.NormalTexture then
        button.NormalTexture:HookScript("OnShow", HideSelf)
    end
    button:HookScript("OnShow", EnsureGeneric)
end

-- 原生动作条按钮同样要每轮补：SetupBorders 只在进世界时跑一次，
-- 那时按钮可能还没显示、宽高为 0（EnlargeIcon 直接返回且不会重试）→ 素材自带黑边露出来。
-- 范围与 SetupBorders 的 BARS 完全一致，避免顺手改到宠物/载具以外的按钮。
local function EnsureStandard()
    -- ⚠️ 战斗中一律不碰：动作条按钮是保护帧，战斗内改 texcoord / 建纹理会污染安全路径，
    --    可能让暴雪返回的数值变成 secret（TotemTimers 的 flash 报错就是这么被触发的）。
    --    脱战时由 PLAYER_REGEN_ENABLED 与 2 秒 ticker 补上。
    if InCombatLockdown() then return end
    for _, bar in ipairs(BARS) do
        for i = 1, ButtonCount(bar) do
            local button = _G[bar .. "Button" .. i]
            if button then
                if IconHasMask(button) then HideBorder(button) end
                if IconNeedsEnlarge(button) then EnlargeIcon(button) end
                AddBlackBorder(button)
                -- 按钮可能晚于 SetupBorders 才创建（新角色首次进世界尤其明显），
                -- 这里补挂文字刷新 hook；已挂过的会立刻返回。
                if HookButtonText then HookButtonText(button) end
                -- 覆盖层纹理自愈：暴雪 BaseActionButtonMixin:UpdateButtonArt 会把 Pushed 等
                -- 换回自己的图集且不重置 texcoord。挂 mixin 上的 hook 对**实例拷贝的方法**
                -- 无效（XML mixin 是逐键拷进按钮的，见 ActionButton.lua:1551 的 self: 调用），
                -- 所以只能按「atlas 是否还在」这个可观测状态做幂等自愈。
                -- GetAtlas 非 nil = 已被换回；重映射后 atlas 变 nil，因此天然幂等。
                if button.PushedTexture and button.PushedTexture.GetAtlas
                    and button.PushedTexture:GetAtlas() then
                    RemapOverlays(button)
                end
            end
        end
    end
end

-- 扫描 UIParent 的顶层帧与其直接子帧（第三方按钮基本都是 UIParent 的直接子级）。
-- 不用全树递归：两秒一次 ticker 下会明显浪费；两级已覆盖 TotemTimers 这类布局。
-- 已登记的目标每轮也过一遍 EnsureGeneric（首次处理时布局可能还没就绪）。
local function ScanGeneric()
    if InCombatLockdown() then return end   -- 保护帧：战斗内一律跳过
    local ok, tops = pcall(function() return { UIParent:GetChildren() } end)
    if not ok or not tops then return end
    local function consider(f)
        if not f then return end
        if GENERIC_TARGET[f] then
            EnsureGeneric(f)
        elseif IsGenericCandidate(f) then
            ApplyGeneric(f)
        end
    end
    for _, top in ipairs(tops) do
        consider(top)
        local okC, kids = pcall(function() return { top:GetChildren() } end)
        if okC and kids then
            for _, kid in ipairs(kids) do consider(kid) end
        end
    end
end

-- 每轮保证：原生按钮 + 第三方按钮都已处理（两者都幂等、只做有必要的操作）。
-- 战斗内整体跳过：这些按钮可能是保护帧，战斗内改布局有污染风险（见 EnsureStandard 注释）。
local function EnsureTick()
    if InCombatLockdown() then return end
    EnsureStandard()
    ScanGeneric()
end

-- UpdateButtonArt 会把 NormalTexture 图集 / 图标 texcoord 重新设回来 → 对已处理的目标补一刀
local function RehideGeneric(button)
    if button and GENERIC_TARGET[button] then
        EnsureGeneric(button)
    end
end

local genericHooked = false
local function EnsureGenericHook()
    if genericHooked then return end
    genericHooked = true
    if BaseActionButtonMixin and BaseActionButtonMixin.UpdateButtonArt then
        hooksecurefunc(BaseActionButtonMixin, "UpdateButtonArt", RehideGeneric)
    end
    if type(_G.ActionButton_UpdateButtonArt) == "function" then
        hooksecurefunc("ActionButton_UpdateButtonArt", RehideGeneric)
    end
end

-- =========================================================
-- 事件驱动（统一一个事件帧）
--   PLAYER_LOGIN          → 挂 hook + 延迟多次套用文字 + 启动额外按钮装饰 ticker
--   PLAYER_ENTERING_WORLD → 边框/图标处理（此时按钮已全部存在）+ 延迟套用文字
--   其余（翻页 / 改键）    → 重新套用文字
-- =========================================================
local extraTicker = nil
local genericTicker = nil
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
ev:RegisterEvent("UPDATE_BINDINGS")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function(_, e)
    if e == "PLAYER_LOGIN" then
        EnsureHooks()
        EnsureGenericHook()
        C_Timer.After(0.2, ApplyAll)
        C_Timer.After(1.0, ApplyAll)
        C_Timer.After(3.0, ApplyAll)
        ApplyExtraAction()
        EnsureTick()
        C_Timer.After(0.5, EnsureTick)
        C_Timer.After(2.0, EnsureTick)
        if not extraTicker then
            extraTicker = C_Timer.NewTicker(0.5, ApplyExtraAction)
        end
        -- 第三方按钮按需创建（TotemTimers 扔一个图腾才建一个计时器按钮）+ 原生按钮可能
        -- 在进世界时还没宽高 → 低频整体补做（原生 + 第三方，两者都幂等）
        if not genericTicker then
            genericTicker = C_Timer.NewTicker(2, EnsureTick)
        end
    elseif e == "PLAYER_ENTERING_WORLD" then
        SetupBorders()
        EnsureGenericHook()
        EnsureTick()
        C_Timer.After(0.2, ApplyAll)
        C_Timer.After(1.0, ApplyAll)
    elseif e == "PLAYER_REGEN_ENABLED" then
        EnsureTick()   -- 战斗内跳过的第三方按钮 / 原生按钮，脱战后补处理
    else
        ApplyAll()
    end
end)

--[[
    VOID CENTER  v3.0.0
    Executor Compatible (Lvl 3+)
    Xeno / KRNL / Synapse / Fluxus

    WHITELIST:
      Only users whose UserId appears in the Free or Premium
      GitHub list can run this script. Everyone else gets an
      "not whitelisted" message and the script stops.

      Set the two URLs below to your raw GitHub file URLs.
      Each file must be a Lua script that returns a table
      of UserIds, e.g.:
          local w = { 123456789, 987654321 }
          return w

      Premium users get all troll commands.
      Free users get utility commands only.
]]

-- ═══════════════════════════════════════════════════════════
-- SERVICES
-- ═══════════════════════════════════════════════════════════
local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local UserInputService   = game:GetService("UserInputService")
local TweenService       = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local Stats              = game:GetService("Stats")
local Debris             = game:GetService("Debris")

local LP     = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ═══════════════════════════════════════════════════════════
-- WHITELIST  ← Set your GitHub URLs here
-- ═══════════════════════════════════════════════════════════
local URL_PREM = "https://raw.githubusercontent.com/MucioMan17/Void-Center-Users/refs/heads/main/prem"
-- Premium user list — only these users get troll commands
local LOCAL_PREM = {
    -- 123456789,
}

-- freeIds is unused now — everyone can run the script
-- premIds controls who gets premium tier
local freeIds = {}
local premIds = {}

local function LoadPrem(url, localList)
    for _, id in ipairs(localList) do
        premIds[id] = true
    end
    if url and url ~= "" then
        local ok, result = pcall(function()
            return loadstring(game:HttpGet(url))()
        end)
        if ok and type(result) == "table" then
            for _, id in ipairs(result) do
                if type(id) == "number" then
                    premIds[id] = true
                end
            end
        end
    end
end

-- Only load premium list — free tier is open to everyone
LoadPrem(URL_PREM, LOCAL_PREM)

warn("[VoidCenter] MyId="..tostring(LP.UserId).." | Premium="..tostring(premIds[LP.UserId] == true))

local function IsPremium(player)
    local p = player or LP
    return premIds[p.UserId] == true
end

-- ═══════════════════════════════════════════════════════════
-- CONFIG
-- ═══════════════════════════════════════════════════════════
local Config = {
    Prefix     = ";",
    FlySpeed   = 50,
    Version    = "3.0.0",
    ActiveCmds = {},
}

-- ═══════════════════════════════════════════════════════════
-- SAFE GUI PARENT (CoreGui -> PlayerGui fallback)
-- ═══════════════════════════════════════════════════════════
local GuiParent
pcall(function() GuiParent = game:GetService("CoreGui") end)
if not GuiParent then GuiParent = LP:WaitForChild("PlayerGui") end

pcall(function()
    local old = GuiParent:FindFirstChild("VoidCenter")
    if old then old:Destroy() end
end)

-- ═══════════════════════════════════════════════════════════
-- THEME
-- ═══════════════════════════════════════════════════════════
local C = {
    BG      = Color3.fromRGB(8,   0,  18),
    Panel   = Color3.fromRGB(14,  0,  30),
    Card    = Color3.fromRGB(22,  0,  48),
    CardLt  = Color3.fromRGB(35,  0,  70),
    Accent  = Color3.fromRGB(140, 45, 255),
    AcctBr  = Color3.fromRGB(185, 90, 255),
    AcctDk  = Color3.fromRGB(90,  20, 170),
    Text    = Color3.fromRGB(240, 225, 255),
    TextDim = Color3.fromRGB(165, 140, 200),
    Green   = Color3.fromRGB(80,  255, 150),
    Yellow  = Color3.fromRGB(255, 200, 50),
    Red     = Color3.fromRGB(255, 65,  65),
    Gold    = Color3.fromRGB(255, 210, 55),
    Black   = Color3.fromRGB(0,   0,   0),
    White   = Color3.fromRGB(255, 255, 255),
}

-- ═══════════════════════════════════════════════════════════
-- UTILITY HELPERS
-- ═══════════════════════════════════════════════════════════
local function N(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end

local function Tween(inst, ti, props)
    TweenService:Create(inst, ti, props):Play()
end

local TF  = TweenInfo.new(0.18, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out)
local TM  = TweenInfo.new(0.30, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out)
local TS  = TweenInfo.new(0.40, Enum.EasingStyle.Back,  Enum.EasingDirection.Out)
local TSI = TweenInfo.new(0.30, Enum.EasingStyle.Back,  Enum.EasingDirection.In)

local function Corner(r, p) N("UICorner", {CornerRadius = UDim.new(0, r)}, p) end
local function Stroke(col, th, p) N("UIStroke", {Color = col, Thickness = th or 1}, p) end
local function Pad(t, b, l, r, p)
    N("UIPadding", {
        PaddingTop    = UDim.new(0, t),
        PaddingBottom = UDim.new(0, b),
        PaddingLeft   = UDim.new(0, l),
        PaddingRight  = UDim.new(0, r),
    }, p)
end

-- ═══════════════════════════════════════════════════════════
-- FIND PLAYER  (username OR display name, exact then partial)
-- ═══════════════════════════════════════════════════════════
local function FindPlayer(query)
    if not query or query == "" then return nil end
    local q = query:lower():gsub("^@", "")   -- strip leading @

    -- 1. Exact username
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name:lower() == q then return p end
    end
    -- 2. Exact display name
    for _, p in ipairs(Players:GetPlayers()) do
        if p.DisplayName:lower() == q then return p end
    end
    -- 3. Partial username
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name:lower():find(q, 1, true) then return p end
    end
    -- 4. Partial display name
    for _, p in ipairs(Players:GetPlayers()) do
        if p.DisplayName:lower():find(q, 1, true) then return p end
    end
    return nil
end

local function PStr(p)
    return p.DisplayName .. " (@" .. p.Name .. ")"
end

-- ═══════════════════════════════════════════════════════════
-- SCREEN GUI
-- ═══════════════════════════════════════════════════════════
local Screen = N("ScreenGui", {
    Name           = "VoidCenter",
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    ResetOnSpawn   = false,
    DisplayOrder   = 999,
}, GuiParent)

-- ═══════════════════════════════════════════════════════════
-- NOTIFICATIONS
-- ═══════════════════════════════════════════════════════════
local NHolder = N("Frame", {
    BackgroundTransparency = 1,
    Position = UDim2.new(1, -316, 0, 48),
    Size     = UDim2.new(0, 300, 1, -64),
    ZIndex   = 500,
}, Screen)
N("UIListLayout", {
    SortOrder         = Enum.SortOrder.LayoutOrder,
    VerticalAlignment = Enum.VerticalAlignment.Top,
    Padding           = UDim.new(0, 6),
}, NHolder)

local nid = 0
local function Notify(title, body, kind, dur)
    kind = kind or "info"
    dur  = dur  or 6
    nid  = nid + 1
    local accent = kind == "success" and C.Green
                or kind == "warning" and C.Yellow
                or kind == "error"   and C.Red
                or kind == "gold"    and C.Gold
                or C.Accent
    local icon = kind == "success" and "+"
              or kind == "warning" and "!"
              or kind == "error"   and "x"
              or kind == "gold"    and "*"
              or "-"

    -- fixed height: 76px total - no AutomaticSize, no ClipsDescendants
    local card = N("Frame", {
        BackgroundColor3 = Color3.fromRGB(11, 3, 22),
        BorderSizePixel  = 0,
        Size             = UDim2.new(1, 0, 0, 76),
        LayoutOrder      = nid,
        Position         = UDim2.new(1.15, 0, 0, 0),
    }, NHolder)
    Corner(10, card)
    Stroke(accent, 1, card)

    -- Left colour bar
    local bar3 = N("Frame", {
        BackgroundColor3 = accent, BorderSizePixel = 0,
        Size = UDim2.new(0, 3, 1, 0),
    }, card)
    Corner(10, bar3)

    -- Icon pill
    local ipill = N("Frame", {
        BackgroundColor3 = accent, BackgroundTransparency = 0.72,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 12, 0, 12),
        Size     = UDim2.new(0, 22, 0, 22),
    }, card)
    Corner(11, ipill)
    N("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1,0,1,0),
        Font = Enum.Font.GothamBold, Text = icon,
        TextColor3 = accent, TextSize = 12,
    }, ipill)

    -- Title
    N("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 42, 0, 10), Size = UDim2.new(1, -78, 0, 22),
        Font = Enum.Font.GothamBold, Text = title,
        TextColor3 = C.Text, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
    }, card)

    -- Body
    N("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 34), Size = UDim2.new(1, -18, 0, 28),
        Font = Enum.Font.Gotham, Text = body,
        TextColor3 = Color3.fromRGB(175, 155, 210), TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true, TextTruncate = Enum.TextTruncate.AtEnd,
    }, card)

    -- Dismiss button
    local xBtn = N("TextButton", {
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -26, 0, 6), Size = UDim2.new(0, 20, 0, 20),
        Font = Enum.Font.GothamBold, Text = "X",
        TextColor3 = Color3.fromRGB(100, 80, 130), TextSize = 10,
    }, card)

    -- Progress track (fixed position at bottom of fixed-height card)
    local track = N("Frame", {
        BackgroundColor3 = Color3.fromRGB(28, 12, 50), BorderSizePixel = 0,
        Position = UDim2.new(0, 3, 1, -4), Size = UDim2.new(1, -6, 0, 3),
    }, card)
    Corner(2, track)
    local prog = N("Frame", {
        BackgroundColor3 = accent, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 1, 0),
    }, track)
    Corner(2, prog)

    -- Animate in
    Tween(card, TS, {Position = UDim2.new(0, 0, 0, 0)})
    Tween(prog, TweenInfo.new(dur, Enum.EasingStyle.Linear), {Size = UDim2.new(0, 0, 1, 0)})

    local alive = true
    local function dismiss()
        if not alive then return end
        alive = false
        Tween(card, TM, {Position = UDim2.new(1.15, 0, 0, 0)})
        task.delay(0.35, function() pcall(function() card:Destroy() end) end)
    end
    xBtn.MouseButton1Click:Connect(dismiss)
    task.delay(dur, dismiss)
end

-- ═══════════════════════════════════════════════════════════
-- HUD WIDGET  (draggable pill, auto-resizes to content)
-- ═══════════════════════════════════════════════════════════
-- Uses AutomaticSize so every section is exactly as wide as
-- its text — nothing ever gets cut off.
-- ═══════════════════════════════════════════════════════════

-- Outer frame: height fixed at 28, width grows automatically
local Panel = N("Frame", {
    Name                   = "VCHud",
    BackgroundColor3       = C.Panel,
    BackgroundTransparency = 0.12,
    BorderSizePixel        = 0,
    Position               = UDim2.new(0, 8, 0, 8),
    Size                   = UDim2.new(0, 0, 0, 28),  -- width driven by AutomaticSize
    AutomaticSize          = Enum.AutomaticSize.X,
    ZIndex                 = 200,
    Active                 = true,
}, Screen)
Corner(8, Panel)
Stroke(C.Accent, 1, Panel)

-- Horizontal list layout — each child sits side by side
local PList = N("UIListLayout", {
    FillDirection  = Enum.FillDirection.Horizontal,
    SortOrder      = Enum.SortOrder.LayoutOrder,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    Padding        = UDim.new(0, 0),
}, Panel)

-- Helper: one section (label that auto-sizes to its text)
local function PSection(text, color, bold, order)
    local f = N("Frame", {
        BackgroundTransparency = 1,
        Size           = UDim2.new(0, 0, 1, 0),
        AutomaticSize  = Enum.AutomaticSize.X,
        LayoutOrder    = order,
        ZIndex         = 201,
    }, Panel)
    local lbl = N("TextLabel", {
        BackgroundTransparency = 1,
        Size          = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        Font          = bold and Enum.Font.GothamBold or Enum.Font.Gotham,
        Text          = text,
        TextColor3    = color or C.TextDim,
        TextSize      = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex        = 202,
    }, f)
    -- Padding inside each section
    N("UIPadding", {
        PaddingLeft  = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 8),
    }, f)
    return lbl
end

-- Helper: thin vertical divider between sections
local function PDivider(order)
    N("Frame", {
        BackgroundColor3       = C.Accent,
        BackgroundTransparency = 0.55,
        BorderSizePixel        = 0,
        Size                   = UDim2.new(0, 1, 0.7, 0),
        LayoutOrder            = order,
        ZIndex                 = 202,
    }, Panel)
end

--  VOID CENTER  |  FPS  |  PING  |  TIER  [|  active...]
PSection("VOID CENTER", C.AcctBr, true, 1)
PDivider(2)
local LblFPS  = PSection("FPS --",  C.TextDim, false, 3)
PDivider(4)
local LblPing = PSection("-- ms",   C.TextDim, false, 5)
PDivider(6)
local LblTier = PSection(
    IsPremium() and "PREMIUM" or "FREE",
    IsPremium() and C.Gold    or C.AcctDk,
    true, 7)

-- Active commands section — hidden when nothing is active
local DivActive = N("Frame", {
    BackgroundColor3       = C.Accent,
    BackgroundTransparency = 0.55,
    BorderSizePixel        = 0,
    Size                   = UDim2.new(0, 1, 0.7, 0),
    LayoutOrder            = 8,
    ZIndex                 = 202,
    Visible                = false,
}, Panel)
local LblActive = N("TextLabel", {
    BackgroundTransparency = 1,
    Size          = UDim2.new(0, 0, 1, 0),
    AutomaticSize = Enum.AutomaticSize.X,
    Font          = Enum.Font.Gotham,
    Text          = "",
    TextColor3    = C.AcctBr,
    TextSize      = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
    LayoutOrder   = 9,
    ZIndex        = 202,
}, Panel)
N("UIPadding", {
    PaddingLeft  = UDim.new(0, 8),
    PaddingRight = UDim.new(0, 8),
}, LblActive)

-- Drag
local dragging, dragStart, startPos
Panel.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
    or inp.UserInputType == Enum.UserInputType.Touch then
        dragging = true dragStart = inp.Position startPos = Panel.Position
    end
end)
Panel.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
    or inp.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)
UserInputService.InputChanged:Connect(function(inp)
    if not dragging then return end
    if inp.UserInputType ~= Enum.UserInputType.MouseMovement
    and inp.UserInputType ~= Enum.UserInputType.Touch then return end
    local d = inp.Position - dragStart
    Panel.Position = UDim2.new(
        startPos.X.Scale, startPos.X.Offset + d.X,
        startPos.Y.Scale, startPos.Y.Offset + d.Y)
end)

-- FPS counter
local fpsBuf = {}
RunService.Heartbeat:Connect(function(dt)
    table.insert(fpsBuf, dt)
    if #fpsBuf > 20 then table.remove(fpsBuf, 1) end
    local s = 0
    for _, v in ipairs(fpsBuf) do s = s + v end
    local fps = math.floor(1 / (s / #fpsBuf))
    LblFPS.Text       = "FPS "..fps
    LblFPS.TextColor3 = fps >= 50 and C.Green or (fps >= 30 and C.Yellow or C.Red)
end)

-- Ping counter
task.spawn(function()
    while task.wait(3) do
        pcall(function()
            local ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
            LblPing.Text       = ping.."ms"
            LblPing.TextColor3 = ping < 80 and C.Green or (ping < 160 and C.Yellow or C.Red)
        end)
    end
end)

-- Active commands display — shows/hides the extra section
local function RefreshActive()
    local list = {}
    for k in pairs(Config.ActiveCmds) do table.insert(list, k) end
    table.sort(list)
    if #list == 0 then
        LblActive.Text      = ""
        DivActive.Visible   = false
    else
        LblActive.Text      = table.concat(list, "  |  ")
        DivActive.Visible   = true
    end
end

-- ═══════════════════════════════════════════════════════════
-- COMMAND REGISTRY
-- ═══════════════════════════════════════════════════════════
local Registry = {}

local function Reg(name, aliases, desc, premium, fn)
    local e = {name=name, aliases=aliases or {}, desc=desc or "", premium=premium or false, fn=fn}
    Registry[name:lower()] = e
    for _, a in ipairs(aliases) do Registry[a:lower()] = e end
end

local function ExecCmd(raw)
    raw = raw:match("^%s*(.-)%s*$")
    if raw == "" then return end
    local parts = {}
    for w in raw:gmatch("%S+") do table.insert(parts, w) end
    local key  = parts[1]:lower()
    local args = {}
    for i = 2, #parts do table.insert(args, parts[i]) end

    local cmd = Registry[key]
    if not cmd then
        Notify("Unknown", "No command: '" .. key .. "' - try 'help'", "error"); return
    end
    if cmd.premium and not IsPremium() then
        Notify("Premium Only", "'" .. cmd.name .. "' requires Premium", "gold", 4); return
    end
    pcall(cmd.fn, args)
end

-- ═══════════════════════════════════════════════════════════
-- COMMAND BAR UI
-- ═══════════════════════════════════════════════════════════
local CmdOpen = false

local Dimmer = N("Frame", {
    BackgroundColor3 = C.Black, BackgroundTransparency = 0.5,
    BorderSizePixel = 0, Size = UDim2.new(1,0,1,0), ZIndex = 280, Visible = false,
    Active = true,
}, Screen)

local CmdFrame = N("Frame", {
    AnchorPoint      = Vector2.new(0.5, 0),
    BackgroundColor3 = C.BG,
    BorderSizePixel  = 0,
    Position         = UDim2.new(0.5, 0, 0.37, 0),
    Size             = UDim2.new(0, 560, 0, 52),
    ZIndex           = 300,
    Visible          = false,
    ClipsDescendants = false,
}, Screen)
Corner(12, CmdFrame)
Stroke(C.Accent, 1.5, CmdFrame)

local PBadge = N("Frame", {
    BackgroundColor3 = C.CardLt, BorderSizePixel = 0,
    Position = UDim2.new(0,8,0.5,-14), Size = UDim2.new(0,28,0,28), ZIndex = 302,
}, CmdFrame)
Corner(8, PBadge)
local PrefLbl = N("TextLabel", {
    BackgroundTransparency = 1, Size = UDim2.new(1,0,1,0),
    Font = Enum.Font.GothamBold, Text = Config.Prefix,
    TextColor3 = C.AcctBr, TextSize = 18, ZIndex = 303,
}, PBadge)

local CmdInput = N("TextBox", {
    BackgroundTransparency = 1,
    Position = UDim2.new(0,44,0,0), Size = UDim2.new(1,-52,1,0),
    Font = Enum.Font.Gotham,
    PlaceholderText = "type a command...  (username or display name works)",
    PlaceholderColor3 = Color3.fromRGB(90,65,130),
    Text = "", TextColor3 = C.Text, TextSize = 15,
    TextXAlignment = Enum.TextXAlignment.Left,
    ClearTextOnFocus = false, ZIndex = 302,
}, CmdFrame)

N("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.new(0,44,1,8), Size = UDim2.new(1,-52,0,14),
    Font = Enum.Font.Gotham,
    Text = "ENTER to run  -  TAB autocomplete  -  ESC close",
    TextColor3 = Color3.fromRGB(65,50,95), TextSize = 10, ZIndex = 301,
}, CmdFrame)

-- Suggestion dropdown
local SugBox = N("Frame", {
    BackgroundColor3 = C.Card, BorderSizePixel = 0,
    Position = UDim2.new(0,0,1,10), Size = UDim2.new(1,0,0,0),
    ZIndex = 300, ClipsDescendants = true,
}, CmdFrame)
Corner(10, SugBox)
Stroke(C.Accent, 1, SugBox)
Pad(5,5,5,5, SugBox)
N("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0,3)}, SugBox)

local function ClearSuggs()
    for _, c in ipairs(SugBox:GetChildren()) do
        if c:IsA("TextButton") or c:IsA("Frame") then c:Destroy() end
    end
    Tween(SugBox, TF, {Size = UDim2.new(1,0,0,0)})
end

local function BuildSuggs(text)
    ClearSuggs()
    if text == "" then return end
    local matches, seen = {}, {}
    for k, e in pairs(Registry) do
        if k:sub(1,#text):lower() == text:lower() and not seen[e.name] then
            seen[e.name] = true
            table.insert(matches, e)
        end
    end
    if #matches == 0 then return end
    table.sort(matches, function(a,b) return a.name < b.name end)
    local shown = math.min(#matches, 6)
    local ROW   = 40
    for i, e in ipairs(matches) do
        if i > 6 then break end
        local btn = N("TextButton", {
            BackgroundColor3 = C.CardLt, BorderSizePixel = 0,
            Size = UDim2.new(1,0,0,ROW), Text = "", LayoutOrder = i, ZIndex = 305,
        }, SugBox)
        Corner(7, btn)
        N("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.new(0,10,0,4), Size = UDim2.new(0.55,0,0,18),
            Font = Enum.Font.GothamBold,
            Text = e.name .. (e.premium and "  *" or ""),
            TextColor3 = e.premium and C.Gold or C.AcctBr,
            TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 306,
        }, btn)
        N("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.new(0,10,0,22), Size = UDim2.new(1,-14,0,14),
            Font = Enum.Font.Gotham, Text = e.desc,
            TextColor3 = C.TextDim, TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 306,
        }, btn)
        if #e.aliases > 0 then
            N("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.new(1,-70,0,4), Size = UDim2.new(0,64,0,18),
                Font = Enum.Font.Gotham, Text = table.concat(e.aliases," "),
                TextColor3 = C.AcctDk, TextSize = 10,
                TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 306,
            }, btn)
        end
        btn.MouseButton1Click:Connect(function()
            CmdInput.Text = e.name .. " "
            CmdInput:CaptureFocus()
            CmdInput.CursorPosition = #CmdInput.Text + 1
        end)
        btn.MouseEnter:Connect(function() Tween(btn,TF,{BackgroundColor3=C.AcctDk}) end)
        btn.MouseLeave:Connect(function() Tween(btn,TF,{BackgroundColor3=C.CardLt}) end)
    end
    Tween(SugBox, TM, {Size = UDim2.new(1,0,0,shown*(ROW+3)+10)})
end

CmdInput:GetPropertyChangedSignal("Text"):Connect(function()
    BuildSuggs(CmdInput.Text:match("^(%S*)"))
end)

CmdInput.FocusLost:Connect(function(enter)
    if not CmdOpen then return end  -- ignore spurious focus loss on startup
    local t = CmdInput.Text:match("^%s*(.-)%s*$")
    CmdInput.Text = ""
    ClearSuggs()
    Dimmer.Visible   = false
    CmdFrame.Visible = false
    CmdOpen          = false
    if enter and t ~= "" then ExecCmd(t) end
end)

-- Click outside (on dimmer) closes the bar
Dimmer.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
    or inp.UserInputType == Enum.UserInputType.Touch then
        CloseCmd()
    end
end)

local function OpenCmd()
    CmdOpen = true
    Dimmer.Visible    = true
    CmdFrame.Visible  = true
    CmdFrame.Position = UDim2.new(0.5,0,0.3,0)
    Tween(CmdFrame, TS, {Position = UDim2.new(0.5,0,0.37,0)})
    task.wait(0.06)
    CmdInput:CaptureFocus()
end

local function CloseCmd()
    CmdOpen = false
    Tween(CmdFrame, TSI, {Position = UDim2.new(0.5,0,0.3,0)})
    ClearSuggs()
    task.delay(0.32, function()
        CmdFrame.Visible = false
        Dimmer.Visible   = false
    end)
    CmdInput.Text = ""
end

UserInputService.InputBegan:Connect(function(inp, gpe)
    if gpe then return end
    local char = inp.KeyCode == Enum.KeyCode.Semicolon and ";"
              or inp.KeyCode == Enum.KeyCode.Slash      and "/"
              or inp.KeyCode == Enum.KeyCode.Minus      and "-"
              or inp.KeyCode == Enum.KeyCode.Period     and "."
              or nil
    if char and char == Config.Prefix and not CmdOpen then
        OpenCmd()
    elseif inp.KeyCode == Enum.KeyCode.Escape and CmdOpen then
        CloseCmd()
    elseif inp.KeyCode == Enum.KeyCode.Tab and CmdOpen then
        for _, ch in ipairs(SugBox:GetChildren()) do
            if ch:IsA("TextButton") then
                for _, lbl in ipairs(ch:GetChildren()) do
                    if lbl:IsA("TextLabel") and lbl.Font == Enum.Font.GothamBold then
                        local name = lbl.Text:gsub("%s**",""):match("^%s*(.-)%s*$")
                        CmdInput.Text = name .. " "
                        CmdInput:CaptureFocus()
                        CmdInput.CursorPosition = #CmdInput.Text + 1
                        break
                    end
                end
                break
            end
        end
    end
end)

-- ═══════════════════════════════════════════════════════════
-- ═══════════════════════════════════════════════════════════
-- EXPORT  — share everything with detection / commands / gui
-- ═══════════════════════════════════════════════════════════
getgenv()._VC = {
    -- services
    LP=LP, Players=Players, RunService=RunService,
    UserInputService=UserInputService, TweenService=TweenService,
    MarketplaceService=MarketplaceService, Stats=Stats, Debris=Debris,
    Camera=Camera,
    -- whitelist
    freeIds=freeIds, premIds=premIds, IsPremium=IsPremium,
    -- config
    Config=Config,
    -- gui parent + screen
    GuiParent=GuiParent, Screen=Screen,
    -- theme
    C=C, TF=TF, TM=TM, TS=TS, TSI=TSI,
    -- ui helpers
    N=N, Tween=Tween, Corner=Corner, Stroke=Stroke, Pad=Pad,
    -- utils
    FindPlayer=FindPlayer, PStr=PStr, Notify=Notify,
    -- registry
    Reg=Reg, Registry=Registry, ExecCmd=ExecCmd, RefreshActive=RefreshActive,
    -- hud
    PrefLbl=PrefLbl,
}

-- STARTUP
-- ═══════════════════════════════════════════════════════════
task.spawn(function()
    task.wait(1.5)
    Notify("Void Center","Online  v"..Config.Version,"success",5)
    task.wait(1.1)
    Notify(
        " Welcome" .. (IsPremium() and "  *" or ""),
        "Hello, "..LP.DisplayName.." (@"..LP.Name..")"
            .. (IsPremium() and "\nPremium active - troll commands unlocked." or ""),
        IsPremium() and "gold" or "info", 5
    )
    task.wait(1.1)
    Notify(" P2P System","Commands work on FREE users who also run VoidCenter\nTags appear above all VoidCenter users automatically","info",7)
    task.wait(1.5)
    Notify(" Tip","Press '"..Config.Prefix.."' to open the command bar","info",5)
end)

print("[VoidCenter v"..Config.Version.."] "..LP.Name..(IsPremium() and " [PREMIUM]" or " [FREE]").." | Loaded")

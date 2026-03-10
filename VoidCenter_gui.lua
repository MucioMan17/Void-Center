-- ── VoidCenter: GUI / Settings module ───────────────────────
local _VC = getgenv()._VC
local LP            = _VC.LP
local C             = _VC.C
local TF            = _VC.TF
local TM            = _VC.TM
local TS            = _VC.TS
local TSI           = _VC.TSI
local N             = _VC.N
local Tween         = _VC.Tween
local Corner        = _VC.Corner
local Stroke        = _VC.Stroke
local Pad           = _VC.Pad
local Config        = _VC.Config
local IsPremium     = _VC.IsPremium
local Notify        = _VC.Notify
local Reg           = _VC.Reg
local RefreshActive = _VC.RefreshActive
local Screen        = _VC.Screen
local PrefLbl       = _VC.PrefLbl

-- SETTINGS UI
-- ═══════════════════════════════════════════════════════════
local SettOpen = false

local SettBG = N("Frame", {
    BackgroundColor3 = C.Black, BackgroundTransparency = 0.45,
    BorderSizePixel = 0, Size = UDim2.new(1,0,1,0), ZIndex = 340, Visible = false,
    Active = true,
}, Screen)

local SettFrame = N("Frame", {
    AnchorPoint = Vector2.new(0.5,0.5),
    BackgroundColor3 = Color3.fromRGB(10,3,22), BorderSizePixel = 0,
    Position = UDim2.new(0.5,0,0.5,0),
    Size = UDim2.new(0,460,0,0), ZIndex = 350, ClipsDescendants = true,
}, SettBG)
Corner(16, SettFrame)
Stroke(C.Accent, 1.5, SettFrame)

-- Header
local SHdr = N("Frame", {
    BackgroundColor3 = Color3.fromRGB(18,6,36), BorderSizePixel = 0,
    Size = UDim2.new(1,0,0,50), ZIndex = 351,
}, SettFrame)
Corner(16, SHdr)
-- Bottom fill to square off header corners against body
N("Frame", {BackgroundColor3=Color3.fromRGB(18,6,36),BorderSizePixel=0,
    Position=UDim2.new(0,0,0.5,0),Size=UDim2.new(1,0,0.5,0),ZIndex=351},SHdr)

N("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.new(0,16,0,0), Size = UDim2.new(0.75,0,1,0),
    Font = Enum.Font.GothamBold, Text = "VOID CENTER  --  SETTINGS",
    TextColor3 = C.AcctBr, TextSize = 14,
    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 352,
}, SHdr)

local SClose = N("TextButton", {
    BackgroundColor3 = Color3.fromRGB(70,0,120), BorderSizePixel = 0,
    AnchorPoint = Vector2.new(1,0.5),
    Position = UDim2.new(1,-14,0.5,0), Size = UDim2.new(0,26,0,26),
    Font = Enum.Font.GothamBold, Text = "X",
    TextColor3 = C.Text, TextSize = 12, ZIndex = 352,
}, SHdr)
Corner(7, SClose)

-- Scrollable body
local SScroll = N("ScrollingFrame", {
    BackgroundTransparency = 1,
    Position = UDim2.new(0,0,0,50), Size = UDim2.new(1,0,1,-50),
    ScrollBarThickness = 3, ScrollBarImageColor3 = C.Accent,
    CanvasSize = UDim2.new(0,0,0,0), ZIndex = 351,
}, SettFrame)
local SList = N("UIListLayout", {
    SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0,6),
}, SScroll)
Pad(14,14,14,14,SScroll)
SList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    SScroll.CanvasSize = UDim2.new(0,0,0,SList.AbsoluteContentSize.Y+28)
end)

local so = 0

local function SSection(txt)
    so = so + 1
    local f = N("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,24),LayoutOrder=so},SScroll)
    N("TextLabel",{
        BackgroundTransparency=1,Size=UDim2.new(1,0,1,0),
        Font=Enum.Font.GothamBold,
        Text=txt:upper(),
        TextColor3=C.AcctBr,TextSize=10,
        TextXAlignment=Enum.TextXAlignment.Left,
    },f)
    -- Thin line under section header
    N("Frame",{
        BackgroundColor3=C.Accent,BackgroundTransparency=0.7,BorderSizePixel=0,
        Position=UDim2.new(0,0,1,-1),Size=UDim2.new(1,0,0,1),
    },f)
end

local function SRow(label, sublabel, val, onSave)
    so = so + 1
    local row = N("Frame", {
        BackgroundColor3 = Color3.fromRGB(18,8,34), BorderSizePixel = 0,
        Size = UDim2.new(1,0,0,54), LayoutOrder = so,
    }, SScroll)
    Corner(10, row)
    Stroke(Color3.fromRGB(50,30,80), 1, row)
    N("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0,14,0,8), Size = UDim2.new(0.55,0,0,20),
        Font = Enum.Font.GothamBold, Text = label,
        TextColor3 = C.Text, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    if sublabel and sublabel ~= "" then
        N("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.new(0,14,0,28), Size = UDim2.new(0.55,0,0,16),
            Font = Enum.Font.Gotham, Text = sublabel,
            TextColor3 = Color3.fromRGB(120,100,160), TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, row)
    end
    local tb = N("TextBox", {
        BackgroundColor3 = Color3.fromRGB(8,2,18), BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1,0.5),
        Position = UDim2.new(1,-12,0.5,0), Size = UDim2.new(0,90,0,30),
        Font = Enum.Font.GothamBold, Text = tostring(val),
        TextColor3 = C.AcctBr, TextSize = 14,
        PlaceholderText = "...", PlaceholderColor3 = C.AcctDk,
        ZIndex = 2,
    }, row)
    Corner(8, tb)
    Stroke(C.AcctDk, 1, tb)
    tb.FocusLost:Connect(function() onSave(tb.Text:match("^%s*(.-)%s*$")) end)
end

-- ── Settings rows ─────────────────────────────────────────────
SSection("Controls")
SRow("Command Bar Key",       "Single character prefix  (default: ;)", Config.Prefix, function(v)
    if #v == 1 then
        Config.Prefix = v
        PrefLbl.Text  = v
        Notify("Settings","Command bar key set to '"..v.."'","success")
    else
        Notify("Settings","Must be a single character","error")
    end
end)

SSection("Movement")
SRow("Fly Speed",             "Studs per second  (default: 50)",  Config.FlySpeed, function(v)
    local n = tonumber(v)
    if n and n > 0 then Config.FlySpeed = n Notify("Settings","Fly speed -> "..n,"success")
    else Notify("Settings","Enter a valid number","error") end
end)
SRow("Walk Speed",            "Default walk speed  (default: 16)", 16, function(v)
    local n = tonumber(v)
    if n and n > 0 then
        local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        if h then h.WalkSpeed = n end
        Notify("Settings","Walk speed -> "..n,"success")
    else Notify("Settings","Enter a valid number","error") end
end)
SRow("Jump Power",            "Default jump power  (default: 50)", 50, function(v)
    local n = tonumber(v)
    if n and n > 0 then
        local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        if h then h.JumpPower = n end
        Notify("Settings","Jump power -> "..n,"success")
    else Notify("Settings","Enter a valid number","error") end
end)

local function OpenSettings()
    SettOpen = true
    SettBG.Visible = true
    SettFrame.Size = UDim2.new(0,460,0,0)
    Tween(SettFrame, TS, {Size = UDim2.new(0,460,0,380)})
end
local function CloseSettings()
    SettOpen = false
    Tween(SettFrame, TSI, {Size = UDim2.new(0,460,0,0)})
    task.delay(0.35, function() SettBG.Visible = false end)
end

SClose.MouseButton1Click:Connect(CloseSettings)
SettBG.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 then CloseSettings() end
end)

Reg("settings", {"set","options"}, "Open the settings menu", false, OpenSettings)

-- ═══════════════════════════════════════════════════════════
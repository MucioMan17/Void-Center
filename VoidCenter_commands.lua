-- ── VoidCenter: Commands module ──────────────────────────────
local _VC = getgenv()._VC
local LP               = _VC.LP
local Players          = _VC.Players
local RunService       = _VC.RunService
local UserInputService = _VC.UserInputService
local TweenService     = _VC.TweenService
local MarketplaceService = _VC.MarketplaceService
local Debris           = _VC.Debris
local Camera           = _VC.Camera
local C                = _VC.C
local TF               = _VC.TF
local TM               = _VC.TM
local N                = _VC.N
local Tween            = _VC.Tween
local Corner           = _VC.Corner
local Stroke           = _VC.Stroke
local Pad              = _VC.Pad
local Config           = _VC.Config
local IsPremium        = _VC.IsPremium
local freeIds          = _VC.freeIds
local premIds          = _VC.premIds
local Notify           = _VC.Notify
local FindPlayer       = _VC.FindPlayer
local PStr             = _VC.PStr
local Reg              = _VC.Reg
local RefreshActive    = _VC.RefreshActive
local Screen           = _VC.Screen
-- From detection module
local vcUsers          = _VC.vcUsers
local IsVoidUser       = _VC.IsVoidUser
local IsWhitelisted    = _VC.IsWhitelisted
local SendSig          = _VC.SendSig

-- FLY
-- ═══════════════════════════════════════════════════════════
local flyOn = false
local flyBV, flyBG, flyConn

local function StopFly()
    if not flyOn then return end
    flyOn = false
    Config.ActiveCmds["Fly"] = nil
    RefreshActive()
    if flyConn then flyConn:Disconnect() flyConn = nil end
    pcall(function() if flyBV then flyBV:Destroy() end end) flyBV = nil
    pcall(function() if flyBG then flyBG:Destroy() end end) flyBG = nil
    local c = LP.Character
    if c then
        local h = c:FindFirstChildOfClass("Humanoid")
        if h then h.PlatformStand = false end
    end
    Notify("Fly", "Landed", "info")
end

local function StartFly()
    if flyOn then StopFly() return end
    local c    = LP.Character
    local root = c and c:FindFirstChild("HumanoidRootPart")
    local hum  = c and c:FindFirstChildOfClass("Humanoid")
    if not root or not hum then Notify("Fly","No character","error") return end

    flyOn = true
    Config.ActiveCmds["Fly"] = true
    RefreshActive()
    hum.PlatformStand = true

    flyBV            = Instance.new("BodyVelocity")
    flyBV.MaxForce   = Vector3.new(1e9,1e9,1e9)
    flyBV.Velocity   = Vector3.zero
    flyBV.Parent     = root

    flyBG            = Instance.new("BodyGyro")
    flyBG.MaxTorque  = Vector3.new(1e9,1e9,1e9)
    flyBG.P          = 1e5
    flyBG.D          = 100
    flyBG.CFrame     = root.CFrame
    flyBG.Parent     = root

    flyConn = RunService.Heartbeat:Connect(function()
        if not flyOn then return end
        local chr  = LP.Character
        if not chr then return end
        local rt   = chr:FindFirstChild("HumanoidRootPart")
        if not rt or not flyBV or not flyBV.Parent then return end

        local spd   = Config.FlySpeed
        local camCF = Camera.CFrame
        local look  = camCF.LookVector      -- includes vertical tilt
        local right = camCF.RightVector
        local up    = Vector3.new(0, 1, 0)
        local dir   = Vector3.zero

        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + look  end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - look  end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - right end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + right end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space)       then dir = dir + up end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
        or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)   then dir = dir - up end
        if UserInputService:IsKeyDown(Enum.KeyCode.E)           then spd = spd * 2.8 end

        flyBV.Velocity = dir.Magnitude > 0 and (dir.Unit * spd) or Vector3.zero

        -- Yaw-only rotation: extract horizontal camera angle and apply to BodyGyro.
        -- Using atan2 gives a clean angle without any vertical tilt bleeding in.
        local yaw = math.atan2(-look.X, -look.Z)
        flyBG.CFrame = CFrame.fromEulerAnglesYXZ(0, yaw, 0)
    end)
    Notify("Fly","WASD - Space/Ctrl up-down - E=boost - fly again to land","success")
end

Reg("fly",      {"f"},  "Toggle fly (WASD - Space/Ctrl - E=boost)", false, function() StartFly() end)
Reg("flyspeed", {"fs"}, "Set fly speed  e.g. flyspeed 80", false, function(a)
    local n = tonumber(a[1])
    if n and n > 0 then Config.FlySpeed = n Notify("Fly","Speed -> "..n,"success")
    else Notify("Fly","Usage: flyspeed <number>","warning") end
end)

-- ═══════════════════════════════════════════════════════════
-- NOCLIP
-- ═══════════════════════════════════════════════════════════
local ncOn   = false
local ncConn

local function StopNoclip()
    if not ncOn then return end
    ncOn = false
    Config.ActiveCmds["Noclip"] = nil
    RefreshActive()
    if ncConn then ncConn:Disconnect() ncConn = nil end
    local c = LP.Character
    if c then
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = true end
        end
    end
    Notify("Noclip","Collision restored","info")
end

local function StartNoclip()
    if ncOn then StopNoclip() return end
    ncOn = true
    Config.ActiveCmds["Noclip"] = true
    RefreshActive()
    ncConn = RunService.Stepped:Connect(function()
        if not ncOn then return end
        local c = LP.Character
        if not c then return end
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end)
    Notify("Noclip","Phase through walls - run again to stop","success")
end

Reg("noclip", {"nc"}, "Toggle noclip / phase through walls", false, function() StartNoclip() end)

-- ═══════════════════════════════════════════════════════════
-- ESP - always maintains all players, auto-updates
-- ═══════════════════════════════════════════════════════════
local espOn   = false
local espData = {}   -- [player] = { hl, bill, hconn }

local function RemoveESPFor(player)
    if espData[player] then
        pcall(function() espData[player].hl:Destroy()   end)
        pcall(function() espData[player].bill:Destroy() end)
        if espData[player].hconn then
            pcall(function() espData[player].hconn:Disconnect() end)
        end
        espData[player] = nil
    end
end

local function BuildESPFor(player)
    if player == LP then return end
    RemoveESPFor(player)

    local c    = player.Character
    local root = c and c:FindFirstChild("HumanoidRootPart")
    if not c or not root then return end

    -- Box highlight
    local hl = Instance.new("Highlight")
    hl.FillColor           = Color3.fromRGB(55,0,110)
    hl.OutlineColor        = Color3.fromRGB(160,50,255)
    hl.FillTransparency    = 0.80
    hl.OutlineTransparency = 0.0
    hl.Adornee             = c
    hl.Parent              = c

    -- Names + health billboard
    local bill = Instance.new("BillboardGui")
    bill.Name         = "VESP_"..player.Name
    bill.Size         = UDim2.new(0,200,0,68)
    bill.StudsOffset  = Vector3.new(0,3.5,0)
    bill.AlwaysOnTop  = true
    bill.Parent       = root

    N("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1,0,0,28),
        Font = Enum.Font.GothamBold,
        Text = player.DisplayName,
        TextColor3 = Color3.fromRGB(215,165,255),
        TextSize = 20,
        TextStrokeTransparency = 0.2, TextStrokeColor3 = C.Black,
    }, bill)
    N("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0,0,0,27), Size = UDim2.new(1,0,0,20),
        Font = Enum.Font.Gotham, Text = "@"..player.Name,
        TextColor3 = Color3.fromRGB(185,135,255), TextSize = 16,
        TextStrokeTransparency = 0.3, TextStrokeColor3 = C.Black,
    }, bill)

    -- Health bar
    local hbg = N("Frame", {
        BackgroundColor3 = Color3.fromRGB(18,0,36), BorderSizePixel = 0,
        Position = UDim2.new(1,6,0.06,0), Size = UDim2.new(0,5,0.88,0),
    }, bill)
    Corner(4, hbg)
    local hfill = N("Frame", {
        AnchorPoint = Vector2.new(0,1),
        BackgroundColor3 = Color3.fromRGB(120,40,255), BorderSizePixel = 0,
        Position = UDim2.new(0,0,1,0), Size = UDim2.new(1,0,1,0),
    }, hbg)
    Corner(4, hfill)

    local hum   = c:FindFirstChildOfClass("Humanoid")
    local hconn = nil
    if hum then
        local function UpdateHP(hp)
            if not espData[player] then return end
            local pct = math.clamp(hp / math.max(hum.MaxHealth,1), 0, 1)
            Tween(hfill, TF, {
                Size             = UDim2.new(1,0,pct,0),
                Position         = UDim2.new(0,0,1-pct,0),
                BackgroundColor3 = Color3.fromRGB(
                    math.floor(255*(1-pct)),
                    math.floor(180*pct),
                    math.floor(255*pct)
                ),
            })
        end
        UpdateHP(hum.Health)
        hconn = hum.HealthChanged:Connect(UpdateHP)
    end

    espData[player] = {hl = hl, bill = bill, hconn = hconn}
end

-- ── Persistent maintenance loop: checks every 1.5 s ──────
task.spawn(function()
    while true do
        task.wait(1.5)
        if not espOn then continue end
        for _, p in ipairs(Players:GetPlayers()) do
            if p == LP then continue end
            local c    = p.Character
            local root = c and c:FindFirstChild("HumanoidRootPart")

            if not c or not root then
                -- Player has no character right now, clean stale data
                RemoveESPFor(p)
            elseif not espData[p]
                or not espData[p].hl
                or not espData[p].hl.Parent
                or espData[p].hl.Adornee ~= c then
                -- New player, respawned, or stale - rebuild
                BuildESPFor(p)
            end
        end
        -- Remove entries for players who left
        for p in pairs(espData) do
            if not p or not p.Parent then
                RemoveESPFor(p)
            end
        end
    end
end)

-- Instant rebuild on character spawn
Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function()
        task.wait(1.2)
        if espOn then BuildESPFor(p) end
    end)
end)
Players.PlayerRemoving:Connect(function(p) RemoveESPFor(p) end)

for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LP then
        p.CharacterAdded:Connect(function()
            task.wait(1.2)
            if espOn then BuildESPFor(p) end
        end)
    end
end

local function EnableESP()
    espOn = true
    Config.ActiveCmds["ESP"] = true
    RefreshActive()
    for _, p in ipairs(Players:GetPlayers()) do BuildESPFor(p) end
    Notify("ESP","Tracking "..tostring(#Players:GetPlayers()-1).." player(s) - auto-updates","success")
end

local function DisableESP()
    espOn = false
    Config.ActiveCmds["ESP"] = nil
    RefreshActive()
    for p in pairs(espData) do RemoveESPFor(p) end
    Notify("ESP","Disabled","info")
end

Reg("esp", {"e"}, "Toggle ESP (box - names - health - auto-updates)", false, function()
    if espOn then DisableESP() else EnableESP() end
end)

-- ═══════════════════════════════════════════════════════════
-- PREMIUM TROLL COMMANDS  (typed in the script command bar)
-- All premium commands send a vcs_ signal to free users
-- who then execute the action locally on their own client.
-- This keeps everything client-sided and avoids chat tagging.
-- =========================================================
local frozenList = {}
local kickList   = {}

-- Helper: find a valid target (must be a free VC user)
local function PremTarget(name, label)
    local t = FindPlayer(name)
    if not t then
        Notify(label, "Not found: "..(name or "?"), "error") return nil end
    if not IsVoidUser(t) then
        Notify(label, PStr(t).." doesn't have VoidCenter", "error") return nil end
    if IsPremium(t) then
        Notify(label, "Cannot target Premium users", "warning") return nil end
    return t
end

Reg("fling",    {"fl"},          "Fling a player  e.g. fling Player1",              true, function(a)
    local t = PremTarget(a[1], "Fling") if not t then return end
    SendSig(1, t.UserId) Notify("Fling [P]", "-> "..PStr(t), "gold")
end)

Reg("bring",    {"br"},          "Bring a player to you  e.g. bring Player1",        true, function(a)
    local t = PremTarget(a[1], "Bring") if not t then return end
    SendSig(2, t.UserId) Notify("Bring [P]", "-> "..PStr(t), "gold")
end)

Reg("bringall", {"ball"},        "Bring all free VC users to you",                   true, function(a)
    local count = 0
    for p in pairs(vcUsers) do
        if p ~= LP and not IsPremium(p) then count = count + 1 end
    end
    if count == 0 then Notify("BringAll [P]", "No free VC users found", "warning") return end
    SendSig(3, 0) Notify("BringAll [P]", "Signalled "..count.." user(s)", "gold")
end)

Reg("freeze",   {"fr"},          "Freeze/unfreeze a player  e.g. freeze Player1",    true, function(a)
    local t = PremTarget(a[1], "Freeze") if not t then return end
    local wasFrozen = frozenList[t]
    frozenList[t] = not wasFrozen
    SendSig(wasFrozen and 7 or 6, t.UserId)
    Notify("Freeze [P]", "-> "..PStr(t)..(wasFrozen and " - unfrozen" or " - frozen"), "gold")
end)

Reg("premreset",{"pr"},          "Force-reset a player  e.g. premreset Player1",     true, function(a)
    local t = PremTarget(a[1], "Reset [P]") if not t then return end
    SendSig(4, t.UserId) Notify("Reset [P]", "-> "..PStr(t), "gold")
end)

Reg("kick",     {"kk"},          "Loop-kick a player  e.g. kick Player1 | kick Player1 stop", true, function(a)
    local t = PremTarget(a[1], "Kick [P]") if not t then return end
    if a[2] and a[2]:lower() == "stop" then
        kickList[t] = false SendSig(9, t.UserId)
        Notify("Kick [P]", "Stopped -> "..PStr(t), "gold") return
    end
    if kickList[t] then
        kickList[t] = false SendSig(9, t.UserId)
        Notify("Kick [P]", "Stopped -> "..PStr(t), "gold")
    else
        kickList[t] = true SendSig(8, t.UserId)
        Notify("Kick [P]", "Kicking -> "..PStr(t), "gold", 6)
    end
end)

Reg("forcechat",{"fc"},          "Make a player chat  e.g. forcechat Player1 hello", true, function(a)
    local t = PremTarget(a[1], "ForcChat [P]") if not t then return end
    if #a < 2 then Notify("ForceChat [P]", "Usage: forcechat <player> <message>", "warning") return end
    local words = {} for i = 2, #a do table.insert(words, a[i]) end
    local msg = table.concat(words, " ")
    SendSig(13, t.UserId, msg)
    Notify("ForceChat [P]", '-> '..PStr(t)..' : "'..msg..'"', "gold")
end)

-- LP.Chatted is still used to receive vcs_ signals from others (read-only — we don't parse dot-commands)
LP.Chatted:Connect(function(msg)
    -- Only parse vcs_ signals, not premium commands (those go through command bar now)
    if msg:sub(1, #VC_PFX + 1) == VC_PFX.."_" then
        task.spawn(function()
            -- Parse and handle the signal
            local withoutPfx = msg:sub(#VC_PFX + 2)
            local parts = {}
            for w in withoutPfx:gmatch("%S+") do table.insert(parts, w) end
            -- Already handled by the Players.Chatted hook in the signal section above
        end)
    end
end)

end)

-- ═══════════════════════════════════════════════════════════
-- FREE UTILITY COMMANDS
-- ═══════════════════════════════════════════════════════════
Reg("goto", {"tp","go"}, "Teleport to player  e.g. goto Player1 or goto DisplayName", false, function(a)
    local t = FindPlayer(a[1])
    if not t then Notify("Goto","Not found: "..(a[1] or "?"),"error") return end
    local mr = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    local tr = t.Character  and t.Character:FindFirstChild("HumanoidRootPart")
    if mr and tr then
        mr.CFrame = tr.CFrame + Vector3.new(3,0,0)
        Notify("Goto","--> "..PStr(t),"success")
    else
        Notify("Goto","Target has no character","error")
    end
end)

Reg("walkspeed", {"ws","speed"}, "Set your walk speed  e.g. walkspeed 30", false, function(a)
    local n = tonumber(a[1]) or 16
    local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if h then h.WalkSpeed = n Notify("WalkSpeed","Speed -> "..n,"success") end
end)

Reg("jumppower", {"jp"}, "Set your jump power  e.g. jumppower 80", false, function(a)
    local n = tonumber(a[1]) or 50
    local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if h then h.JumpPower = n Notify("JumpPower","Power -> "..n,"success") end
end)

Reg("resetstats", {"rss"}, "Reset your speed and jump to default", false, function()
    local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if h then
        h.WalkSpeed = 16
        h.JumpPower = 50
        Notify(" ResetStats","Speed & jump reset to default","info")
    end
end)

-- Safe platform - built once, shared between all VC users who use the command
local safePlatform = nil
local SAFE_POS     = Vector3.new(0, 5000, 0)

local function BuildSafePlatform()
    -- Check if it already exists in Workspace
    local existing = workspace:FindFirstChild("VoidSafePlatform")
    if existing then safePlatform = existing return end

    local model = Instance.new("Model")
    model.Name = "VoidSafePlatform"

    -- Main floor - large purple platform
    local floor = Instance.new("Part")
    floor.Name          = "Floor"
    floor.Size          = Vector3.new(60, 2, 60)
    floor.Position      = SAFE_POS
    floor.Anchored      = true
    floor.CanCollide    = true
    floor.Material      = Enum.Material.SmoothPlastic
    floor.Color         = Color3.fromRGB(80, 0, 120)    -- deep purple
    floor.Parent        = model

    -- Black border trim around edge
    local border = Instance.new("Part")
    border.Name       = "Border"
    border.Size       = Vector3.new(64, 1, 64)
    border.Position   = SAFE_POS - Vector3.new(0, 0.5, 0)
    border.Anchored   = true
    border.CanCollide = false
    border.Material   = Enum.Material.SmoothPlastic
    border.Color      = Color3.fromRGB(10, 0, 20)       -- near black
    border.Parent     = model

    -- Glowing purple surface light
    local light = Instance.new("SurfaceLight")
    light.Brightness = 3
    light.Color      = Color3.fromRGB(150, 0, 255)
    light.Range      = 40
    light.Face       = Enum.NormalId.Top
    light.Parent     = floor

    -- Small sign
    local sign = Instance.new("Part")
    sign.Name     = "Sign"
    sign.Size     = Vector3.new(8, 3, 0.5)
    sign.Position = SAFE_POS + Vector3.new(0, 2.5, -28)
    sign.Anchored = true
    sign.CanCollide = false
    sign.Material = Enum.Material.SmoothPlastic
    sign.Color    = Color3.fromRGB(30, 0, 60)
    sign.Parent   = model

    local sg = Instance.new("SurfaceGui")
    sg.Face   = Enum.NormalId.Front
    sg.Parent = sign
    local lbl = Instance.new("TextLabel")
    lbl.Size                 = UDim2.new(1,0,1,0)
    lbl.BackgroundColor3     = Color3.fromRGB(30,0,60)
    lbl.TextColor3           = Color3.fromRGB(200,100,255)
    lbl.Font                 = Enum.Font.GothamBold
    lbl.Text                 = "  VoidCenter Safe Zone  "
    lbl.TextScaled           = true
    lbl.Parent               = sg

    model.Parent    = workspace
    model.PrimaryPart = floor
    safePlatform    = model
end

Reg("safe", {"sz"}, "Teleport to the VoidCenter safe platform high above the map", false, function()
    BuildSafePlatform()
    local r = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if r then
        r.CFrame = CFrame.new(SAFE_POS + Vector3.new(math.random(-20,20), 4, math.random(-20,20)))
        Notify(" Safe Zone","Welcome to the VoidCenter safe platform! Type 'safe' to return here anytime","success",5)
    end
end)

Reg("reset", {"rme","r"}, "Reset your own character", false, function()
    local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if h then
        h.Health = 0
        Notify("Reset","Resetting your character...","info",2)
    end
end)

Reg("antiafk", {"aafk"}, "Toggle anti-AFK (prevents auto-kick)", false, function()
    if Config.ActiveCmds["AntiAFK"] then
        Config.ActiveCmds["AntiAFK"] = nil
        RefreshActive()
        Notify("Anti-AFK","Disabled","info")
    else
        Config.ActiveCmds["AntiAFK"] = true
        RefreshActive()
        Notify("Anti-AFK","Enabled - you will not be kicked for AFK","success")
        task.spawn(function()
            local VirtualUser = game:GetService("VirtualUser")
            while Config.ActiveCmds["AntiAFK"] do
                task.wait(60)
                if Config.ActiveCmds["AntiAFK"] then
                    pcall(function() VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame) end)
                    task.wait(1)
                    pcall(function() VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame) end)
                end
            end
        end)
    end
end)

local aflConn  -- stored so we can disconnect cleanly
Reg("antifling", {"afl"}, "Toggle anti-fling - others phase through you", false, function()
    if Config.ActiveCmds["AntiFling"] then
        -- TURN OFF
        Config.ActiveCmds["AntiFling"] = nil
        if aflConn then aflConn:Disconnect() aflConn = nil end
        RefreshActive()
        -- Only restore CanCollide if noclip is NOT also running
        -- (noclip manages its own CanCollide via its own connection)
        if not ncOn then
            pcall(function()
                local chr = LP.Character
                if chr then
                    for _, p in ipairs(chr:GetDescendants()) do
                        if p:IsA("BasePart") then p.CanCollide = true end
                    end
                end
            end)
        end
        Notify("Anti-Fling", "Disabled", "info")
    else
        -- TURN ON - use RunService.Stepped (same as noclip) for consistency
        Config.ActiveCmds["AntiFling"] = true
        RefreshActive()
        Notify("Anti-Fling", "Enabled - players phase through you", "success")
        aflConn = RunService.Stepped:Connect(function()
            pcall(function()
                local chr = LP.Character
                if not chr then return end
                for _, p in ipairs(chr:GetDescendants()) do
                    -- Disable collision on ALL parts including HRP -
                    -- HRP is the handle exploiters grab to fling you
                    if p:IsA("BasePart") then
                        p.CanCollide = false
                    end
                end
            end)
        end)
    end
end)

Reg("antivoid", {"av"}, "Toggle anti-void protection", false, function()
    if Config.ActiveCmds["AntiVoid"] then
        Config.ActiveCmds["AntiVoid"] = nil
        RefreshActive()
        Notify("Anti-Void", "Disabled", "info")
    else
        Config.ActiveCmds["AntiVoid"] = true
        RefreshActive()

        -- Read the game's actual void kill height. Every Roblox game has this property.
        -- We trigger 30 studs above it so we always save before the void kills us.
        local voidKillY = -500
        pcall(function()
            voidKillY = workspace.FallenPartsDestroyHeight
        end)
        local triggerY = voidKillY + 30   -- save 30 studs before death line

        -- Where to teleport back to: record a safe Y on the ground when enabled.
        local safeY = 100
        pcall(function()
            local chr = LP.Character
            local r   = chr and chr:FindFirstChild("HumanoidRootPart")
            if r then safeY = math.max(r.Position.Y + 10, 10) end
        end)

        Notify("Anti-Void", "Enabled  (trigger: Y < "..math.floor(triggerY)..")", "success")

        local cooldown = false
        task.spawn(function()
            while Config.ActiveCmds["AntiVoid"] do
                task.wait(0.04)
                pcall(function()
                    local chr = LP.Character
                    local r   = chr and chr:FindFirstChild("HumanoidRootPart")
                    local h   = chr and chr:FindFirstChildOfClass("Humanoid")
                    if not r or not h or cooldown then return end
                    if h.Health <= 0 then return end
                    if r.Position.Y < triggerY then
                        cooldown  = true
                        h.Health  = h.MaxHealth
                        r.CFrame  = CFrame.new(r.Position.X, safeY, r.Position.Z)
                        Notify("Anti-Void", "Saved!", "success", 3)
                        task.wait(1.5)
                        cooldown = false
                        -- Update safeY after each save in case map has changed
                        pcall(function()
                            local chr2 = LP.Character
                            local r2 = chr2 and chr2:FindFirstChild("HumanoidRootPart")
                            if r2 then safeY = math.max(r2.Position.Y + 10, 10) end
                        end)
                    end
                end)
            end
        end)
    end
end)

Reg("spectate", {"spec","view"}, "Spectate a player  e.g. spectate Player1 | spectate stop", false, function(a)
    if not a[1] or a[1]:lower() == "stop" then
        -- Exit spectate: restore camera
        local cam = workspace.CurrentCamera
        cam.CameraType = Enum.CameraType.Custom
        cam.CameraSubject = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        Config.ActiveCmds["Spectating"] = nil
        RefreshActive()
        Notify("Spectate","Camera restored","info",3)
        return
    end
    local t = FindPlayer(a[1])
    if not t then Notify("Spectate","Player not found: "..(a[1] or "?"),"error") return end
    if t == LP then Notify("Spectate","Can't spectate yourself","warning") return end
    local th = t.Character and t.Character:FindFirstChildOfClass("Humanoid")
    if not th then Notify("Spectate",PStr(t).." has no character","error") return end
    local cam = workspace.CurrentCamera
    cam.CameraType    = Enum.CameraType.Custom
    cam.CameraSubject = th
    Config.ActiveCmds["Spectating"] = true
    RefreshActive()
    Notify("Spectate","Now viewing "..PStr(t).."\nType 'spectate stop' to exit","success",4)
    -- Auto-follow if they respawn
    t.CharacterAdded:Connect(function(char)
        if not Config.ActiveCmds["Spectating"] then return end
        task.wait(0.5)
        local newHum = char:FindFirstChildOfClass("Humanoid")
        if newHum then cam.CameraSubject = newHum end
    end)
end)

Reg("rejoin", {"rj"}, "Rejoin the current game", false, function()
    game:GetService("TeleportService"):Teleport(game.PlaceId, LP)
end)

Reg("help", {"cmds","commands"}, "List all commands", false, function()
    Notify("Free Commands",
        "fly / flyspeed / noclip / esp / goto / safe / reset\nwalkspeed / jumppower / antiafk / antifling / antivoid / spectate / rejoin",
        "info", 8)
    task.wait(0.6)
    if IsPremium() then
        Notify("Premium Commands [P]",
            "fling / bring / bringall / freeze / premreset / kick / forcechat\nType these in the command bar like any other command.",
            "gold", 8)
        task.wait(0.6)
        Notify("How It Works [P]",
            "Premium commands send signals to free users who carry out the action on their client. Targets must have VoidCenter running.",
            "gold", 8)
    else
        Notify("Premium",
            "Get whitelisted for Premium to unlock troll commands.",
            "gold", 7)
    end
end)

-- ═══════════════════════════════════════════════════════════
-- RESPAWN - restore all active features
-- ═══════════════════════════════════════════════════════════
LP.CharacterAdded:Connect(function()
    task.wait(1)
    if flyOn  then flyOn  = false task.wait(0.2) StartFly()     end
    if ncOn   then ncOn   = false task.wait(0.1) StartNoclip()  end
    if espOn  then
        task.wait(1.2)
        for _, p in ipairs(Players:GetPlayers()) do BuildESPFor(p) end
    end
end)

-- ═══════════════════════════════════════════════════════════
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

-- FLY
-- ═══════════════════════════════════════════════════════════
local flyOn   = false
local flyBV   = nil
local flyBG   = nil
local flyConn = nil

local function StopFly()
    if not flyOn then return end
    flyOn = false
    Config.ActiveCmds["Fly"] = nil
    RefreshActive()
    if flyConn then flyConn:Disconnect() flyConn = nil end
    pcall(function() if flyBV and flyBV.Parent then flyBV:Destroy() end end) flyBV = nil
    pcall(function() if flyBG and flyBG.Parent then flyBG:Destroy() end end) flyBG = nil
    pcall(function()
        local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.PlatformStand = false end
    end)
    Notify("Fly", "Landed", "info")
end

local function StartFly()
    if flyOn then StopFly() return end
    local c    = LP.Character
    local root = c and c:FindFirstChild("HumanoidRootPart")
    local hum  = c and c:FindFirstChildOfClass("Humanoid")
    if not root or not hum then Notify("Fly", "No character", "error") return end

    flyOn = true
    Config.ActiveCmds["Fly"] = true
    RefreshActive()
    hum.PlatformStand = true

    -- BodyGyro locks your character's rotation to the camera
    flyBG             = Instance.new("BodyGyro", root)
    flyBG.P           = 9e4
    flyBG.MaxTorque   = Vector3.new(9e9, 9e9, 9e9)
    flyBG.CFrame      = root.CFrame

    -- BodyVelocity moves you in the direction you're looking
    flyBV             = Instance.new("BodyVelocity", root)
    flyBV.MaxForce    = Vector3.new(9e9, 9e9, 9e9)
    flyBV.Velocity    = Vector3.zero

    flyConn = RunService.RenderStepped:Connect(function()
        local chr = LP.Character
        if not chr then return end
        local rt  = chr:FindFirstChild("HumanoidRootPart")
        if not rt or not flyBV or not flyBV.Parent then return end

        local cam   = workspace.CurrentCamera
        local speed = Config.FlySpeed
        local move  = Vector3.zero

        if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + cam.CFrame.LookVector  end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - cam.CFrame.LookVector  end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move - cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space)
        or UserInputService:IsKeyDown(Enum.KeyCode.ButtonA) then
            move = move + Vector3.new(0, 1, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
        or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
            move = move - Vector3.new(0, 1, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.E) then speed = speed * 2.5 end

        flyBV.Velocity = move.Magnitude > 0 and move.Unit * speed or Vector3.zero
        flyBG.CFrame   = cam.CFrame  -- character faces where you look
    end)

    Notify("Fly", "WASD to move  Space/Ctrl up-down  E to boost  fly again to land", "success")
end

Reg("fly",      {"f"},  "Toggle fly", false, function() StartFly() end)
Reg("flyspeed", {"fs"}, "Set fly speed  e.g. flyspeed 80", false, function(a)
    local n = tonumber(a[1])
    if n and n > 0 then
        Config.FlySpeed = n
        Notify("Fly", "Speed set to " .. n, "success")
    else
        Notify("Fly", "Usage: flyspeed <number>", "warning")
    end
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
                RemoveESPFor(p)
            elseif not espData[p]
                or not espData[p].hl
                or not espData[p].hl.Parent
                or espData[p].hl.Adornee ~= c then
                task.spawn(BuildESPFor, p)
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
    -- Spawn each build separately so instance creation doesn't freeze the game
    for _, p in ipairs(Players:GetPlayers()) do
        task.spawn(BuildESPFor, p)
    end
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
-- PREMIUM COMMANDS  (type directly in Roblox chat)
-- ─────────────────────────────────────────────────────────
-- Premium users just type .fling Player1 in chat.
-- The target's script sees it and executes locally.
-- No signals, no encoding, no suppression needed.
--
-- Available commands:
--   .fling <player>
--   .bring <player>
--   .bringall
--   .freeze <player>
--   .unfreeze <player>
--   .kill <player>
--   .kick <player>
--   .unkick <player>
--   .chat <player> <message>
-- ═══════════════════════════════════════════════════════════

-- Notify premium user that the command was typed
-- (the actual execution happens on the target's client via detection.lua)
Reg("prem",  {"premium","pcmds"}, "List premium dot-commands (type in Roblox chat)", true, function()
    Notify("Premium Commands",
        ".fling .bring .bringall .freeze .unfreeze .kill .kick .unkick .chat",
        "gold", 8)
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

local safeReturnCF = nil  -- stores position before going to safe zone

Reg("safe", {"sz"}, "Teleport to safe platform  |  type again to return", false, function()
    local r = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not r then return end

    local atSafe = math.abs(r.Position.Y - SAFE_POS.Y) < 200

    if atSafe and safeReturnCF then
        -- Already at safe zone — teleport back to where we came from
        r.CFrame = safeReturnCF
        safeReturnCF = nil
        Notify("Safe Zone", "Returned to previous location", "info", 3)
    else
        -- Save current position then go to safe zone
        safeReturnCF = r.CFrame
        BuildSafePlatform()
        r.CFrame = CFrame.new(SAFE_POS + Vector3.new(math.random(-20,20), 4, math.random(-20,20)))
        Notify("Safe Zone", "At safe platform  |  type 'safe' again to return", "success", 4)
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
    Notify("Utility",
        "fly / flyspeed / noclip / esp / goto / safe / reset\nwalkspeed / jumppower / resetstats / rejoin / spectate",
        "info", 8)
    task.wait(0.5)
    Notify("Visual",
        "trail / rainbow / ghost / invisible / bighead / nametag",
        "info", 8)
    task.wait(0.5)
    Notify("Combat & Tools",
        "hitbox / reach / zoom / thirdperson / hat / unequip",
        "info", 8)
    task.wait(0.5)
    Notify("Info",
        "find / players / copyfit / antiafk / antifling / antivoid",
        "info", 8)
    task.wait(0.5)
    if IsPremium() then
        Notify("Premium [P]  (type in Roblox chat)",
            ".fling .bring .bringall .freeze .unfreeze\n.kill .kick .unkick .spin .explode\n.follow .unfollow .tp2me .untp2me .chat",
            "gold", 10)
    else
        Notify("Premium",
            "Get whitelisted for Premium to unlock troll commands.",
            "gold", 6)
    end
end)


-- ═══════════════════════════════════════════════════════════
-- NEW COMMANDS
-- ═══════════════════════════════════════════════════════════

-- ── NAMETAG ───────────────────────────────────────────────
local nametagBill = nil
Reg("nametag", {"nt"}, "Set a custom tag above your head  e.g. nametag cool guy | nametag off", false, function(a)
    if nametagBill then pcall(function() nametagBill:Destroy() end) nametagBill = nil end
    local text = table.concat(a, " ")
    if text == "" or text:lower() == "off" then
        Notify("Nametag", "Removed", "info") return
    end
    local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not root then Notify("Nametag", "No character", "error") return end
    local bill = Instance.new("BillboardGui")
    bill.Size = UDim2.new(0, 200, 0, 30)
    bill.StudsOffsetWorldSpace = Vector3.new(0, 3.5, 0)
    bill.AlwaysOnTop = true
    bill.LightInfluence = 0
    bill.MaxDistance = 0
    bill.Parent = root
    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1,0,1,0)
    lbl.Font = Enum.Font.GothamBold
    lbl.Text = text
    lbl.TextColor3 = C.AcctBr
    lbl.TextSize = 14
    lbl.TextStrokeTransparency = 0.3
    lbl.TextStrokeColor3 = Color3.fromRGB(0,0,0)
    lbl.Parent = bill
    nametagBill = bill
    -- Rebuild on respawn
    LP.CharacterAdded:Connect(function(char)
        if not nametagBill then return end
        task.wait(1)
        local r2 = char:FindFirstChild("HumanoidRootPart")
        if r2 then bill.Parent = r2 end
    end)
    Notify("Nametag", "Set to: "..text, "success")
end)

-- ── HITBOX ────────────────────────────────────────────────
local hitboxOn = false
local hitboxConn = nil
local origSizes = {}
Reg("hitbox", {"hb"}, "Expand your hitbox  e.g. hitbox 10 | hitbox off", false, function(a)
    if hitboxOn or (a[1] and a[1]:lower() == "off") then
        hitboxOn = false
        Config.ActiveCmds["Hitbox"] = nil RefreshActive()
        if hitboxConn then hitboxConn:Disconnect() hitboxConn = nil end
        local c = LP.Character
        if c then
            for part, sz in pairs(origSizes) do
                pcall(function() part.Size = sz end)
            end
        end
        origSizes = {}
        Notify("Hitbox", "Restored", "info") return
    end
    local size = tonumber(a[1]) or 8
    local c = LP.Character
    if not c then Notify("Hitbox", "No character", "error") return end
    hitboxOn = true
    Config.ActiveCmds["Hitbox"] = true RefreshActive()
    local function applyHitbox(char)
        origSizes = {}
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
                origSizes[p] = p.Size
                pcall(function() p.Size = Vector3.new(size, size, size) end)
            end
        end
    end
    applyHitbox(c)
    hitboxConn = LP.CharacterAdded:Connect(function(char)
        if not hitboxOn then return end
        task.wait(0.5) applyHitbox(char)
    end)
    Notify("Hitbox", "Size set to "..size, "success")
end)

-- ── BIGHEAD ───────────────────────────────────────────────
local bigheadOn = false
Reg("bighead", {"bh"}, "Toggle big head", false, function()
    local c = LP.Character
    if not c then return end
    local head = c:FindFirstChild("Head")
    if not head then return end
    if bigheadOn then
        bigheadOn = false
        Config.ActiveCmds["BigHead"] = nil RefreshActive()
        pcall(function() head.Size = Vector3.new(2,2,2) end)
        Notify("BigHead", "Off", "info")
    else
        bigheadOn = true
        Config.ActiveCmds["BigHead"] = true RefreshActive()
        pcall(function() head.Size = Vector3.new(8,8,8) end)
        Notify("BigHead", "On", "success")
    end
end)

-- ── INVISIBLE ─────────────────────────────────────────────
local invisOn = false
Reg("invisible", {"invis","inv"}, "Toggle invisibility", false, function()
    local c = LP.Character
    if not c then return end
    if invisOn then
        invisOn = false
        Config.ActiveCmds["Invisible"] = nil RefreshActive()
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") or p:IsA("Decal") then
                pcall(function() p.Transparency = p:IsA("Decal") and 0 or 0 end)
            end
        end
        -- Force re-render by briefly unequipping
        Notify("Invisible", "Visible again", "info")
    else
        invisOn = true
        Config.ActiveCmds["Invisible"] = true RefreshActive()
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") or p:IsA("Decal") then
                pcall(function() p.Transparency = 1 end)
            end
        end
        Notify("Invisible", "You are now invisible", "success")
    end
end)

-- ── REACH ─────────────────────────────────────────────────
Reg("reach", {"rc"}, "Set tool reach distance  e.g. reach 20 | reach off", false, function(a)
    if a[1] and a[1]:lower() == "off" then
        local tool = LP.Character and LP.Character:FindFirstChildOfClass("Tool")
        if tool then
            local handle = tool:FindFirstChild("Handle")
            if handle then pcall(function() handle.Size = Vector3.new(1,1,1) end) end
        end
        Notify("Reach", "Reset", "info") return
    end
    local dist = tonumber(a[1]) or 15
    local tool = LP.Character and LP.Character:FindFirstChildOfClass("Tool")
    if not tool then Notify("Reach", "Equip a tool first", "warning") return end
    local handle = tool:FindFirstChild("Handle")
    if handle then
        pcall(function() handle.Size = Vector3.new(dist, dist, dist) end)
        Notify("Reach", "Reach set to "..dist, "success")
    else
        Notify("Reach", "Tool has no handle", "error")
    end
end)

-- ── ZOOM ──────────────────────────────────────────────────
Reg("zoom", {"zm"}, "Set max camera zoom  e.g. zoom 100 | zoom off", false, function(a)
    if a[1] and a[1]:lower() == "off" then
        pcall(function() LP.CameraMaxZoomDistance = 400 end)
        Notify("Zoom", "Reset to default", "info") return
    end
    local dist = tonumber(a[1]) or 100
    pcall(function() LP.CameraMaxZoomDistance = dist end)
    Notify("Zoom", "Max zoom set to "..dist, "success")
end)

-- ── THIRDPERSON ───────────────────────────────────────────
local tpOn = false
Reg("thirdperson", {"tp3","3p"}, "Lock camera to third person", false, function()
    if tpOn then
        tpOn = false
        Config.ActiveCmds["ThirdPerson"] = nil RefreshActive()
        pcall(function()
            LP.CameraMinZoomDistance = 0.5
            LP.CameraMaxZoomDistance = 400
        end)
        Notify("ThirdPerson", "Off", "info")
    else
        tpOn = true
        Config.ActiveCmds["ThirdPerson"] = true RefreshActive()
        pcall(function()
            LP.CameraMinZoomDistance = 10
            LP.CameraMaxZoomDistance = 10
        end)
        Notify("ThirdPerson", "Locked to third person", "success")
    end
end)

-- ── TRAIL ─────────────────────────────────────────────────
local trailOn = false
local trailObj = nil
Reg("trail", {"tr"}, "Toggle movement trail", false, function()
    local c = LP.Character
    local root = c and c:FindFirstChild("HumanoidRootPart")
    local head = c and c:FindFirstChild("Head")
    if not root or not head then Notify("Trail", "No character", "error") return end
    if trailOn then
        trailOn = false
        Config.ActiveCmds["Trail"] = nil RefreshActive()
        if trailObj then pcall(function() trailObj:Destroy() end) trailObj = nil end
        Notify("Trail", "Off", "info")
    else
        trailOn = true
        Config.ActiveCmds["Trail"] = true RefreshActive()
        local a0 = Instance.new("Attachment", root)
        local a1 = Instance.new("Attachment", head)
        local trail = Instance.new("Trail")
        trail.Attachment0 = a0
        trail.Attachment1 = a1
        trail.Lifetime = 0.5
        trail.MinLength = 0
        trail.FaceCamera = true
        trail.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0,   Color3.fromRGB(140,45,255)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80,200,255)),
            ColorSequenceKeypoint.new(1,   Color3.fromRGB(255,80,180)),
        })
        trail.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 1),
        })
        trail.Parent = root
        trailObj = trail
        Notify("Trail", "On", "success")
    end
end)

-- ── RAINBOW ───────────────────────────────────────────────
local rainbowOn = false
local rainbowConn = nil
Reg("rainbow", {"rb"}, "Toggle rainbow character colors", false, function()
    if rainbowOn then
        rainbowOn = false
        Config.ActiveCmds["Rainbow"] = nil RefreshActive()
        if rainbowConn then rainbowConn:Disconnect() rainbowConn = nil end
        Notify("Rainbow", "Off", "info")
    else
        rainbowOn = true
        Config.ActiveCmds["Rainbow"] = true RefreshActive()
        local hue = 0
        rainbowConn = RunService.Heartbeat:Connect(function(dt)
            if not rainbowOn then return end
            hue = (hue + dt * 0.3) % 1
            local col = Color3.fromHSV(hue, 1, 1)
            local c = LP.Character
            if not c then return end
            for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") then
                    pcall(function() p.Color = col end)
                end
            end
        end)
        Notify("Rainbow", "On", "success")
    end
end)

-- ── GHOST ─────────────────────────────────────────────────
local ghostOn = false
Reg("ghost", {"gh"}, "Toggle ghost mode (semi-transparent, no collisions)", false, function()
    local c = LP.Character
    if not c then return end
    if ghostOn then
        ghostOn = false
        Config.ActiveCmds["Ghost"] = nil RefreshActive()
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") then
                pcall(function()
                    p.Transparency = p.Name == "HumanoidRootPart" and 1 or 0
                    p.CanCollide = p.Name ~= "HumanoidRootPart"
                end)
            end
        end
        Notify("Ghost", "Off", "info")
    else
        ghostOn = true
        Config.ActiveCmds["Ghost"] = true RefreshActive()
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") then
                pcall(function()
                    p.Transparency = 0.6
                    p.CanCollide = false
                end)
            end
        end
        Notify("Ghost", "On - semi-transparent and no collisions", "success")
    end
end)

-- ── HAT ───────────────────────────────────────────────────
Reg("hat", {"accessory"}, "Equip any hat by asset ID  e.g. hat 1365767", false, function(a)
    local id = tonumber(a[1])
    if not id then Notify("Hat", "Usage: hat <assetId>", "warning") return end
    local ok, err = pcall(function()
        local ins = game:GetService("InsertService")
        local model = ins:LoadAsset(id)
        local hat = model:FindFirstChildOfClass("Accessory")
            or model:FindFirstChildOfClass("Hat")
            or model:FindFirstChild("Handle") and model
        if not hat then model:Destroy() Notify("Hat", "No accessory found in asset "..id, "error") return end
        hat.Parent = LP.Character
        model:Destroy()
        Notify("Hat", "Equipped asset "..id, "success")
    end)
    if not ok then Notify("Hat", "Failed: "..tostring(err), "error") end
end)

-- ── FIND ──────────────────────────────────────────────────
Reg("find", {"where","loc"}, "Show a player's location  e.g. find Player1", false, function(a)
    local t = FindPlayer(a[1])
    if not t then Notify("Find", "Player not found: "..(a[1] or "?"), "error") return end
    local root = t.Character and t.Character:FindFirstChild("HumanoidRootPart")
    if not root then Notify("Find", PStr(t).." has no character", "error") return end
    local p = root.Position
    Notify("Find  "..t.Name,
        string.format("X: %.1f  Y: %.1f  Z: %.1f", p.X, p.Y, p.Z),
        "info", 6)
end)

-- ── PLAYERS ───────────────────────────────────────────────
Reg("players", {"list","who"}, "List all players in the server", false, function()
    local lines = {}
    for _, p in ipairs(Players:GetPlayers()) do
        local ping = ""
        pcall(function()
            ping = "  "..math.floor(p:GetNetworkPing()*1000).."ms"
        end)
        local tag = p == LP and " (you)" or ""
        table.insert(lines, p.DisplayName.." @"..p.Name..ping..tag)
    end
    Notify("Players ("..#lines..")", table.concat(lines, "\n"), "info", 8)
end)

-- ── COPYFIT ───────────────────────────────────────────────
Reg("copyfit", {"cf","outfit"}, "Copy another player's outfit  e.g. copyfit Player1", false, function(a)
    local t = FindPlayer(a[1])
    if not t then Notify("CopyFit", "Player not found: "..(a[1] or "?"), "error") return end
    local ok, err = pcall(function()
        local desc = Players:GetCharacterAppearanceAsync(t.UserId)
        local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum:ApplyDescription(desc)
            Notify("CopyFit", "Copied outfit from "..t.DisplayName, "success", 4)
        end
    end)
    if not ok then Notify("CopyFit", "Failed: "..tostring(err), "error") end
end)

-- ── UNEQUIP ───────────────────────────────────────────────
Reg("unequip", {"ue","drop"}, "Unequip all tools", false, function()
    local c = LP.Character
    if not c then return end
    local bp = LP:FindFirstChildOfClass("Backpack")
    local count = 0
    for _, tool in ipairs(c:GetChildren()) do
        if tool:IsA("Tool") then
            pcall(function()
                tool.Parent = bp or c
                count = count + 1
            end)
        end
    end
    Notify("Unequip", "Unequipped "..count.." tool(s)", "info")
end)

-- ── Chat sender helper (used by control loop) ────────────────
local function SendChat(msg)
    local sent = false
    pcall(function()
        local tcs = game:GetService("TextChatService")
        if tcs.ChatVersion == Enum.ChatVersion.TextChatService then
            local ch = tcs.TextChannels:FindFirstChild("RBXGeneral")
            if ch then ch:SendAsync(msg) sent = true end
        end
    end)
    if not sent then pcall(function()
        local ev  = game:GetService("ReplicatedStorage"):FindFirstChild("DefaultChatSystemChatEvents")
        local sr  = ev and ev:FindFirstChild("SayMessageRequest")
        if sr then sr:FireServer(msg, "All") end
    end) end
end

-- ── PREMIUM: CONTROL ──────────────────────────────────────────
-- Premium user types .control <player> in chat to start.
-- Their script reads WASD and sends .ctrlmove x z signals every 0.1s.
-- .release ends it on the target's side.
local controlTarget   = nil
local controlConn     = nil
local controlChatConn = nil

-- Listen for .control and .release typed in chat by THIS premium user
local function StartControlListener()
    local function onMsg(msg)
        if not IsPremium() then return end
        local clean = msg:match("^%S+:%s*(.+)$") or msg
        if clean:sub(1,1) ~= "." then return end
        local words = {}
        for w in clean:sub(2):gmatch("%S+") do table.insert(words, w) end
        local cmd = (words[1] or ""):lower()

        if cmd == "control" or cmd == "ctrl" then
            local targetName = words[2]
            if not targetName then return end
            local t = FindPlayer(targetName)
            if not t then Notify("Control", "Player not found: "..targetName, "error") return end
            -- Stop any existing control loop
            if controlConn then controlConn:Disconnect() controlConn = nil end
            controlTarget = t
            Config.ActiveCmds["Controlling"] = t.Name RefreshActive()
            Notify("Control", "Controlling "..t.DisplayName.."  |  .release to stop", "warning", 5)
            -- Start WASD loop — sends a chat signal every 0.15s (throttled)
            controlConn = task.spawn(function()
                while controlTarget do
                    local x, z = 0, 0
                    if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up)    then z = z - 1 end
                    if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down)  then z = z + 1 end
                    if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left)  then x = x - 1 end
                    if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then x = x + 1 end
                    SendChat(".ctrlmove "..controlTarget.Name.." "..x.." "..z)
                    task.wait(0.15)
                end
            end)

        elseif cmd == "release" then
            -- Setting controlTarget to nil stops the task.spawn loop naturally
            controlTarget = nil
            controlConn   = nil
            Config.ActiveCmds["Controlling"] = nil RefreshActive()
            Notify("Control", "Control released", "info", 3)
        end
    end

    -- Hook both chat systems
    pcall(function()
        local tcs = game:GetService("TextChatService")
        tcs.MessageReceived:Connect(function(msg)
            if msg.TextSource and msg.TextSource.UserId == LP.UserId then
                onMsg(msg.Text)
            end
        end)
    end)
    LP.Chatted:Connect(onMsg)
end

if IsPremium() then
    StartControlListener()
end

-- ── PREMIUM: SPIN ─────────────────────────────────────────
-- .spin <player>  — handled in detection.lua via dot-command
-- We just register it here so it shows in help
Reg("spin_info", {}, "Premium: .spin <player> in chat", true, function()
    Notify("Spin [P]", "Type .spin <player> in Roblox chat", "gold")
end)

-- ── PREMIUM: EXPLODE ──────────────────────────────────────
Reg("explode_info", {}, "Premium: .explode <player> in chat", true, function()
    Notify("Explode [P]", "Type .explode <player> in Roblox chat", "gold")
end)

-- ── PREMIUM: FOLLOW ───────────────────────────────────────
Reg("follow_info", {}, "Premium: .follow <player> / .unfollow in chat", true, function()
    Notify("Follow [P]", "Type .follow <player> in Roblox chat", "gold")
end)

-- ── PREMIUM: TP2ME ────────────────────────────────────────
Reg("tp2me_info", {}, "Premium: .tp2me <player> / .tp2me <player> stop in chat", true, function()
    Notify("TP2Me [P]", "Type .tp2me <player> in Roblox chat", "gold")
end)


-- ── LOOP TELEPORT ────────────────────────────────────────────
local loopTpOn     = false
local loopTpTarget = nil

Reg("looptp", {"ltp"}, "Loop teleport to a player  e.g. looptp Player1 | looptp stop", false, function(a)
    if not a[1] or a[1]:lower() == "stop" then
        loopTpOn     = false
        loopTpTarget = nil
        Config.ActiveCmds["LoopTP"] = nil
        RefreshActive()
        Notify("LoopTP", "Stopped", "info")
        return
    end
    local t = FindPlayer(a[1])
    if not t then Notify("LoopTP", "Player not found: "..(a[1] or "?"), "error") return end
    loopTpOn     = true
    loopTpTarget = t
    Config.ActiveCmds["LoopTP"] = t.Name
    RefreshActive()
    Notify("LoopTP", "Looping to "..t.DisplayName.."  |  looptp stop to cancel", "success", 4)
    task.spawn(function()
        while loopTpOn and loopTpTarget do
            pcall(function()
                local r  = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                local tr = loopTpTarget.Character and loopTpTarget.Character:FindFirstChild("HumanoidRootPart")
                if r and tr then
                    r.CFrame = tr.CFrame * CFrame.new(math.random(-3, 3), 0, math.random(-3, 3))
                end
            end)
            task.wait(0.1)
        end
    end)
end)

-- ── VOID SPAM ─────────────────────────────────────────────────
local vspamOn   = false
local vspamConn = nil

Reg("voidspam", {"vs"}, "Toggle void spam", false, function()
    if vspamOn then
        vspamOn = false
        Config.ActiveCmds["VoidSpam"] = nil
        RefreshActive()
        if vspamConn then vspamConn:Disconnect() vspamConn = nil end
        -- Restore camera
        pcall(function()
            local cam = workspace.CurrentCamera
            cam.CameraType = Enum.CameraType.Custom
            local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
            if hum then cam.CameraSubject = hum end
        end)
        Notify("Void Spam", "Off", "info")
        return
    end
    local r = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not r then Notify("Void Spam", "No character", "error") return end
    vspamOn = true
    Config.ActiveCmds["VoidSpam"] = true
    RefreshActive()
    Notify("Void Spam", "On  —  type again to stop", "success")

    -- Lock camera to character so it stays on the map while body flickers
    local cam = workspace.CurrentCamera
    local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    cam.CameraType    = Enum.CameraType.Custom
    if hum then cam.CameraSubject = hum end

    local inVoid = false
    local savedCF = r.CFrame

    vspamConn = RunService.Heartbeat:Connect(function()
        if not vspamOn then return end
        local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if not root then return end
        if inVoid then
            -- Return to saved position so humanoid can process movement
            root.CFrame = savedCF
            inVoid = false
        else
            -- Save where we are (includes any movement made while visible)
            savedCF = root.CFrame
            root.CFrame = CFrame.new(savedCF.X, -1e4, savedCF.Z)
            inVoid = true
        end
    end)
end)

-- ── IMMORTAL ─────────────────────────────────────────────────
-- Constantly resets health to max and zeroes out any knockback
-- velocity every heartbeat — taken from sniper bot health logic
local immortalOn   = false
local immortalConn = nil

Reg("immortal", {"imm"}, "Toggle immortal mode (constant max health + zero knockback)", false, function()
    if immortalOn then
        immortalOn = false
        Config.ActiveCmds["Immortal"] = nil
        RefreshActive()
        if immortalConn then immortalConn:Disconnect() immortalConn = nil end
        Notify("Immortal", "Off", "info")
        return
    end
    immortalOn = true
    Config.ActiveCmds["Immortal"] = true
    RefreshActive()
    Notify("Immortal", "On  —  health locked to max, knockback zeroed", "success")
    immortalConn = RunService.Heartbeat:Connect(function()
        if not immortalOn then return end
        local c   = LP.Character
        local hum = c and c:FindFirstChildOfClass("Humanoid")
        local hrp = c and c:FindFirstChild("HumanoidRootPart")
        if not c or not hum then return end
        -- Lock health to max
        if hum.Health > 0 then
            hum.Health = hum.MaxHealth
        end
        -- Zero out any fling/knockback velocity
        if hrp then
            local vel = hrp.AssemblyLinearVelocity
            if vel.Magnitude > 50 then
                hrp.AssemblyLinearVelocity  = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
            end
        end
    end)
end)

-- ── INFINITY (ORBIT) ─────────────────────────────────────────
-- Inspired by Gojo's Infinity — objects that come near get pulled
-- into orbit automatically. Anything trying to breach the barrier
-- gets pushed away. Nothing unanchored can touch you.
local infinityOn    = false
local infinityParts = {}  -- { part, angle, radius, height, speed }
local infinityConn  = nil
local INFINITY_BARRIER = 6   -- studs — nothing gets closer than this
local INFINITY_PULL    = 20  -- studs — objects within this get absorbed
local INFINITY_ORBIT   = 8   -- orbit ring radius

local function isCharPart(obj)
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character and obj:IsDescendantOf(p.Character) then return true end
    end
    return false
end

local function alreadyOrbing(part)
    for _, d in ipairs(infinityParts) do
        if d.part == part then return true end
    end
    return false
end

local function absorbPart(part)
    if alreadyOrbing(part) then return end
    local bp = Instance.new("BodyPosition")
    bp.Name     = "VCInfBP"
    bp.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    bp.P        = 2e4
    bp.D        = 800
    bp.Parent   = part
    -- Also kill its velocity so it doesn't yank us
    pcall(function()
        part.AssemblyLinearVelocity  = Vector3.zero
        part.AssemblyAngularVelocity = Vector3.zero
    end)
    table.insert(infinityParts, {
        part   = part,
        angle  = math.random() * math.pi * 2,
        radius = INFINITY_ORBIT + math.random(-2, 2),
        height = math.random(-3, 4),
        speed  = math.random(60, 140) / 100,
    })
end

local function StopInfinity()
    infinityOn = false
    Config.ActiveCmds["Infinity"] = nil
    RefreshActive()
    if infinityConn then infinityConn:Disconnect() infinityConn = nil end
    for _, data in ipairs(infinityParts) do
        pcall(function()
            local bp = data.part:FindFirstChild("VCInfBP")
            if bp then bp:Destroy() end
        end)
    end
    infinityParts = {}
    Notify("Infinity", "Cursed Technique: Reversed  |  Off", "info")
end

Reg("infinity", {"inf","gojo"}, "Toggle Infinity — objects orbit you and can never touch you", false, function(a)
    if infinityOn or (a[1] and a[1]:lower() == "off") then
        StopInfinity() return
    end
    local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not root then Notify("Infinity", "No character", "error") return end

    infinityOn = true
    Config.ActiveCmds["Infinity"] = true
    RefreshActive()
    Notify("Infinity", "Cursed Technique: Infinity  |  Nothing can touch you", "success", 5)

    local scanTimer = 0

    infinityConn = RunService.Heartbeat:Connect(function(dt)
        if not infinityOn then return end
        local r = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if not r then return end
        local center = r.Position + Vector3.new(0, 2, 0)

        -- Only scan workspace every 0.5s — this is what caused lag
        scanTimer = scanTimer + dt
        if scanTimer >= 0.5 then
            scanTimer = 0
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("BasePart") and not obj.Anchored and not isCharPart(obj) then
                    local dist = (obj.Position - center).Magnitude
                    if dist <= INFINITY_PULL and dist > INFINITY_BARRIER then
                        absorbPart(obj)
                    end
                end
            end
        end

        -- Update orbit + barrier every frame (lightweight, just math)
        for i = #infinityParts, 1, -1 do
            local data = infinityParts[i]
            pcall(function()
                if not data.part or not data.part.Parent or data.part.Anchored then
                    pcall(function()
                        local bp = data.part:FindFirstChild("VCInfBP")
                        if bp then bp:Destroy() end
                    end)
                    table.remove(infinityParts, i)
                    return
                end
                data.angle = data.angle + dt * data.speed
                local target = center + Vector3.new(
                    math.cos(data.angle) * data.radius,
                    data.height,
                    math.sin(data.angle) * data.radius
                )
                local bp = data.part:FindFirstChild("VCInfBP")
                if bp then bp.Position = target end
                -- Push anything breaching the barrier
                local dist = (data.part.Position - center).Magnitude
                if dist < INFINITY_BARRIER then
                    local pushDir = (data.part.Position - center)
                    pushDir = pushDir.Magnitude > 0 and pushDir.Unit or Vector3.new(0,1,0)
                    data.part.AssemblyLinearVelocity = pushDir * 60
                end
            end)
        end
    end)
end)

-- ── INFINITE JUMP ────────────────────────────────────────────
local ijOn   = false
local ijConn = nil
Reg("infinitejump", {"ij"}, "Toggle infinite jump", false, function()
    if ijOn then
        ijOn = false
        Config.ActiveCmds["InfJump"] = nil RefreshActive()
        if ijConn then ijConn:Disconnect() ijConn = nil end
        Notify("Infinite Jump", "Off", "info")
    else
        ijOn = true
        Config.ActiveCmds["InfJump"] = true RefreshActive()
        ijConn = UserInputService.JumpRequest:Connect(function()
            if not ijOn then return end
            local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
        end)
        Notify("Infinite Jump", "On  —  hold Space to keep jumping", "success")
    end
end)

-- ═══════════════════════════════════════════════════════════
-- RESPAWN - restore all active features
-- ═══════════════════════════════════════════════════════════
LP.CharacterAdded:Connect(function()
    task.wait(1)
    if flyOn      then flyOn  = false task.wait(0.2) StartFly()    end
    if ncOn       then ncOn   = false task.wait(0.1) StartNoclip() end
    if godOn      then godOn  = false task.wait(0.3) StartGod()    end
    if immortalOn then
        if immortalConn then immortalConn:Disconnect() immortalConn = nil end
        immortalConn = RunService.Heartbeat:Connect(function()
            if not immortalOn then return end
            local c   = LP.Character
            local hum = c and c:FindFirstChildOfClass("Humanoid")
            local hrp = c and c:FindFirstChild("HumanoidRootPart")
            if not c or not hum then return end
            if hum.Health > 0 then hum.Health = hum.MaxHealth end
            if hrp then
                local vel = hrp.AssemblyLinearVelocity
                if vel.Magnitude > 50 then
                    hrp.AssemblyLinearVelocity  = Vector3.zero
                    hrp.AssemblyAngularVelocity = Vector3.zero
                end
            end
        end)
    end
    if vspamOn then
        if vspamConn then vspamConn:Disconnect() vspamConn = nil end
        local inVoid2 = false
        local savedCF2 = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") and LP.Character.HumanoidRootPart.CFrame or CFrame.new()
        vspamConn = RunService.Heartbeat:Connect(function()
            if not vspamOn then return end
            local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
            if not root then return end
            if inVoid2 then
                root.CFrame = savedCF2
                inVoid2 = false
            else
                savedCF2 = root.CFrame
                root.CFrame = CFrame.new(savedCF2.X, -1e4, savedCF2.Z)
                inVoid2 = true
            end
        end)
    end

    if loopTpOn and loopTpTarget then
        task.spawn(function()
            while loopTpOn and loopTpTarget do
                pcall(function()
                    local r  = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                    local tr = loopTpTarget.Character and loopTpTarget.Character:FindFirstChild("HumanoidRootPart")
                    if r and tr then
                        r.CFrame = tr.CFrame * CFrame.new(math.random(-3,3), 0, math.random(-3,3))
                    end
                end)
                task.wait(0.1)
            end
        end)
    end

    if ijOn then
        if ijConn then ijConn:Disconnect() ijConn = nil end
        ijConn = UserInputService.JumpRequest:Connect(function()
            if not ijOn then return end
            local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
        end)
    end
    if espOn      then
        task.wait(1.2)
        for _, p in ipairs(Players:GetPlayers()) do task.spawn(BuildESPFor, p) end
    end
    -- Restore visual toggles after respawn
    task.wait(0.3)
    if invisOn then
        invisOn = false
        local c = LP.Character
        if c then
            for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") or p:IsA("Decal") then
                    pcall(function() p.Transparency = 1 end)
                end
            end
            invisOn = true
        end
    end
    if ghostOn then
        ghostOn = false
        local c = LP.Character
        if c then
            for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") then
                    pcall(function() p.Transparency = 0.6 p.CanCollide = false end)
                end
            end
            ghostOn = true
        end
    end
    if rainbowOn then
        -- rainbowConn still running, just let it apply to new character
    end
    if bigheadOn then
        local head = LP.Character and LP.Character:FindFirstChild("Head")
        if head then pcall(function() head.Size = Vector3.new(8,8,8) end) end
    end
    if trailOn then
        local c    = LP.Character
        local root = c and c:FindFirstChild("HumanoidRootPart")
        local head = c and c:FindFirstChild("Head")
        if root and head and trailObj then
            pcall(function() trailObj:Destroy() end)
            trailObj = nil
            trailOn = false
        end
    end
end)

-- ═══════════════════════════════════════════════════════════

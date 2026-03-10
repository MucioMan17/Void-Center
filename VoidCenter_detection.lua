-- ── VoidCenter: Detection + P2P module ─────────────────────
local _VC = getgenv()._VC
local LP             = _VC.LP
local Players        = _VC.Players
local RunService     = _VC.RunService
local Debris         = _VC.Debris
local C              = _VC.C
local TF             = _VC.TF
local TM             = _VC.TM
local N              = _VC.N
local Tween          = _VC.Tween
local Corner         = _VC.Corner
local Stroke         = _VC.Stroke
local Config         = _VC.Config
local IsPremium      = _VC.IsPremium
local freeIds        = _VC.freeIds
local premIds        = _VC.premIds
local Notify         = _VC.Notify
local FindPlayer     = _VC.FindPlayer
local PStr           = _VC.PStr
local Reg            = _VC.Reg
local RefreshActive  = _VC.RefreshActive
local Screen         = _VC.Screen
local UserInputService = _VC.UserInputService

-- VOID USER DETECTION  (whitelist-based, no cross-client needed)
-- ─────────────────────────────────────────────────────────
-- Since every script loads the same two GitHub lists, we
-- already know exactly who has the script and what tier
-- they are. We just scan the player list on load and watch
-- PlayerAdded for new joiners. No chat, no parts, nothing.
--
-- P2P SIGNALS still use invisible chat (confirmed working)
-- for premium commands. Detection itself needs nothing.
-- ═══════════════════════════════════════════════════════════

local vcUsers = {}   -- [player] = { premium = bool }

local function IsVoidUser(p) return vcUsers[p] ~= nil end

local function IsWhitelisted(player)
    local id = player.UserId
    return freeIds[id] or premIds[id]
end

-- ── Tags ──────────────────────────────────────────────────────
local tagData = {}

local function RemoveTag(p)
    if tagData[p] then pcall(function() tagData[p]:Destroy() end) tagData[p] = nil end
end

local function MakeTag(player)
    if player == LP then return end
    local ch   = player.Character
    local root = ch and ch:FindFirstChild("HumanoidRootPart")
    if not root then return end
    RemoveTag(player)

    local info = vcUsers[player]
    local prem = info and info.premium == true
    local acC  = prem and C.Gold or C.AcctBr
    local bgC  = prem and Color3.fromRGB(38,16,0) or Color3.fromRGB(14,0,30)

    local bill = Instance.new("BillboardGui")
    bill.Name           = "VTag_"..player.Name
    -- Fixed pixel size so it always renders. SizeOffset keeps it readable.
    bill.Size           = UDim2.new(0, 180, 0, 42)
    bill.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
    bill.AlwaysOnTop    = true
    bill.LightInfluence = 0
    bill.MaxDistance    = 70
    bill.Parent         = root

    -- Background
    local bg = N("Frame", {
        BackgroundColor3 = bgC, BackgroundTransparency = 0.1,
        BorderSizePixel = 0, Size = UDim2.new(1,0,1,0),
    }, bill)
    Corner(8, bg)
    Stroke(acC, 1, bg)

    -- Left accent stripe
    N("Frame", {
        BackgroundColor3 = acC, BorderSizePixel = 0,
        Size = UDim2.new(0, 3, 1, 0),
    }, bg)

    -- Tier label (top row)
    local tierTxt = prem and "PREMIUM" or "FREE"
    N("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 9, 0, 3), Size = UDim2.new(1, -12, 0, 16),
        Font = Enum.Font.GothamBold,
        Text = tierTxt,
        TextColor3 = acC, TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, bg)

    -- Display name (bottom row)
    N("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 9, 0, 21), Size = UDim2.new(1, -12, 0, 16),
        Font = Enum.Font.Gotham,
        Text = player.DisplayName .. "  (@" .. player.Name .. ")",
        TextColor3 = Color3.fromRGB(210, 195, 240), TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, bg)

    -- Invisible click button for TP
    local btn = N("TextButton", {
        BackgroundTransparency = 1, Size = UDim2.new(1,0,1,0), Text = "", ZIndex = 5,
    }, bg)
    btn.MouseButton1Click:Connect(function()
        local mr = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        local tr = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if mr and tr then
            mr.CFrame = tr.CFrame + Vector3.new(0,0,3.5)
            Notify("Tag", "Teleported to "..player.DisplayName, "success")
        end
    end)
    btn.MouseEnter:Connect(function() Tween(bg, TF, {BackgroundTransparency=0}) end)
    btn.MouseLeave:Connect(function() Tween(bg, TF, {BackgroundTransparency=0.1}) end)
    tagData[player] = bill
end

-- Register a player as a VC user based on whitelist tier
local function RegisterIfWhitelisted(player)
    if player == LP then return end
    local id   = player.UserId
    local isPrem = premIds[id] == true
    local isFree = freeIds[id] == true
    if not isPrem and not isFree then return end  -- not whitelisted, skip

    local prev = vcUsers[player]
    vcUsers[player] = { premium = isPrem }

    if not prev or prev.premium ~= isPrem
    or not tagData[player] or not tagData[player].Parent then
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            MakeTag(player)
        end
    end
    -- Rebuild tag when they respawn
    if not prev then
        player.CharacterAdded:Connect(function()
            task.wait(1)
            if vcUsers[player] then MakeTag(player) end
        end)
    end
end

-- Scan everyone already in the server
for _, p in ipairs(Players:GetPlayers()) do
    RegisterIfWhitelisted(p)
end

-- Watch for new players joining
Players.PlayerAdded:Connect(function(p)
    -- Wait briefly for their character to load
    task.delay(1, function() RegisterIfWhitelisted(p) end)
end)

Players.PlayerRemoving:Connect(function(p)
    RemoveTag(p)
    vcUsers[p] = nil
end)

-- Rebuild tags after we respawn
LP.CharacterAdded:Connect(function()
    task.wait(1)
    for p in pairs(vcUsers) do
        if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            MakeTag(p)
        end
    end
end)

-- ═══════════════════════════════════════════════════════════
-- P2P SIGNALS  (ChildAdded on HumanoidRootPart)
-- ─────────────────────────────────────────────────────────
-- HOW IT WORKS:
--   When a LocalScript creates a Part inside its OWN character,
--   Roblox replicates that to the server then to every client.
--   ChildAdded fires on every other client — this is exactly
--   how tools and accessories work. Zero chat, zero filter.
--
-- SENDING:
--   Create a Part named "s_CMD_UID_TICK" inside our HRP.
--   Debris removes it after 1.5s so HRPs stay clean.
--
-- RECEIVING:
--   Every script watches every whitelisted player's HRP with
--   ChildAdded. When a "s_" part appears we parse the name
--   and call HandleSig if the UID matches us.
--
-- WHY IT WORKS THIS TIME:
--   Previous attempt watched GetPropertyChangedSignal("Size")
--   which does NOT replicate from LocalScript. ChildAdded DOES.
-- ═══════════════════════════════════════════════════════════

local SIG_PFX = "s"   -- signal part name prefix
local seenSig = {}    -- dedup table

-- ── Send a signal ─────────────────────────────────────────────
local function SendSig(code, targetUID, extra)
    pcall(function()
        local chr  = LP.Character
        local root = chr and chr:FindFirstChild("HumanoidRootPart")
        if not root then return end

        local uid = (targetUID or 0) % 100000
        local tk  = math.floor(tick() * 10) % 10000

        -- Name encodes everything: s_CODE_UID_TICK
        local name = SIG_PFX.."_"..code.."_"..uid.."_"..tk

        local p = Instance.new("Part")
        p.Name         = name
        p.Size         = Vector3.new(0.05, 0.05, 0.05)
        p.Transparency = 1
        p.CanCollide   = false
        p.Anchored     = false
        p.Massless     = true
        p.CastShadow   = false

        -- For chatmsg: store text in a StringValue child
        if type(extra) == "string" and extra ~= "" then
            local sv = Instance.new("StringValue")
            sv.Name   = "x"
            sv.Value  = extra
            sv.Parent = p
        end

        p.Parent = root
        Debris:AddItem(p, 1.5)  -- auto-cleanup
    end)
end

-- ── Signal handler (executes on the RECEIVING client) ─────────
local function HandleSig(sender, code, tuid, sigPart)
    -- 0 = broadcast (bringall), otherwise must match our UserId
    if tuid ~= 0 and tuid ~= LP.UserId % 100000 then return end

    local c, r, hum
    local function gc()
        c   = LP.Character
        r   = c and c:FindFirstChild("HumanoidRootPart")
        hum = c and c:FindFirstChildOfClass("Humanoid")
    end

    if code == 1 then -- fling
        gc() if not r then return end
        local bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(1e9,1e9,1e9)
        bv.Velocity = Vector3.new(math.random(-160,160),350,math.random(-160,160))
        bv.Parent = r
        Debris:AddItem(bv, 0.15)
        Notify("Signal","Flung by "..sender.DisplayName,"warning",3)

    elseif code == 2 or code == 3 then -- bring / bringall
        gc()
        local sr = sender.Character and sender.Character:FindFirstChild("HumanoidRootPart")
        if r and sr then
            r.CFrame = sr.CFrame * CFrame.new(math.random(-4,4), 0, math.random(-4,4))
        end
        Notify("Signal","Brought to "..sender.DisplayName,"info",3)

    elseif code == 4 or code == 5 then -- reset / kill
        gc() if hum then hum.Health = 0 end
        Notify("Signal","Killed by "..sender.DisplayName,"error",3)

    elseif code == 6 then -- freeze
        Config.ActiveCmds["Frozen"] = true RefreshActive() gc()
        if c then
            for _,p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") then p.Anchored = true end
            end
            if hum then hum.PlatformStand = true end
        end
        Notify("Signal","Frozen by "..sender.DisplayName,"warning",4)

    elseif code == 7 then -- unfreeze
        Config.ActiveCmds["Frozen"] = nil RefreshActive() gc()
        if c then
            for _,p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") then p.Anchored = false end
            end
            if hum then hum.PlatformStand = false end
        end
        Notify("Signal","Unfrozen","info",3)

    elseif code == 8 then -- kick (void loop)
        if Config.ActiveCmds["Kicked"] then return end
        Config.ActiveCmds["Kicked"] = true RefreshActive()
        Notify("Signal","Kicked by "..sender.DisplayName,"error",4)
        task.spawn(function()
            while Config.ActiveCmds["Kicked"] do
                pcall(function()
                    gc()
                    if r   then r.CFrame   = CFrame.new(0,-9999,0) end
                    if hum then hum.Health = 0 end
                end)
                task.wait(0.08)
            end
        end)

    elseif code == 9 then -- unkick
        Config.ActiveCmds["Kicked"] = nil RefreshActive()
        Notify("Signal","Kick stopped","info",3)

    elseif code == 10 then -- ctrl_start
        if IsPremium() then return end
        Config.ActiveCmds["Controlled"] = true RefreshActive() gc()
        if c then
            for _,p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") then p.Anchored = true end
            end
            if hum then hum.PlatformStand = true end
        end
        Notify("Signal","Controlled by "..sender.DisplayName,"warning",5)

    elseif code == 11 then -- ctrl_stop
        Config.ActiveCmds["Controlled"] = nil RefreshActive() gc()
        if c then
            for _,p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") then p.Anchored = false end
            end
            if hum then hum.PlatformStand = false end
            if r then
                local bv = r:FindFirstChild("VoidCtrlBV")
                if bv then bv:Destroy() end
            end
        end
        Notify("Signal","Control released","info",3)

    elseif code == 12 then -- ctrl_vel
        if not Config.ActiveCmds["Controlled"] then return end
        local sv = sigPart and sigPart:FindFirstChild("x")
        if not sv then return end
        local dirCode, jumpBit = sv.Value:match("(%d+),(%d)")
        dirCode = tonumber(dirCode) or 0
        local doJump = jumpBit == "1"
        local DIR = {
            [0]=Vector3.zero,
            [1]=Vector3.new(0,0,-1), [2]=Vector3.new(0,0,1),
            [3]=Vector3.new(1,0,0),  [4]=Vector3.new(-1,0,0),
            [5]=Vector3.new(1,0,-1), [6]=Vector3.new(-1,0,-1),
            [7]=Vector3.new(1,0,1),  [8]=Vector3.new(-1,0,1),
        }
        local baseDir = DIR[dirCode] or Vector3.zero
        gc() if not r then return end
        local sr = sender.Character and sender.Character:FindFirstChild("HumanoidRootPart")
        local dir = baseDir
        if sr and baseDir.Magnitude > 0 then
            local lv = sr.CFrame.LookVector
            local rv = sr.CFrame.RightVector
            dir = Vector3.new(
                lv.X*(-baseDir.Z) + rv.X*baseDir.X, 0,
                lv.Z*(-baseDir.Z) + rv.Z*baseDir.X)
            if dir.Magnitude > 0.01 then dir = dir.Unit end
        end
        local spd = hum and hum.WalkSpeed or 16
        local bv  = r:FindFirstChild("VoidCtrlBV")
        if not bv then
            bv           = Instance.new("BodyVelocity")
            bv.Name      = "VoidCtrlBV"
            bv.MaxForce  = Vector3.new(1e9,0,1e9)
            bv.Parent    = r
        end
        bv.Velocity = dir * spd
        if doJump then
            local jbv        = Instance.new("BodyVelocity")
            jbv.MaxForce     = Vector3.new(0,1e9,0)
            jbv.Velocity     = Vector3.new(0,60,0)
            jbv.Parent       = r
            Debris:AddItem(jbv, 0.12)
        end

    elseif code == 13 then -- chatmsg
        local sv = sigPart and sigPart:FindFirstChild("x")
        local msg = sv and sv.Value or ""
        if msg == "" then return end
        local sent = false
        if not sent then pcall(function()
            local tcs = game:GetService("TextChatService")
            if tcs.ChatVersion == Enum.ChatVersion.TextChatService then
                local ch = tcs.TextChannels:FindFirstChild("RBXGeneral")
                if ch then ch:SendAsync(msg) sent = true end
            end
        end) end
        if not sent then pcall(function()
            local ev  = game:GetService("ReplicatedStorage"):FindFirstChild("DefaultChatSystemChatEvents")
            local sr2 = ev and ev:FindFirstChild("SayMessageRequest")
            if sr2 then sr2:FireServer(msg, "All") end
        end) end
    end
end

-- ── Watch a player's HRP for signal parts ─────────────────────
local function WatchHRP(player, hrp)
    hrp.ChildAdded:Connect(function(child)
        -- Signal parts are named "s_CODE_UID_TICK"
        local name = child.Name
        if name:sub(1,2) ~= SIG_PFX.."_" then return end

        task.spawn(function()
            task.wait(0.05)  -- tiny wait for StringValue child to replicate
            pcall(function()
                local parts = name:split("_")
                -- parts = {"s", "CODE", "UID", "TICK"}
                local code = tonumber(parts[2])
                local uid  = tonumber(parts[3])
                local tk   = parts[4] or ""
                if not code or not uid then return end

                -- Only handle signals from whitelisted players
                if not IsWhitelisted(player) then return end

                -- Dedup
                local key = tostring(player.UserId)..":"..code..":"..uid..":"..tk
                if seenSig[key] then return end
                seenSig[key] = true
                task.delay(5, function() seenSig[key] = nil end)

                HandleSig(player, code, uid, child)
            end)
        end)
    end)
end

-- Watch a player's current and future characters
local function WatchPlayer(player)
    local function onChar(char)
        task.spawn(function()
            local hrp = char:WaitForChild("HumanoidRootPart", 10)
            if hrp then WatchHRP(player, hrp) end
        end)
    end
    if player.Character then onChar(player.Character) end
    player.CharacterAdded:Connect(onChar)
end

-- Watch all current players (skip self — we send, not receive our own)
for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LP then WatchPlayer(p) end
end
Players.PlayerAdded:Connect(function(p)
    if p ~= LP then WatchPlayer(p) end
end)


-- =========================================================
-- Export detection state for commands module
_VC.vcUsers         = vcUsers
_VC.IsVoidUser      = IsVoidUser
_VC.IsWhitelisted   = IsWhitelisted
_VC.SendSig         = SendSig
_VC.tagData         = tagData

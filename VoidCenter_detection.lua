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

    -- Small pill tag — just a dot + username, sits just above the head
    local bill = Instance.new("BillboardGui")
    bill.Name                  = "VTag_"..player.Name
    bill.Size                  = UDim2.new(0, 120, 0, 20)
    bill.StudsOffsetWorldSpace = Vector3.new(0, 2.8, 0)
    bill.AlwaysOnTop           = true
    bill.LightInfluence        = 0
    bill.MaxDistance           = 0
    bill.Parent                = root

    -- Pill background — very subtle, semi-transparent
    local bg = N("Frame", {
        BackgroundColor3    = Color3.fromRGB(8, 0, 18),
        BackgroundTransparency = 0.35,
        BorderSizePixel     = 0,
        Size                = UDim2.new(1, 0, 1, 0),
    }, bill)
    Corner(10, bg)
    Stroke(acC, 1, bg)

    -- Dot indicator (filled circle, tier color)
    N("Frame", {
        BackgroundColor3 = acC,
        BorderSizePixel  = 0,
        AnchorPoint      = Vector2.new(0, 0.5),
        Position         = UDim2.new(0, 6, 0.5, 0),
        Size             = UDim2.new(0, 6, 0, 6),
    }, bg)
    Corner(4, bg:FindFirstChildOfClass("Frame"))

    -- Username only — clean and minimal
    N("TextLabel", {
        BackgroundTransparency = 1,
        Position  = UDim2.new(0, 17, 0, 0),
        Size      = UDim2.new(1, -20, 1, 0),
        Font      = Enum.Font.GothamBold,
        Text      = player.Name,
        TextColor3 = acC,
        TextSize  = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate   = Enum.TextTruncate.AtEnd,
    }, bg)

    -- Click to teleport
    local btn = N("TextButton", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Text = "", ZIndex = 5,
    }, bg)
    btn.MouseButton1Click:Connect(function()
        local mr = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        local tr = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if mr and tr then
            mr.CFrame = tr.CFrame + Vector3.new(0, 0, 3.5)
            Notify("Tag", "Teleported to "..player.DisplayName, "success")
        end
    end)
    btn.MouseEnter:Connect(function() Tween(bg, TF, {BackgroundTransparency = 0.1}) end)
    btn.MouseLeave:Connect(function() Tween(bg, TF, {BackgroundTransparency = 0.35}) end)
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
-- P2P SIGNALS  (dot-commands in chat)
-- ─────────────────────────────────────────────────────────
-- Premium users type .fling Player1 etc. in Roblox chat.
-- The target's script watches all whitelisted premium players'
-- chat and executes the command locally on itself.
-- Only premium UserIds can send, only free UserIds are targets.
-- ═══════════════════════════════════════════════════════════

-- Dot-command prefix
local DOT = "."

-- Dummy SendSig so commands module doesn't error — not used anymore
local function SendSig() end

-- ── Execute a dot-command on ourselves ────────────────────────
local function HandleDotCmd(sender, cmd, targetName, extra)
    -- Sender must be premium
    if not premIds[sender.UserId] then return end
    -- We must be free (premium can't be targeted)
    if IsPremium() then return end
    -- Command must be targeting us (by name or display name)
    if targetName then
        local tn   = targetName:lower()
        local name = LP.Name:lower()
        local disp = LP.DisplayName:lower()
        -- exact username, exact displayname, partial username, partial displayname
        local match = (name == tn)
                   or (disp == tn)
                   or (name:find(tn, 1, true) ~= nil)
                   or (disp:find(tn, 1, true) ~= nil)
        if not match then return end
    end

    local c, r, hum
    local function gc()
        c   = LP.Character
        r   = c and c:FindFirstChild("HumanoidRootPart")
        hum = c and c:FindFirstChildOfClass("Humanoid")
    end

    if cmd == "fling" then
        gc() if not r then return end
        local bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(1e9,1e9,1e9)
        bv.Velocity = Vector3.new(math.random(-160,160),350,math.random(-160,160))
        bv.Parent = r
        Debris:AddItem(bv, 0.15)
        Notify("Signal","Flung by "..sender.DisplayName,"warning",3)

    elseif cmd == "bring" then
        gc()
        local sr = sender.Character and sender.Character:FindFirstChild("HumanoidRootPart")
        if r and sr then
            r.CFrame = sr.CFrame * CFrame.new(math.random(-4,4),0,math.random(-4,4))
        end
        Notify("Signal","Brought to "..sender.DisplayName,"info",3)

    elseif cmd == "bringall" then
        -- No target needed — affects all free users
        gc()
        local sr = sender.Character and sender.Character:FindFirstChild("HumanoidRootPart")
        if r and sr then
            r.CFrame = sr.CFrame * CFrame.new(math.random(-8,8),0,math.random(-8,8))
        end
        Notify("Signal","Brought (all) to "..sender.DisplayName,"info",3)

    elseif cmd == "kill" or cmd == "reset" then
        gc() if hum then hum.Health = 0 end
        Notify("Signal","Killed by "..sender.DisplayName,"error",3)

    elseif cmd == "freeze" then
        Config.ActiveCmds["Frozen"] = true RefreshActive() gc()
        if c then
            for _,p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") then p.Anchored = true end
            end
            if hum then hum.PlatformStand = true end
        end
        Notify("Signal","Frozen by "..sender.DisplayName,"warning",4)

    elseif cmd == "unfreeze" then
        Config.ActiveCmds["Frozen"] = nil RefreshActive() gc()
        if c then
            for _,p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") then p.Anchored = false end
            end
            if hum then hum.PlatformStand = false end
        end
        Notify("Signal","Unfrozen by "..sender.DisplayName,"info",3)

    elseif cmd == "kick" then
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

    elseif cmd == "unkick" then
        Config.ActiveCmds["Kicked"] = nil RefreshActive()
        Notify("Signal","Kick stopped","info",3)

    elseif cmd == "control" or cmd == "ctrl" then
        if IsPremium() then return end
        Config.ActiveCmds["Controlled"] = true RefreshActive() gc()
        if c then
            for _,p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") then p.Anchored = true end
            end
            if hum then hum.PlatformStand = true end
        end
        Notify("Signal","Controlled by "..sender.DisplayName,"warning",5)

    elseif cmd == "release" then
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

    elseif cmd == "chat" then
        -- .chat Player1 hello world
        if not extra or extra == "" then return end
        local sent = false
        if not sent then pcall(function()
            local tcs = game:GetService("TextChatService")
            if tcs.ChatVersion == Enum.ChatVersion.TextChatService then
                local ch = tcs.TextChannels:FindFirstChild("RBXGeneral")
                if ch then ch:SendAsync(extra) sent = true end
            end
        end) end
        if not sent then pcall(function()
            local ev  = game:GetService("ReplicatedStorage"):FindFirstChild("DefaultChatSystemChatEvents")
            local sr2 = ev and ev:FindFirstChild("SayMessageRequest")
            if sr2 then sr2:FireServer(extra, "All") end
        end) end
    end
end

-- ── Parse a chat message for dot-commands ─────────────────────
local function OnChat(speaker, msg)
    if not msg or msg == "" then return end
    if not premIds[speaker.UserId] then return end  -- only premium senders

    -- Strip any "Name: " prefix that some chat systems prepend
    local clean = msg:match("^%S+:%s*(.+)$") or msg
    -- Must start with dot
    if clean:sub(1,1) ~= DOT then return end

    -- Split everything after the dot
    local body  = clean:sub(2):match("^%s*(.-)%s*$")  -- trim
    local parts = {}
    for w in body:gmatch("%S+") do table.insert(parts, w) end
    if #parts == 0 then return end

    local cmd        = parts[1]:lower()
    -- targetName is everything from part 2 up to but not including extra words
    -- For .chat the extra is words 3+, for everything else words 2 is target and 3+ is extra
    local targetName = parts[2] or nil
    local extra      = #parts >= 3 and table.concat(parts, " ", 3) or ""

    -- bringall has no target
    if cmd == "bringall" then
        HandleDotCmd(speaker, cmd, nil, "")
        return
    end

    if cmd ~= "" then
        HandleDotCmd(speaker, cmd, targetName, extra)
    end
end

-- ── Hook chat for all whitelisted premium players ──────────────
local function WatchPlayer(player)
    if not premIds[player.UserId] then return end  -- only watch premium players
    player.Chatted:Connect(function(msg)
        task.spawn(OnChat, player, msg)
    end)
end

for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LP then WatchPlayer(p) end
end
Players.PlayerAdded:Connect(function(p)
    if p ~= LP then WatchPlayer(p) end
end)

-- Also hook TextChatService MessageReceived for new chat system
pcall(function()
    local tcs = game:GetService("TextChatService")
    if tcs.ChatVersion == Enum.ChatVersion.TextChatService then
        tcs.MessageReceived:Connect(function(msg)
            local src = msg and msg.TextSource
            if not src then return end
            local p = Players:GetPlayerByUserId(src.UserId)
            if not p or p == LP then return end
            local raw = (msg.OriginalText ~= "") and msg.OriginalText or msg.Text
            task.spawn(OnChat, p, raw)
        end)
    end
end)


-- =========================================================
-- Export detection state for commands module
_VC.vcUsers         = vcUsers
_VC.IsVoidUser      = IsVoidUser
_VC.IsWhitelisted   = IsWhitelisted
_VC.SendSig         = SendSig
_VC.tagData         = tagData

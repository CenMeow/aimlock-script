local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local HttpService      = game:GetService("HttpService")
local LP     = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local SAVE_FILE = "Revenant_tsb.json"
local DEFAULTS = {
    KeyName       = "C",
    FovRadius     = 250,
    Smoothness    = 0.12,
    Prediction    = 0.13,
    TargetPart    = "HumanoidRootPart",
    ShowFOV       = true,
    AntiFling     = false,
    AntiVoid      = false,
    DashEnabled   = true,
    DashCooldown  = 0.35,
    DetectDelay   = 0.18,
    NotifyEnabled = true,
}
local function LoadSave()
    local ok, raw = pcall(function() return readfile and readfile(SAVE_FILE) end)
    if ok and raw then
        local ok2, t = pcall(HttpService.JSONDecode, HttpService, raw)
        if ok2 and type(t) == "table" then return t end
    end
    return {}
end
local saved = LoadSave()
local CFG = {}
for k, v in pairs(DEFAULTS) do CFG[k] = (saved[k] ~= nil) and saved[k] or v end
local function SaveCFG()
    local t = {}; for k in pairs(DEFAULTS) do t[k] = CFG[k] end
    pcall(function() if writefile then writefile(SAVE_FILE, HttpService:JSONEncode(t)) end end)
end
local function ResetCFG()
    for k, v in pairs(DEFAULTS) do CFG[k] = v end
end
local function StrToKey(s)
    local ok, v = pcall(function() return Enum.KeyCode[s] end)
    return (ok and v) or Enum.KeyCode.Unknown
end
local function KeyShort(kc)
    return tostring(kc):gsub("Enum%.KeyCode%.", "")
end
local Loaded       = true
local Conns        = {}
local CamlockOn    = false
local enemy        = nil
local listeningKey = false
local listenTarget = nil
local afConn, avConn, velConn, posConn
local character = LP.Character or LP.CharacterAdded:Wait()
local humanoid  = character:WaitForChild("Humanoid")
local hrp       = character:WaitForChild("HumanoidRootPart")
local lastSafe  = hrp.CFrame
local dashLastTime = 0
local dashRunning  = false
local eventConns   = {}
local function FindEnemy()
    local bestDist, bestPart = math.huge, nil
    local cx = Camera.ViewportSize.X / 2
    local cy = Camera.ViewportSize.Y / 2
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local part = p.Character:FindFirstChild(CFG.TargetPart)
            local hum  = p.Character:FindFirstChildOfClass("Humanoid")
            if part and hum and hum.Health > 0 then
                local sp, vis = Camera:WorldToViewportPoint(part.Position)
                if vis then
                    local d = math.sqrt((sp.X - cx)^2 + (sp.Y - cy)^2)
                    if (CFG.FovRadius <= 0 or d < CFG.FovRadius) and d < bestDist then
                        bestDist = d; bestPart = part
                    end
                end
            end
        end
    end
    return bestPart
end
local function FindClosestEnemyWorld()
    local bestDist = math.huge
    local bestChar = nil
    for _, desc in pairs(workspace:GetDescendants()) do
        if desc:IsA("Model") and desc ~= character then
            local eHRP = desc:FindFirstChild("HumanoidRootPart")
            local eHum = desc:FindFirstChildOfClass("Humanoid")
            if eHRP and eHum and eHum.Health > 0 then
                local ok, dist = pcall(function()
                    return (hrp.Position - eHRP.Position).Magnitude
                end)
                if ok and dist and dist < bestDist then
                    bestDist = dist; bestChar = desc
                end
            end
        end
    end
    return bestChar
end
local notifySG = nil
local function Notify(title, msg, nType)
    if not CFG.NotifyEnabled then return end
    local sg = notifySG
    if not sg then return end
    local cols = {
        info    = Color3.fromRGB(100, 200, 255),
        success = Color3.fromRGB(80,  220, 140),
        warn    = Color3.fromRGB(255, 180,  50),
        dash    = Color3.fromRGB(200, 100, 255),
    }
    local ac = cols[nType or "info"] or cols.info
    task.spawn(function()
        for _, c in ipairs(sg:GetChildren()) do
            if c:IsA("Frame") and c.Name == "TSB_NotifCard" then
                local newY = c.Position.Y.Offset - 68
                TweenService:Create(c, TweenInfo.new(0.18, Enum.EasingStyle.Quart), {
                    Position = UDim2.new(1, -14, 1, newY)
                }):Play()
            end
        end
        local Card = Instance.new("Frame")
        Card.Name             = "TSB_NotifCard"
        Card.Size             = UDim2.new(0, 260, 0, 56)
        Card.AnchorPoint      = Vector2.new(1, 1)
        Card.Position         = UDim2.new(1, 300, 1, -14)
        Card.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
        Card.BorderSizePixel  = 0
        Card.ZIndex           = 600
        Card.ClipsDescendants = true
        Card.Parent           = sg
        Instance.new("UICorner", Card).CornerRadius = UDim.new(0, 8)
        local Bar = Instance.new("Frame")
        Bar.Size             = UDim2.new(0, 4, 1, -14)
        Bar.Position         = UDim2.new(0, 0, 0, 7)
        Bar.BackgroundColor3 = ac
        Bar.BorderSizePixel  = 0
        Bar.ZIndex           = 601
        Bar.Parent           = Card
        Instance.new("UICorner", Bar).CornerRadius = UDim.new(0, 2)
        local TL = Instance.new("TextLabel")
        TL.Size               = UDim2.new(1, -18, 0, 22)
        TL.Position           = UDim2.new(0, 14, 0, 7)
        TL.BackgroundTransparency = 1
        TL.Text               = title
        TL.TextSize           = 12
        TL.Font               = Enum.Font.GothamBold
        TL.TextColor3         = ac
        TL.TextXAlignment     = Enum.TextXAlignment.Left
        TL.ZIndex             = 601
        TL.Parent             = Card
        local ML = Instance.new("TextLabel")
        ML.Size               = UDim2.new(1, -18, 0, 18)
        ML.Position           = UDim2.new(0, 14, 0, 30)
        ML.BackgroundTransparency = 1
        ML.Text               = msg
        ML.TextSize           = 10
        ML.Font               = Enum.Font.GothamMedium
        ML.TextColor3         = Color3.fromRGB(180, 180, 200)
        ML.TextXAlignment     = Enum.TextXAlignment.Left
        ML.ZIndex             = 601
        ML.Parent             = Card
        local PBar = Instance.new("Frame")
        PBar.Size             = UDim2.new(1, 0, 0, 2)
        PBar.Position         = UDim2.new(0, 0, 1, -2)
        PBar.BackgroundColor3 = ac
        PBar.BorderSizePixel  = 0
        PBar.ZIndex           = 601
        PBar.Parent           = Card
        TweenService:Create(Card, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Position = UDim2.new(1, -14, 1, -14)
        }):Play()
        TweenService:Create(PBar, TweenInfo.new(2.8, Enum.EasingStyle.Linear), {
            Size = UDim2.new(0, 0, 0, 2)
        }):Play()
        task.wait(2.8)
        TweenService:Create(Card, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
            Position         = UDim2.new(1, 300, 1, Card.Position.Y.Offset),
            BackgroundTransparency = 1,
        }):Play()
        TweenService:Create(TL, TweenInfo.new(0.2), { TextTransparency = 1 }):Play()
        TweenService:Create(ML, TweenInfo.new(0.2), { TextTransparency = 1 }):Play()
        task.wait(0.25)
        Card:Destroy()
    end)
end
table.insert(Conns, RunService.Heartbeat:Connect(function()
    if not Loaded or not CamlockOn then return end
    if not enemy or not enemy.Parent then enemy = FindEnemy() end
    if not enemy then return end
    local hum = enemy.Parent and enemy.Parent:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then
        enemy = FindEnemy(); if not enemy then return end
    end
    local pred = enemy.Position + enemy.Velocity * CFG.Prediction
    Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, pred), CFG.Smoothness)
end))
local RefreshUI
local function Toggle()
    if listeningKey then return end
    CamlockOn = not CamlockOn
    if CamlockOn then
        enemy = FindEnemy()
        local name = enemy and enemy.Parent and enemy.Parent.Name or "無目標"
        Notify("自瞄已開啟", "目標：" .. name, "success")
    else
        enemy = nil
        Notify("自瞄已關閉", "已停止追蹤", "info")
    end
    if RefreshUI then RefreshUI() end
end
local function CleanupDash()
    task.delay(0.1, function()
        pcall(function()
            local data = {{Dash=Enum.KeyCode.W, Key=Enum.KeyCode.Q, Goal="KeyPress"}}
            if character and character:FindFirstChild("Communicate") then
                character.Communicate:FireServer(unpack(data))
            end
        end)
        pcall(function()
            local function findNil(name, cls)
                if type(getnilinstances) ~= "function" then return nil end
                for _, i in pairs(getnilinstances()) do
                    if i.ClassName == cls and i.Name == name then return i end
                end
            end
            local data = {{Goal="delete bv", BV=findNil("moveme","BodyVelocity")}}
            if character and character:FindFirstChild("Communicate") then
                character.Communicate:FireServer(unpack(data))
            end
        end)
    end)
end
local function ExecuteDash()
    if not character or not humanoid or not hrp then return end
    if dashRunning then return end
    local targetChar = FindClosestEnemyWorld()
    if not targetChar then
        Notify("tech 衝刺", "附近沒有人", "warn"); return
    end
    local tHRP = targetChar:FindFirstChild("HumanoidRootPart")
    if not tHRP then return end
    dashRunning = true
    Notify("tech", "目標" .. targetChar.Name, "dash")
    local saved_ws = humanoid.WalkSpeed
    local saved_jp = humanoid.JumpPower
    local saved_ps = humanoid.PlatformStand
    local saved_ar; pcall(function() saved_ar = humanoid.AutoRotate end)
    local hbConn
    local function Restore()
        if hbConn then pcall(function() hbConn:Disconnect() end); hbConn = nil end
        pcall(function()
            humanoid.WalkSpeed     = saved_ws or 16
            humanoid.JumpPower     = saved_jp or 50
            humanoid.PlatformStand = saved_ps or false
            if saved_ar ~= nil then pcall(function() humanoid.AutoRotate = saved_ar end) end
            hrp.Velocity    = Vector3.zero
            hrp.RotVelocity = Vector3.zero
        end)
        dashRunning = false
    end
    pcall(function()
        humanoid.WalkSpeed = 0; humanoid.JumpPower = 0
        humanoid.PlatformStand = true
        pcall(function() humanoid.AutoRotate = false end)
        hrp.Velocity = Vector3.zero; hrp.RotVelocity = Vector3.zero
    end)
    for _, d in pairs(character:GetDescendants()) do
        local cn = d.ClassName
        if cn=="BodyVelocity" or cn=="BodyPosition" or cn=="BodyGyro" or
           cn=="VectorForce"  or cn=="AlignPosition" or cn=="AlignOrientation" or
           cn=="LinearVelocity" or cn=="AngularVelocity" then
            pcall(function() d:Destroy() end)
        end
    end
    hbConn = RunService.Heartbeat:Connect(function()
        pcall(function()
            hrp.Velocity    = Vector3.zero
            hrp.RotVelocity = Vector3.zero
            humanoid.WalkSpeed = 0
        end)
    end)
    pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Physics) end)
    hrp.CFrame = hrp.CFrame * CFrame.Angles(math.rad(85), 0, 0)
    local startT = tick()
    local dashCon
    dashCon = RunService.Heartbeat:Connect(function()
        if tick() - startT >= 0.7 then dashCon:Disconnect(); return end
        local ok, cf = pcall(function()
            return CFrame.new(tHRP.Position - tHRP.CFrame.LookVector * 0.3)
                   * CFrame.Angles(math.rad(85), 0, 0)
        end)
        if ok and cf then hrp.CFrame = cf end
    end)
    task.delay(0.18, function() pcall(CleanupDash) end)
    task.delay(0.3,  function() pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end) end)
    task.delay(0.7 + 0.3, function() pcall(Restore) end)
end
local function TryDash()
    if not CFG.DashEnabled then return end
    if tick() - dashLastTime < CFG.DashCooldown then return end
    dashLastTime = tick()
    task.spawn(function() pcall(ExecuteDash) end)
end
local function OnAnimPlayed(anim)
    if not anim or not anim.Animation then return end
    if string.find(tostring(anim.Animation.AnimationId or ""), "10503381238", 1, true) then
        task.delay(CFG.DetectDelay, TryDash)
    end
end
local function SetupCharConns(c)
    for _, conn in pairs(eventConns) do pcall(function() conn:Disconnect() end) end
    eventConns = {}
    if not CFG.DashEnabled then return end
    local hum2 = c:FindFirstChildOfClass("Humanoid") or c:WaitForChild("Humanoid", 5)
    if not hum2 then return end
    local ok, con = pcall(function() return hum2.AnimationPlayed:Connect(OnAnimPlayed) end)
    if ok and con then table.insert(eventConns, con) end
    local anim2 = hum2:FindFirstChildOfClass("Animator")
    if anim2 then
        local ok2, con2 = pcall(function() return anim2.AnimationPlayed:Connect(OnAnimPlayed) end)
        if ok2 and con2 then table.insert(eventConns, con2) end
    end
    table.insert(eventConns, c.DescendantAdded:Connect(function(d)
        if d:IsA("Animation") and string.find(tostring(d.AnimationId or ""), "10503381238", 1, true) then
            task.delay(CFG.DetectDelay, TryDash)
        end
    end))
end
local function EnableAF()
    for _, p in pairs(character:GetChildren()) do
        if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
            p.CanCollide = false; p.Velocity = Vector3.zero
        end
    end
    afConn = RunService.Heartbeat:Connect(function()
        for _, p in pairs(character:GetChildren()) do
            if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then p.CanCollide = false end
        end
    end)
    velConn = RunService.Stepped:Connect(function()
        if hrp.Velocity.Magnitude > 50    then hrp.Velocity    = Vector3.zero end
        if hrp.RotVelocity.Magnitude > 50 then hrp.RotVelocity = Vector3.zero end
    end)
    posConn = RunService.Heartbeat:Connect(function()
        if hrp.Velocity.Magnitude < 50 and hrp.RotVelocity.Magnitude < 50 then
            lastSafe = hrp.CFrame
        end
    end)
    pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false) end)
end
local function DisableAF()
    for _, c in pairs({afConn, velConn, posConn}) do
        if c then pcall(function() c:Disconnect() end) end
    end
    afConn = nil; velConn = nil; posConn = nil
    for _, p in pairs(character:GetChildren()) do
        if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then p.CanCollide = true end
    end
    pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true) end)
end
local function EnableAV()
    avConn = RunService.Heartbeat:Connect(function()
        local y = hrp.Position.Y
        if y < -100 or y > 400 then hrp.CFrame = lastSafe end
    end)
end
local function DisableAV()
    if avConn then pcall(function() avConn:Disconnect() end); avConn = nil end
end
LP.CharacterAdded:Connect(function(c)
    character = c; humanoid = c:WaitForChild("Humanoid")
    hrp = c:WaitForChild("HumanoidRootPart"); lastSafe = hrp.CFrame
    if CFG.AntiFling then DisableAF(); EnableAF() end
    if CFG.AntiVoid  then DisableAV(); EnableAV() end
    task.wait(0.1); pcall(SetupCharConns, c)
end)
pcall(SetupCharConns, character)
table.insert(Conns, UserInputService.InputBegan:Connect(function(input, _gp)
    if listeningKey then
        if input.KeyCode == Enum.KeyCode.Escape then
            listeningKey = false; listenTarget = nil
            if _G.TSB_CancelBind then _G.TSB_CancelBind() end
        else
            local ks = KeyShort(input.KeyCode)
            if listenTarget == "aim"  then CFG.KeyName = ks end
            listeningKey = false; listenTarget = nil
            if _G.TSB_FinishBind then _G.TSB_FinishBind(input.KeyCode) end
        end
        return
    end
    if input.KeyCode == StrToKey(CFG.KeyName)     then Toggle() end
end))
local fovCircle
pcall(function()
    fovCircle = Drawing.new("Circle")
    fovCircle.Visible = false; fovCircle.Thickness = 1.5
    fovCircle.Color   = Color3.fromRGB(255, 200, 50)
    fovCircle.Filled  = false; fovCircle.Transparency = 0.7
end)
table.insert(Conns, RunService.RenderStepped:Connect(function()
    if not fovCircle then return end
    if not Loaded then fovCircle.Visible = false; return end
    fovCircle.Position = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    fovCircle.Radius   = math.max(CFG.FovRadius, 1)
    fovCircle.Visible  = CFG.ShowFOV and CFG.FovRadius > 0
end))
local function Unload()
    Loaded = false; CamlockOn = false; enemy = nil
    for _, c in ipairs(Conns) do pcall(function() c:Disconnect() end) end
    for _, c in pairs(eventConns) do pcall(function() c:Disconnect() end) end
    DisableAF(); DisableAV()
    if fovCircle then pcall(function() fovCircle:Remove() end) end
    local g = game:GetService("CoreGui"):FindFirstChild("TSB_v16")
    if g then g:Destroy() end
    print("Revenant 已卸載完成")
end
local T = {
    Window  = Color3.fromRGB(28,  28,  38),
    TopBar  = Color3.fromRGB(20,  20,  30),
    Tab     = Color3.fromRGB(36,  36,  50),
    TabAct  = Color3.fromRGB(52,  52,  72),
    Elem    = Color3.fromRGB(40,  40,  56),
    Border  = Color3.fromRGB(58,  58,  80),
    Accent  = Color3.fromRGB(100, 200, 255),
    AccentD = Color3.fromRGB(40,  90,  130),
    On      = Color3.fromRGB(80,  220, 140),
    Off     = Color3.fromRGB(200, 70,  70),
    Dash    = Color3.fromRGB(200, 100, 255),
    Text    = Color3.fromRGB(228, 228, 240),
    Sub     = Color3.fromRGB(140, 140, 160),
    Track   = Color3.fromRGB(24,  24,  36),
    Knob    = Color3.fromRGB(240, 240, 255),
}
local function mk(cls, props)
    local i = Instance.new(cls)
    for k, v in pairs(props) do i[k] = v end
    return i
end
local function corner(p, r) mk("UICorner", {CornerRadius=UDim.new(0, r or 6), Parent=p}) end
local function stroke(p, col, t)
    return mk("UIStroke", {Color=col or T.Border, Thickness=t or 1,
        ApplyStrokeMode=Enum.ApplyStrokeMode.Border, Parent=p})
end
local function pad(p, a, b, c, d)
    mk("UIPadding", {PaddingTop=UDim.new(0,a), PaddingBottom=UDim.new(0,b),
        PaddingLeft=UDim.new(0,c), PaddingRight=UDim.new(0,d), Parent=p})
end
local function vlist(p, sp)
    return mk("UIListLayout", {FillDirection=Enum.FillDirection.Vertical,
        HorizontalAlignment=Enum.HorizontalAlignment.Left,
        SortOrder=Enum.SortOrder.LayoutOrder,
        Padding=UDim.new(0, sp or 0), Parent=p})
end
local function hlist(p, valign, sp)
    return mk("UIListLayout", {FillDirection=Enum.FillDirection.Horizontal,
        VerticalAlignment=valign or Enum.VerticalAlignment.Center,
        SortOrder=Enum.SortOrder.LayoutOrder,
        Padding=UDim.new(0, sp or 0), Parent=p})
end
local function lbl(p, txt, sz, col, font, xa)
    return mk("TextLabel", {BackgroundTransparency=1, Text=txt, TextSize=sz or 12,
        TextColor3=col or T.Text, Font=font or Enum.Font.GothamMedium,
        TextXAlignment=xa or Enum.TextXAlignment.Left,
        TextYAlignment=Enum.TextYAlignment.Center, Parent=p})
end
local SG = mk("ScreenGui", {
    Name="TSB_v16", ResetOnSpawn=false,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling,
    Parent=game:GetService("CoreGui"),
})
notifySG = SG
local Win = mk("Frame", {
    Name="Win",
    Size=UDim2.new(0, 420, 0, 44),
    Position=UDim2.new(0.5, -210, 0.06, 0),
    BackgroundColor3=T.Window, BorderSizePixel=0,
    Active=true, Draggable=true, ClipsDescendants=true,
    Parent=SG,
})
corner(Win, 8); stroke(Win, T.Border, 1)
vlist(Win, 0)
Win.AutomaticSize = Enum.AutomaticSize.Y
local TopBar = mk("Frame", {
    Size=UDim2.new(1,0,0,46),
    BackgroundColor3=T.TopBar, BorderSizePixel=0, Parent=Win,
})
corner(TopBar, 8)
mk("Frame", {Size=UDim2.new(1,0,0.5,0), Position=UDim2.new(0,0,0.5,0),
    BackgroundColor3=T.TopBar, BorderSizePixel=0, Parent=TopBar})
local TBR = mk("Frame", {Size=UDim2.new(1,0,1,0), BackgroundTransparency=1, Parent=TopBar})
hlist(TBR, Enum.VerticalAlignment.Center, 0); pad(TBR, 0,0,16,14)
local Dot = mk("Frame", {Size=UDim2.new(0,10,0,10), BackgroundColor3=T.Sub, BorderSizePixel=0, Parent=TBR})
corner(Dot, 5)
local TitleLbl = lbl(TBR, "Revenant", 14, T.Text, Enum.Font.GothamBold)
TitleLbl.Size = UDim2.new(1,-96,1,0)
local TBBtns = mk("Frame", {Size=UDim2.new(0,90,1,0), BackgroundTransparency=1, Parent=TBR})
hlist(TBBtns, Enum.VerticalAlignment.Center, 5)
local function SBtn(par, txt, bg, tc)
    local b = mk("TextButton", {Size=UDim2.new(0,36,0,26), BackgroundColor3=bg or T.Tab,
        BorderSizePixel=0, Text=txt, TextColor3=tc or T.Sub,
        Font=Enum.Font.GothamBold, TextSize=12, Parent=par})
    corner(b, 4); stroke(b, T.Border, 1); return b
end
local CFGBtn   = SBtn(TBBtns, "設定", T.Tab, T.Sub)
local CloseBtn = SBtn(TBBtns, "✕", Color3.fromRGB(60,20,20), T.Off)
local PwrRow = mk("Frame", {
    Size=UDim2.new(1,0,0,66),
    BackgroundColor3=T.Elem, BorderSizePixel=0, Parent=Win,
})
pad(PwrRow, 0,0,18,14); hlist(PwrRow, Enum.VerticalAlignment.Center, 0)
local PwrL = mk("Frame", {Size=UDim2.new(1,-96,1,0), BackgroundTransparency=1, Parent=PwrRow})
vlist(PwrL, 3)
local PwrTitle = lbl(PwrL, "鏡頭鎖定", 16, T.Text, Enum.Font.GothamBold)
PwrTitle.Size = UDim2.new(1,0,0,22)
local PwrSub = lbl(PwrL, "按 "..CFG.KeyName.." 切換", 12, T.Sub)
PwrSub.Size = UDim2.new(1,0,0,16)
local PwrBtn = mk("TextButton", {
    Size=UDim2.new(0,78,0,38),
    BackgroundColor3=T.Track, BorderSizePixel=0,
    Text="關閉", TextColor3=T.Off,
    Font=Enum.Font.GothamBold, TextSize=14, Parent=PwrRow,
})
corner(PwrBtn, 6)
local PwrStk = stroke(PwrBtn, T.Off, 1.5)
PwrBtn.MouseButton1Click:Connect(Toggle)
local TabBar = mk("Frame", {
    Size=UDim2.new(1,0,0,40),
    BackgroundColor3=T.TopBar, BorderSizePixel=0,
    Visible=false, Parent=Win,
})
pad(TabBar, 5,5,12,12); hlist(TabBar, Enum.VerticalAlignment.Center, 5)
local PageHolder = mk("Frame", {
    Size=UDim2.new(1,0,0,0),
    AutomaticSize=Enum.AutomaticSize.Y,
    BackgroundTransparency=1, ClipsDescendants=false,
    BorderSizePixel=0, Visible=false, Parent=Win,
})
local BotRow = mk("Frame", {
    Size=UDim2.new(1,0,0,46),
    BackgroundColor3=T.TopBar, BorderSizePixel=0,
    Visible=false, Parent=Win,
})
pad(BotRow, 6,6,12,12); hlist(BotRow, Enum.VerticalAlignment.Center, 8)
local uiToggles  = {}
local uiSliders  = {}
local partSelectRef
local keyBtnRefs = {}
local function ElemRow(par, h)
    local f = mk("Frame", {Size=UDim2.new(1,0,0,h or 46),
        BackgroundColor3=T.Elem, BorderSizePixel=0, Parent=par})
    pad(f, 0,0,12,12); return f
end
local function Section(par, txt, col)
    local f = mk("Frame", {Size=UDim2.new(1,0,0,28), BackgroundTransparency=1, Parent=par})
    pad(f, 0,0,12,12)
    local l = lbl(f, txt, 11, col or T.Accent, Enum.Font.GothamBold)
    l.Size = UDim2.new(1,0,1,0)
end
local function UIToggle(par, labelTxt, cfgKey, onChange)
    local Row = ElemRow(par, 44)
    hlist(Row, Enum.VerticalAlignment.Center, 0)
    local L = lbl(Row, labelTxt, 13, T.Text); L.Size = UDim2.new(1,-58,1,0)
    local state = CFG[cfgKey]
    local Pill = mk("TextButton", {
        Size=UDim2.new(0,52,0,26),
        BackgroundColor3=state and T.On or T.Track,
        BorderSizePixel=0, Text="", AutoButtonColor=false, Parent=Row,
    })
    corner(Pill, 13); stroke(Pill, T.Border, 1)
    local Nub = mk("Frame", {
        Size=UDim2.new(0,20,0,20), AnchorPoint=Vector2.new(0,0.5),
        BackgroundColor3=T.Knob, BorderSizePixel=0,
        Position=state and UDim2.new(1,-22,0.5,0) or UDim2.new(0,3,0.5,0),
        Parent=Pill,
    })
    corner(Nub, 10)
    local function Set(s, noCB)
        state = s; CFG[cfgKey] = s
        TweenService:Create(Pill, TweenInfo.new(0.15), {BackgroundColor3=s and T.On or T.Track}):Play()
        TweenService:Create(Nub,  TweenInfo.new(0.15), {Position=s and UDim2.new(1,-22,0.5,0) or UDim2.new(0,3,0.5,0)}):Play()
        if not noCB and onChange then onChange(s) end
    end
    Pill.MouseButton1Click:Connect(function() Set(not state) end)
    uiToggles[cfgKey] = {set=Set, default=DEFAULTS[cfgKey]}
    if state and onChange then task.defer(function() onChange(state) end) end
end
local function UISlider(par, labelTxt, unit, minV, maxV, dec, cfgKey, accentCol)
    accentCol = accentCol or T.Accent
    local Box = ElemRow(par, 64); vlist(Box, 6)
    local InfoR = mk("Frame", {Size=UDim2.new(1,0,0,18), BackgroundTransparency=1, Parent=Box})
    hlist(InfoR, Enum.VerticalAlignment.Center, 0)
    local Lbl  = lbl(InfoR, labelTxt, 12, T.Sub);  Lbl.Size  = UDim2.new(0.65,0,1,0)
    local ValL = lbl(InfoR, "", 12, accentCol, nil, Enum.TextXAlignment.Right); ValL.Size = UDim2.new(0.35,0,1,0)
    local TBtn = mk("TextButton", {Size=UDim2.new(1,0,0,20),
        BackgroundTransparency=1, Text="", AutoButtonColor=false, Parent=Box})
    local TBG  = mk("Frame", {Size=UDim2.new(1,0,0,6), Position=UDim2.new(0,0,0.5,-3),
        BackgroundColor3=T.Track, BorderSizePixel=0, Parent=TBtn})
    corner(TBG, 2)
    local Fill = mk("Frame", {BackgroundColor3=accentCol, BorderSizePixel=0,
        Size=UDim2.new(0,0,1,0), Parent=TBG}); corner(Fill, 2)
    local Knob = mk("Frame", {Size=UDim2.new(0,18,0,18), AnchorPoint=Vector2.new(0.5,0.5),
        BackgroundColor3=T.Knob, BorderSizePixel=0,
        Position=UDim2.new(0,0,0.5,0), Parent=TBG}); corner(Knob, 9)
    local fmt = "%." .. dec .. "f" .. (unit or "")
    local function Apply(v)
        CFG[cfgKey] = v
        local r = math.clamp((v-minV)/(maxV-minV), 0, 1)
        Fill.Size = UDim2.new(r,0,1,0); Knob.Position = UDim2.new(r,0,0.5,0)
        ValL.Text = string.format(fmt, v)
    end
    Apply(CFG[cfgKey])
    local drag = false
    local function FromX(x)
        local r = math.clamp((x - TBG.AbsolutePosition.X) / TBG.AbsoluteSize.X, 0, 1)
        Apply(minV + (maxV-minV)*r)
    end
    TBtn.MouseButton1Down:Connect(function(x) drag=true; FromX(x) end)
    TBtn.MouseMoved:Connect(function(x) if drag then FromX(x) end end)
    TBtn.MouseButton1Up:Connect(function() drag=false end)
    table.insert(Conns, UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then drag=false end end))
    table.insert(Conns, UserInputService.InputChanged:Connect(function(i)
        if drag and i.UserInputType == Enum.UserInputType.MouseMovement then FromX(i.Position.X) end end))
    uiSliders[cfgKey] = {apply=Apply, default=DEFAULTS[cfgKey]}
end
local function UIPartSelector(par)
    local Box = ElemRow(par, 66); vlist(Box, 6)
    local Lbl = lbl(Box, "目標部位", 12, T.Sub); Lbl.Size = UDim2.new(1,0,0,18)
    local BRow = mk("Frame", {Size=UDim2.new(1,0,0,30), BackgroundTransparency=1, Parent=Box})
    hlist(BRow, Enum.VerticalAlignment.Center, 5)
    local lbls = {"頭","身","腳"}
    local keys = {"Head","UpperTorso","HumanoidRootPart"}
    local btns = {}
    local curIdx = 3
    for i, k in ipairs(keys) do if CFG.TargetPart == k then curIdx=i end end
    local function Sel(idx)
        curIdx=idx; CFG.TargetPart=keys[idx]
        for i, b in ipairs(btns) do
            b.BackgroundColor3 = (i==idx) and T.Accent or T.Track
            b.TextColor3       = (i==idx) and T.Window or T.Sub
        end
    end
    partSelectRef = {sel=Sel, default=3}
    for i = 1, 3 do
        local b = mk("TextButton", {Size=UDim2.new(0,82,1,0),
            BackgroundColor3=T.Track, BorderSizePixel=0,
            Text=lbls[i], TextColor3=T.Sub,
            Font=Enum.Font.GothamMedium, TextSize=11, Parent=BRow})
        corner(b, 4); btns[i]=b
        local ii=i; b.MouseButton1Click:Connect(function() Sel(ii) end)
    end
    Sel(curIdx)
end
local function UIKeyBind(par, labelTxt, cfgKey, tag)
    local Row = ElemRow(par, 44)
    hlist(Row, Enum.VerticalAlignment.Center, 0)
    local L = lbl(Row, labelTxt, 13, T.Text); L.Size = UDim2.new(1,-100,1,0)
    local KB = mk("TextButton", {Size=UDim2.new(0,96,0,30),
        BackgroundColor3=T.Track, BorderSizePixel=0,
        Text=CFG[cfgKey], TextColor3=T.Accent,
        Font=Enum.Font.GothamMedium, TextSize=12, Parent=Row})
    corner(KB, 4); local KBS = stroke(KB, T.AccentD, 1)
    KB.MouseButton1Click:Connect(function()
        if listeningKey then return end
        listeningKey=true; listenTarget=tag
        KB.Text="按鍵..."; KB.TextColor3=Color3.fromRGB(255,240,80)
        KB.BackgroundColor3=Color3.fromRGB(40,36,12); KBS.Color=Color3.fromRGB(180,160,0)
        _G.TSB_FinishBind = function(kc)
            KB.Text=KeyShort(kc); KB.TextColor3=T.Accent
            KB.BackgroundColor3=T.Track; KBS.Color=T.AccentD
            if tag=="aim" then PwrSub.Text="按 "..CFG.KeyName.." 切換" end
            _G.TSB_FinishBind=nil; _G.TSB_CancelBind=nil
        end
        _G.TSB_CancelBind = function()
            KB.Text=CFG[cfgKey]; KB.TextColor3=T.Accent
            KB.BackgroundColor3=T.Track; KBS.Color=T.AccentD
            _G.TSB_FinishBind=nil; _G.TSB_CancelBind=nil
        end
    end)
    keyBtnRefs[cfgKey] = {btn=KB}
end
local tabNames = {"自瞄","anti","tech","設定"}
local tabBtns  = {}
local tabPages = {}
local curTab   = 1
local function ShowTab(idx)
    curTab = idx
    for i, pg in ipairs(tabPages) do pg.Visible = (i==idx) end
    for i, tb in ipairs(tabBtns)  do
        tb.BackgroundColor3 = (i==idx) and T.TabAct or T.Tab
        tb.TextColor3       = (i==idx) and T.Text   or T.Sub
    end
end
for i, name in ipairs(tabNames) do
    local tb = mk("TextButton", {
        Size=UDim2.new(0,82,1,0),
        BackgroundColor3=T.Tab, BorderSizePixel=0,
        Text=name, TextColor3=T.Sub,
        Font=Enum.Font.GothamMedium, TextSize=12,
        Parent=TabBar,
    })
    corner(tb, 4); tabBtns[i]=tb
    local ii=i; tb.MouseButton1Click:Connect(function() ShowTab(ii) end)
end
for i = 1, 4 do
    local pg = mk("Frame", {
        Size=UDim2.new(1,0,0,0),
        AutomaticSize=Enum.AutomaticSize.Y,
        BackgroundTransparency=1, BorderSizePixel=0,
        Visible=false, Parent=PageHolder,
    })
    vlist(pg, 1); tabPages[i] = pg
    if i == 1 then
        Section(pg, "自瞄設定")
        UISlider(pg, "偵測半徑",  "px",  0,   500, 0, "FovRadius",  T.Accent)
        UISlider(pg, "平滑度",    "",    0.01,  1, 2, "Smoothness", Color3.fromRGB(100,200,255))
        UISlider(pg, "速度預測",  "",    0,   0.5, 2, "Prediction", Color3.fromRGB(255,160,80))
        Section(pg, "目標部位")
        UIPartSelector(pg)
        Section(pg, "視野範圍")
        UIToggle(pg, "顯示偵測圓圈", "ShowFOV")
    elseif i == 2 then
        Section(pg, "防護設定")
        UIToggle(pg, "防彈飛", "AntiFling", function(s)
            if s then EnableAF() else DisableAF() end
            Notify(s and "防彈飛已開啟" or "防彈飛已關閉",
                   s and "身體碰撞已鎖定" or "已還原身體碰撞", s and "success" or "info")
        end)
        UIToggle(pg, "防虛空", "AntiVoid", function(s)
            if s then EnableAV() else DisableAV() end
            Notify(s and "防虛空已開啟" or "防虛空已關閉",
                   s and "正在偵測掉落" or "已停止偵測掉落", s and "success" or "info")
        end)
    elseif i == 3 then
        Section(pg, "衝刺設定", T.Dash)
        UIToggle(pg, "偵測Tech動畫", "DashEnabled", function(s)
            if s then
                pcall(SetupCharConns, character)
            else
                for _, conn in pairs(eventConns) do pcall(function() conn:Disconnect() end) end
                eventConns = {}
            end
            Notify(s and "衝刺偵測已開啟" or "衝刺偵測已關閉",
                   s and "正在偵測動畫" or "已停止偵測", s and "dash" or "info")
        end)
        UISlider(pg, "偵測延遲（打中時機）", "s", 0,   0.6, 2, "DetectDelay", Color3.fromRGB(255,160,80))
        UISlider(pg, "衝刺冷卻",           "s", 0.05, 2,  2, "DashCooldown",Color3.fromRGB(255,160,80))
    elseif i == 4 then
        Section(pg, "按鍵綁定")
        UIKeyBind(pg, "自瞄開關鍵",  "KeyName",    "aim")
        Section(pg, "通知設定")
        UIToggle(pg, "啟用通知", "NotifyEnabled")
    end
end
local function BotBtn(par, txt, bg, tc)
    local b = mk("TextButton", {Size=UDim2.new(0.5,-4,1,0),
        BackgroundColor3=bg, BorderSizePixel=0,
        Text=txt, TextColor3=tc,
        Font=Enum.Font.GothamBold, TextSize=12, Parent=par})
    corner(b, 5); return b
end
local SaveBtn  = BotBtn(BotRow, "💾  儲存",  Color3.fromRGB(20,44,22), T.On)
local ResetBtn = BotBtn(BotRow, "↺  還原", Color3.fromRGB(44,20,20), T.Off)
stroke(SaveBtn,  Color3.fromRGB(40,120,50), 1)
stroke(ResetBtn, Color3.fromRGB(120,40,40), 1)
SaveBtn.MouseButton1Click:Connect(function()
    SaveCFG()
    local o=SaveBtn.Text; SaveBtn.Text="✓  已儲存"; SaveBtn.TextColor3=T.Accent
    Notify("設定已儲存", "下次載入將自動套用", "success")
    task.delay(1.5, function() SaveBtn.Text=o; SaveBtn.TextColor3=T.On end)
end)
ResetBtn.MouseButton1Click:Connect(function()
    ResetCFG()
    for k, r in pairs(uiSliders)  do r.apply(DEFAULTS[k]) end
    for k, r in pairs(uiToggles)  do r.set(DEFAULTS[k], false) end
    if partSelectRef then partSelectRef.sel(partSelectRef.default) end
    for k, r in pairs(keyBtnRefs) do r.btn.Text = DEFAULTS[k] end
    PwrSub.Text = "按 "..DEFAULTS.KeyName.." 切換"
    Notify("設定已還原", "所有設定已恢復預設", "warn")
    local o=ResetBtn.Text; ResetBtn.Text="✓  完成"; ResetBtn.TextColor3=T.Accent
    task.delay(1.5, function() ResetBtn.Text=o; ResetBtn.TextColor3=T.Off end)
end)
RefreshUI = function()
    if CamlockOn then
        Dot.BackgroundColor3 = T.On;  PwrSub.Text = "追蹤中..."
        PwrBtn.Text="開啟";  PwrBtn.TextColor3=T.On
        PwrBtn.BackgroundColor3=Color3.fromRGB(10,36,20); PwrStk.Color=T.On
    else
        Dot.BackgroundColor3 = T.Sub; PwrSub.Text = "按 "..CFG.KeyName.." 切換"
        PwrBtn.Text="關閉"; PwrBtn.TextColor3=T.Off
        PwrBtn.BackgroundColor3=T.Track; PwrStk.Color=T.Off
    end
end
CFGBtn.MouseButton1Click:Connect(function()
    local open = not TabBar.Visible
    TabBar.Visible     = open
    PageHolder.Visible = open
    BotRow.Visible     = open
    if open then ShowTab(curTab) end
end)
CloseBtn.MouseButton1Click:Connect(Unload)
ShowTab(1)
RefreshUI()
task.defer(function()
    Notify("Revenant 已載入", saved and "已讀取儲存的設定" or "使用預設設定", "success")
end)
print("Revenant 已載入完成")

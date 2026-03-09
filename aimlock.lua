-- ╔══════════════════════════════════════╗
-- ║       TSB 自瞄輔助  v10             ║
-- ║   手把 + 鍵盤  |  繁體中文介面      ║
-- ╚══════════════════════════════════════╝

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local GuiService       = game:GetService("GuiService")

local LP     = Players.LocalPlayer
local Camera = workspace.CurrentCamera

getgenv().AimCFG = {
    GamepadKey  = Enum.KeyCode.ButtonR3,
    KeyboardKey = Enum.KeyCode.C,
    FovRadius   = 250,
    Smoothness  = 0.12,
    Prediction  = 0.13,
    TargetPart  = "HumanoidRootPart",
    ShowFOV     = true,
    FOVColor    = Color3.fromRGB(0, 200, 255),
}

local CamlockState  = false
local enemy         = nil
local Loaded        = true
local Conns         = {}
local listeningKey  = false   -- 是否正在等待按鍵輸入

-- ══════════════════════════════════════
--  找最近敵人
-- ══════════════════════════════════════
local function FindNearestEnemy()
    local ClosestDistance = math.huge
    local ClosestPlayer   = nil
    local CenterPosition  = Vector2.new(
        GuiService:GetScreenResolution().X / 2,
        GuiService:GetScreenResolution().Y / 2
    )
    for _, Player in ipairs(Players:GetPlayers()) do
        if Player ~= LP then
            local Character = Player.Character
            local part      = Character and Character:FindFirstChild(getgenv().AimCFG.TargetPart)
            local hum       = Character and Character:FindFirstChild("Humanoid")
            if part and hum and hum.Health > 0 then
                local Position, IsVisible = Camera:WorldToViewportPoint(part.Position)
                if IsVisible then
                    local Distance = (CenterPosition - Vector2.new(Position.X, Position.Y)).Magnitude
                    local inFov    = getgenv().AimCFG.FovRadius <= 0
                                  or Distance < getgenv().AimCFG.FovRadius
                    if inFov and Distance < ClosestDistance then
                        ClosestPlayer   = part
                        ClosestDistance = Distance
                    end
                end
            end
        end
    end
    return ClosestPlayer
end

-- ══════════════════════════════════════
--  鏡頭跟隨
-- ══════════════════════════════════════
table.insert(Conns, RunService.Heartbeat:Connect(function()
    if not Loaded or not CamlockState then return end
    if not enemy or not enemy.Parent then
        enemy = FindNearestEnemy()
    end
    if not enemy then return end
    local hum = enemy.Parent and enemy.Parent:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then
        enemy = nil; CamlockState = false
        if _G.AimUI_Refresh then _G.AimUI_Refresh() end
        return
    end
    local predictedPos = enemy.Position + enemy.Velocity * getgenv().AimCFG.Prediction
    local targetCF     = CFrame.new(Camera.CFrame.Position, predictedPos)
    Camera.CFrame      = Camera.CFrame:Lerp(targetCF, getgenv().AimCFG.Smoothness)
end))

-- ══════════════════════════════════════
--  開關 / 卸載
-- ══════════════════════════════════════
local function Toggle()
    if listeningKey then return end  -- 等待按鍵時不觸發開關
    CamlockState = not CamlockState
    if CamlockState then
        enemy = FindNearestEnemy()
        if not enemy then CamlockState = false end
    else
        enemy = nil
    end
    if _G.AimUI_Refresh then _G.AimUI_Refresh() end
end

local function Unload()
    Loaded = false; CamlockState = false; enemy = nil
    for _, c in ipairs(Conns) do pcall(function() c:Disconnect() end) end
    if _G.AimFovCircle then pcall(function() _G.AimFovCircle:Remove() end) end
    local gui = game:GetService("CoreGui"):FindFirstChild("TSB_AimAssist_v10")
    if gui then gui:Destroy() end
    getgenv().AimCFG = nil
    _G.AimUI_Refresh = nil
    _G.AimFovCircle  = nil
    print("[TSB 自瞄] 已卸載")
end

-- 按鍵監聽
table.insert(Conns, UserInputService.InputBegan:Connect(function(input, gp)
    -- 等待重新綁定時，攔截任何按鍵
    if listeningKey then
        -- ESC = 取消
        if input.KeyCode == Enum.KeyCode.Escape then
            listeningKey = false
            if _G.AimUI_CancelBind then _G.AimUI_CancelBind() end
            return
        end
        -- 手把按鍵
        if input.UserInputType == Enum.UserInputType.Gamepad1 then
            getgenv().AimCFG.GamepadKey = input.KeyCode
        else
            getgenv().AimCFG.KeyboardKey = input.KeyCode
        end
        listeningKey = false
        if _G.AimUI_FinishBind then _G.AimUI_FinishBind(input) end
        return
    end

    if gp then return end
    if input.KeyCode == getgenv().AimCFG.GamepadKey
    or input.KeyCode == getgenv().AimCFG.KeyboardKey then
        Toggle()
    end
end))

-- ══════════════════════════════════════
--  FOV 圓圈
-- ══════════════════════════════════════
local function ScreenCenter()
    local r = GuiService:GetScreenResolution()
    return Vector2.new(r.X / 2, r.Y / 2)
end

local ok, FovCircle = pcall(function()
    local c = Drawing.new("Circle")
    c.Visible = false; c.Radius = 200
    c.Thickness = 1.2; c.Color = getgenv().AimCFG.FOVColor
    c.Filled = false; c.Transparency = 0.75
    return c
end)
if not ok then FovCircle = nil end
_G.AimFovCircle = FovCircle

table.insert(Conns, RunService.RenderStepped:Connect(function()
    if not FovCircle then return end
    if not Loaded then FovCircle.Visible = false; return end
    FovCircle.Position = ScreenCenter()
    FovCircle.Radius   = math.max(getgenv().AimCFG.FovRadius, 1)
    FovCircle.Visible  = getgenv().AimCFG.ShowFOV and getgenv().AimCFG.FovRadius > 0
    FovCircle.Color    = getgenv().AimCFG.FOVColor
end))

-- ══════════════════════════════════════
--  UI
-- ══════════════════════════════════════
local SG = Instance.new("ScreenGui")
SG.Name           = "TSB_AimAssist_v10"
SG.ResetOnSpawn   = false
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.Parent         = game:GetService("CoreGui")

local CLR = {
    BG      = Color3.fromRGB(8,   10,  18),
    Panel   = Color3.fromRGB(13,  15,  26),
    Border  = Color3.fromRGB(30,  35,  60),
    Cyan    = Color3.fromRGB(0,   200, 255),
    Red     = Color3.fromRGB(255,  60, 100),
    Dim     = Color3.fromRGB(80,   90, 120),
    Track   = Color3.fromRGB(20,   22,  38),
    White   = Color3.fromRGB(220, 225, 255),
    Orange  = Color3.fromRGB(255, 160,  50),
    ResizeH = Color3.fromRGB(45,   52,  85),
    Yellow  = Color3.fromRGB(255, 220,  50),
}

local function RC(p, r)
    local u = Instance.new("UICorner")
    u.CornerRadius = UDim.new(0, r or 8); u.Parent = p
end
local function MkStroke(p, col, thick)
    local s = Instance.new("UIStroke")
    s.Color = col or CLR.Border; s.Thickness = thick or 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = p; return s
end
local function Pad(p, t, b, l, r)
    local u = Instance.new("UIPadding")
    u.PaddingTop    = UDim.new(0, t or 0)
    u.PaddingBottom = UDim.new(0, b or 0)
    u.PaddingLeft   = UDim.new(0, l or 0)
    u.PaddingRight  = UDim.new(0, r or 0)
    u.Parent = p
end

-- 把 KeyCode 轉成簡短顯示文字
local function KeyName(kc)
    local s = tostring(kc):gsub("Enum.KeyCode.", "")
    -- 縮短常見名稱
    local short = {
        LeftShift="LShift", RightShift="RShift",
        LeftControl="LCtrl", RightControl="RCtrl",
        LeftAlt="LAlt", RightAlt="RAlt",
        ButtonR3="R3", ButtonL3="L3",
        ButtonA="A(手把)", ButtonB="B(手把)",
        ButtonX="X(手把)", ButtonY="Y(手把)",
    }
    return short[s] or s
end

local WIN_MIN_W = 200
local WIN_MAX_W = 460
local WIN_MIN_H = 34
local currentW  = 280
local minimized = false
local settOpen  = false

-- 主視窗
local Win = Instance.new("Frame")
Win.Name             = "Win"
Win.Size             = UDim2.new(0, currentW, 0, 40)
Win.Position         = UDim2.new(0.5, -currentW/2, 0.06, 0)
Win.BackgroundColor3 = CLR.BG
Win.BorderSizePixel  = 0
Win.Active           = true
Win.Draggable        = true
Win.ClipsDescendants = true
Win.Parent           = SG
RC(Win, 12); MkStroke(Win, CLR.Border, 1)

local WinList = Instance.new("UIListLayout")
WinList.FillDirection = Enum.FillDirection.Vertical
WinList.Padding       = UDim.new(0, 5)
WinList.Parent        = Win
Pad(Win, 8, 10, 12, 12)

local function ApplyWinH(animated)
    local h = minimized and WIN_MIN_H or (WinList.AbsoluteContentSize.Y + 20)
    local t = {Size = UDim2.new(0, currentW, 0, h)}
    if animated then
        TweenService:Create(Win, TweenInfo.new(0.2, Enum.EasingStyle.Quart), t):Play()
    else
        Win.Size = t.Size
    end
end

-- 標題列
local TitleBar = Instance.new("Frame")
TitleBar.Size               = UDim2.new(1, 0, 0, 22)
TitleBar.BackgroundTransparency = 1
TitleBar.Parent             = Win

local TBarL = Instance.new("UIListLayout")
TBarL.FillDirection     = Enum.FillDirection.Horizontal
TBarL.VerticalAlignment = Enum.VerticalAlignment.Center
TBarL.Padding           = UDim.new(0, 6)
TBarL.Parent            = TitleBar

local Dot = Instance.new("Frame")
Dot.Size             = UDim2.new(0, 8, 0, 8)
Dot.BackgroundColor3 = CLR.Dim
Dot.BorderSizePixel  = 0
Dot.Parent           = TitleBar
RC(Dot, 8)

local TitleTxt = Instance.new("TextLabel")
TitleTxt.Size               = UDim2.new(0, 110, 1, 0)
TitleTxt.BackgroundTransparency = 1
TitleTxt.Text               = "TSB 自瞄"
TitleTxt.TextColor3         = CLR.Dim
TitleTxt.Font               = Enum.Font.Code
TitleTxt.TextSize           = 12
TitleTxt.TextXAlignment     = Enum.TextXAlignment.Left
TitleTxt.Parent             = TitleBar

local StatusTxt = Instance.new("TextLabel")
StatusTxt.Size              = UDim2.new(0, 55, 1, 0)
StatusTxt.BackgroundTransparency = 1
StatusTxt.Text              = "已關閉"
StatusTxt.TextColor3        = CLR.Dim
StatusTxt.Font              = Enum.Font.Code
StatusTxt.TextSize          = 10
StatusTxt.TextXAlignment    = Enum.TextXAlignment.Right
StatusTxt.Parent            = TitleBar

local Spacer = Instance.new("Frame")
Spacer.BackgroundTransparency = 1
Spacer.Size  = UDim2.new(1, -245, 1, 0)
Spacer.Parent = TitleBar

local MinBtn = Instance.new("TextButton")
MinBtn.Size             = UDim2.new(0, 20, 0, 20)
MinBtn.BackgroundColor3 = Color3.fromRGB(20, 24, 42)
MinBtn.BorderSizePixel  = 0
MinBtn.Text             = "-"
MinBtn.TextColor3       = CLR.Dim
MinBtn.Font             = Enum.Font.Code
MinBtn.TextSize         = 16
MinBtn.Parent           = TitleBar
RC(MinBtn, 4); MkStroke(MinBtn, CLR.Border, 1)

local UnloadBtn = Instance.new("TextButton")
UnloadBtn.Size             = UDim2.new(0, 20, 0, 20)
UnloadBtn.BackgroundColor3 = Color3.fromRGB(40, 12, 18)
UnloadBtn.BorderSizePixel  = 0
UnloadBtn.Text             = "x"
UnloadBtn.TextColor3       = CLR.Red
UnloadBtn.Font             = Enum.Font.Code
UnloadBtn.TextSize         = 14
UnloadBtn.Parent           = TitleBar
RC(UnloadBtn, 4); MkStroke(UnloadBtn, CLR.Red, 1)

UnloadBtn.MouseButton1Click:Connect(Unload)
MinBtn.MouseButton1Click:Connect(function()
    minimized   = not minimized
    MinBtn.Text = minimized and "+" or "-"
    for _, child in ipairs(Win:GetChildren()) do
        if child ~= TitleBar and child:IsA("GuiObject") then
            child.Visible = not minimized
        end
    end
    ApplyWinH(true)
end)

-- 主開關按鈕
local MainBtn = Instance.new("TextButton")
MainBtn.Size             = UDim2.new(1, 0, 0, 38)
MainBtn.BackgroundColor3 = Color3.fromRGB(10, 4, 12)
MainBtn.BorderSizePixel  = 0
MainBtn.Text             = "自瞄  關閉"
MainBtn.TextColor3       = CLR.Red
MainBtn.Font             = Enum.Font.Code
MainBtn.TextSize         = 13
MainBtn.Parent           = Win
RC(MainBtn, 8)
local MainStroke = MkStroke(MainBtn, CLR.Red, 1)
MainBtn.MouseButton1Click:Connect(Toggle)

_G.AimUI_Refresh = function()
    if CamlockState then
        Dot.BackgroundColor3     = CLR.Cyan
        StatusTxt.Text           = "鎖定中"
        StatusTxt.TextColor3     = CLR.Cyan
        MainBtn.Text             = "自瞄  開啟"
        MainBtn.TextColor3       = CLR.Cyan
        MainBtn.BackgroundColor3 = Color3.fromRGB(0, 15, 22)
        MainStroke.Color         = CLR.Cyan
    else
        Dot.BackgroundColor3     = CLR.Dim
        StatusTxt.Text           = "已關閉"
        StatusTxt.TextColor3     = CLR.Dim
        MainBtn.Text             = "自瞄  關閉"
        MainBtn.TextColor3       = CLR.Red
        MainBtn.BackgroundColor3 = Color3.fromRGB(10, 4, 12)
        MainStroke.Color         = CLR.Red
    end
end

-- 設定按鈕
local SettBtn = Instance.new("TextButton")
SettBtn.Size                 = UDim2.new(1, 0, 0, 26)
SettBtn.BackgroundTransparency = 1
SettBtn.Text                 = "  設定  v"
SettBtn.TextColor3           = CLR.Dim
SettBtn.Font                 = Enum.Font.Code
SettBtn.TextSize             = 11
SettBtn.Parent               = Win
MkStroke(SettBtn, CLR.Border, 1); RC(SettBtn, 8)

-- 設定面板
local SP = Instance.new("Frame")
SP.Size              = UDim2.new(1, 0, 0, 0)
SP.BackgroundColor3  = CLR.Panel
SP.BorderSizePixel   = 0
SP.ClipsDescendants  = true
SP.Visible           = false
SP.Parent            = Win
RC(SP, 8)

local SPL = Instance.new("UIListLayout")
SPL.Padding = UDim.new(0, 8); SPL.Parent = SP
Pad(SP, 10, 12, 10, 10)

-- ════════════════════════════
--  按鍵綁定元件
-- ════════════════════════════
local function MakeKeyBind(parent, label, getKey, onBind)
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, 0, 0, 26)
    Row.BackgroundTransparency = 1; Row.Parent = parent

    local Lbl = Instance.new("TextLabel")
    Lbl.Size = UDim2.new(0.5, 0, 1, 0); Lbl.BackgroundTransparency = 1
    Lbl.Text = label; Lbl.TextColor3 = CLR.Dim
    Lbl.Font = Enum.Font.Code; Lbl.TextSize = 10
    Lbl.TextXAlignment = Enum.TextXAlignment.Left; Lbl.Parent = Row

    local KeyBtn = Instance.new("TextButton")
    KeyBtn.Size             = UDim2.new(0.5, 0, 1, 0)
    KeyBtn.Position         = UDim2.new(0.5, 0, 0, 0)
    KeyBtn.BackgroundColor3 = CLR.Track
    KeyBtn.BorderSizePixel  = 0
    KeyBtn.Text             = KeyName(getKey())
    KeyBtn.TextColor3       = CLR.Cyan
    KeyBtn.Font             = Enum.Font.Code
    KeyBtn.TextSize         = 10
    KeyBtn.Parent           = Row
    RC(KeyBtn, 5); MkStroke(KeyBtn, CLR.Border, 1)
    local KeyStroke = KeyBtn:FindFirstChildOfClass("UIStroke")

    -- 點擊後進入監聽狀態
    KeyBtn.MouseButton1Click:Connect(function()
        if listeningKey then return end
        listeningKey        = true
        KeyBtn.Text         = "按下按鍵..."
        KeyBtn.TextColor3   = CLR.Yellow
        KeyBtn.BackgroundColor3 = Color3.fromRGB(28, 24, 8)
        if KeyStroke then KeyStroke.Color = CLR.Yellow end

        -- 完成綁定
        _G.AimUI_FinishBind = function(input)
            local newKey = input.KeyCode
            onBind(newKey)
            KeyBtn.Text         = KeyName(newKey)
            KeyBtn.TextColor3   = CLR.Cyan
            KeyBtn.BackgroundColor3 = CLR.Track
            if KeyStroke then KeyStroke.Color = CLR.Border end
            _G.AimUI_FinishBind = nil
            _G.AimUI_CancelBind = nil
        end

        -- 取消綁定（ESC）
        _G.AimUI_CancelBind = function()
            KeyBtn.Text         = KeyName(getKey())
            KeyBtn.TextColor3   = CLR.Cyan
            KeyBtn.BackgroundColor3 = CLR.Track
            if KeyStroke then KeyStroke.Color = CLR.Border end
            _G.AimUI_FinishBind = nil
            _G.AimUI_CancelBind = nil
        end
    end)

    return KeyBtn
end

-- ════════════════════════════
--  滑桿元件
-- ════════════════════════════
local function MakeSlider(parent, label, minV, maxV, defaultV, dec, accentCol, callback)
    accentCol = accentCol or CLR.Cyan
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, 0, 0, 38)
    Row.BackgroundTransparency = 1; Row.Parent = parent

    local RL = Instance.new("UIListLayout")
    RL.FillDirection = Enum.FillDirection.Vertical
    RL.Padding = UDim.new(0, 5); RL.Parent = Row

    local InfoRow = Instance.new("Frame")
    InfoRow.Size = UDim2.new(1, 0, 0, 13)
    InfoRow.BackgroundTransparency = 1; InfoRow.Parent = Row

    local Lbl = Instance.new("TextLabel")
    Lbl.Size = UDim2.new(0.68, 0, 1, 0); Lbl.BackgroundTransparency = 1
    Lbl.Text = label; Lbl.TextColor3 = CLR.Dim
    Lbl.Font = Enum.Font.Code; Lbl.TextSize = 10
    Lbl.TextXAlignment = Enum.TextXAlignment.Left; Lbl.Parent = InfoRow

    local ValLbl = Instance.new("TextLabel")
    ValLbl.Size = UDim2.new(0.32, 0, 1, 0)
    ValLbl.Position = UDim2.new(0.68, 0, 0, 0)
    ValLbl.BackgroundTransparency = 1; ValLbl.TextColor3 = accentCol
    ValLbl.Font = Enum.Font.Code; ValLbl.TextSize = 10
    ValLbl.TextXAlignment = Enum.TextXAlignment.Right; ValLbl.Parent = InfoRow

    local TrackBtn = Instance.new("TextButton")
    TrackBtn.Size = UDim2.new(1, 0, 0, 16)
    TrackBtn.BackgroundTransparency = 1
    TrackBtn.Text = ""; TrackBtn.AutoButtonColor = false; TrackBtn.Parent = Row

    local TrackBG = Instance.new("Frame")
    TrackBG.Size = UDim2.new(1, 0, 0, 6)
    TrackBG.Position = UDim2.new(0, 0, 0.5, -3)
    TrackBG.BackgroundColor3 = CLR.Track; TrackBG.BorderSizePixel = 0
    TrackBG.Parent = TrackBtn; RC(TrackBG, 3)

    local Fill = Instance.new("Frame")
    Fill.BackgroundColor3 = accentCol; Fill.BorderSizePixel = 0
    Fill.Size = UDim2.new((defaultV-minV)/(maxV-minV), 0, 1, 0)
    Fill.Parent = TrackBG; RC(Fill, 3)

    local Knob = Instance.new("Frame")
    Knob.Size = UDim2.new(0, 14, 0, 14)
    Knob.AnchorPoint = Vector2.new(0.5, 0.5)
    Knob.BackgroundColor3 = CLR.White; Knob.BorderSizePixel = 0
    Knob.Position = UDim2.new((defaultV-minV)/(maxV-minV), 0, 0.5, 0)
    Knob.Parent = TrackBG; RC(Knob, 7)

    local fmt = "%." .. tostring(dec) .. "f"
    ValLbl.Text = string.format(fmt, defaultV)

    local dragging = false
    local function UpdateFromX(x)
        local rel = math.clamp((x - TrackBG.AbsolutePosition.X) / TrackBG.AbsoluteSize.X, 0, 1)
        local val = minV + (maxV - minV) * rel
        Fill.Size     = UDim2.new(rel, 0, 1, 0)
        Knob.Position = UDim2.new(rel, 0, 0.5, 0)
        ValLbl.Text   = string.format(fmt, val)
        callback(val)
    end

    TrackBtn.MouseButton1Down:Connect(function(x) dragging = true;  UpdateFromX(x) end)
    TrackBtn.MouseMoved:Connect(function(x)       if dragging then  UpdateFromX(x) end end)
    TrackBtn.MouseButton1Up:Connect(function()    dragging = false end)
    table.insert(Conns, UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end))
    table.insert(Conns, UserInputService.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            UpdateFromX(i.Position.X)
        end
    end))
end

-- ════════════════════════════
--  開關元件
-- ════════════════════════════
local function MakeToggleRow(parent, label, default, callback)
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, 0, 0, 24)
    Row.BackgroundTransparency = 1; Row.Parent = parent

    local Lbl = Instance.new("TextLabel")
    Lbl.Size = UDim2.new(0.72, 0, 1, 0); Lbl.BackgroundTransparency = 1
    Lbl.Text = label; Lbl.TextColor3 = CLR.Dim
    Lbl.Font = Enum.Font.Code; Lbl.TextSize = 10
    Lbl.TextXAlignment = Enum.TextXAlignment.Left; Lbl.Parent = Row

    local state = default
    local Pill = Instance.new("TextButton")
    Pill.Size = UDim2.new(0, 38, 0, 18)
    Pill.Position = UDim2.new(1, -38, 0.5, -9)
    Pill.BackgroundColor3 = state and CLR.Cyan or CLR.Track
    Pill.BorderSizePixel = 0; Pill.Text = ""; Pill.AutoButtonColor = false
    Pill.Parent = Row; RC(Pill, 9)

    local PK = Instance.new("Frame")
    PK.Size = UDim2.new(0, 13, 0, 13); PK.AnchorPoint = Vector2.new(0, 0.5)
    PK.BackgroundColor3 = CLR.White; PK.BorderSizePixel = 0
    PK.Position = state and UDim2.new(1,-15,0.5,0) or UDim2.new(0,2,0.5,0)
    PK.Parent = Pill; RC(PK, 7)

    Pill.MouseButton1Click:Connect(function()
        state = not state
        TweenService:Create(Pill, TweenInfo.new(0.18), {
            BackgroundColor3 = state and CLR.Cyan or CLR.Track
        }):Play()
        TweenService:Create(PK, TweenInfo.new(0.18), {
            Position = state and UDim2.new(1,-15,0.5,0) or UDim2.new(0,2,0.5,0)
        }):Play()
        callback(state)
    end)
end

-- ════════════════════════════
--  目標部位選擇
-- ════════════════════════════
local function MakePartSelector(parent)
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, 0, 0, 44)
    Row.BackgroundTransparency = 1; Row.Parent = parent

    local RL = Instance.new("UIListLayout")
    RL.FillDirection = Enum.FillDirection.Vertical
    RL.Padding = UDim.new(0, 5); RL.Parent = Row

    local Lbl = Instance.new("TextLabel")
    Lbl.Size = UDim2.new(1, 0, 0, 13); Lbl.BackgroundTransparency = 1
    Lbl.Text = "目標部位"; Lbl.TextColor3 = CLR.Dim
    Lbl.Font = Enum.Font.Code; Lbl.TextSize = 10
    Lbl.TextXAlignment = Enum.TextXAlignment.Left; Lbl.Parent = Row

    local BtnRow = Instance.new("Frame")
    BtnRow.Size = UDim2.new(1, 0, 0, 24)
    BtnRow.BackgroundTransparency = 1; BtnRow.Parent = Row

    local BtnL = Instance.new("UIListLayout")
    BtnL.FillDirection = Enum.FillDirection.Horizontal
    BtnL.Padding = UDim.new(0, 6); BtnL.Parent = BtnRow

    local parts    = {"頭",  "身體",       "腳"}
    local partKeys = {"Head", "UpperTorso", "HumanoidRootPart"}
    local btns     = {}

    local function SelectPart(idx)
        getgenv().AimCFG.TargetPart = partKeys[idx]
        for i, b in ipairs(btns) do
            b.BackgroundColor3 = (i == idx) and CLR.Cyan or CLR.Track
            b.TextColor3       = (i == idx) and CLR.BG   or CLR.Dim
        end
    end

    for i = 1, #parts do
        local btn = Instance.new("TextButton")
        btn.Size             = UDim2.new(0, 60, 1, 0)
        btn.BackgroundColor3 = CLR.Track
        btn.BorderSizePixel  = 0
        btn.Text             = parts[i]
        btn.TextColor3       = CLR.Dim
        btn.Font             = Enum.Font.Code
        btn.TextSize         = 10
        btn.Parent           = BtnRow
        RC(btn, 5)
        btns[i] = btn
        local idx = i
        btn.MouseButton1Click:Connect(function() SelectPart(idx) end)
    end
    SelectPart(3)
end

-- ════════════════════════════
--  分隔線
-- ════════════════════════════
local function MakeDivider(parent, labelText)
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, 0, 0, 16)
    Row.BackgroundTransparency = 1; Row.Parent = parent

    local Line = Instance.new("Frame")
    Line.Size = UDim2.new(1, 0, 0, 1)
    Line.Position = UDim2.new(0, 0, 0.5, 0)
    Line.BackgroundColor3 = CLR.Border; Line.BorderSizePixel = 0
    Line.Parent = Row

    if labelText then
        local Tag = Instance.new("TextLabel")
        Tag.Size = UDim2.new(0, 80, 1, 0)
        Tag.Position = UDim2.new(0.5, -40, 0, 0)
        Tag.BackgroundColor3 = CLR.Panel; Tag.BorderSizePixel = 0
        Tag.Text = labelText; Tag.TextColor3 = CLR.Dim
        Tag.Font = Enum.Font.Code; Tag.TextSize = 9
        Tag.Parent = Row
    end
end

-- ════════════════════════════
--  建立所有設定
-- ════════════════════════════

-- 按鍵綁定區塊
MakeDivider(SP, " 按鍵設定 ")
MakeKeyBind(SP, "鍵盤開關鍵",
    function() return getgenv().AimCFG.KeyboardKey end,
    function(k) getgenv().AimCFG.KeyboardKey = k end)

MakeDivider(SP, " 自瞄設定 ")
MakeSlider(SP, "偵測半徑", 0, 500, getgenv().AimCFG.FovRadius, 0, CLR.Cyan,
    function(v) getgenv().AimCFG.FovRadius  = v end)
MakeSlider(SP, "平滑度（小=慢/大=快）", 0.01, 1, getgenv().AimCFG.Smoothness, 2, CLR.Cyan,
    function(v) getgenv().AimCFG.Smoothness = v end)
MakeSlider(SP, "速度預測量", 0, 0.5, getgenv().AimCFG.Prediction, 2, CLR.Orange,
    function(v) getgenv().AimCFG.Prediction = v end)

MakeDivider(SP, " 其他 ")
MakePartSelector(SP)
MakeToggleRow(SP, "顯示 FOV 圓圈", getgenv().AimCFG.ShowFOV,
    function(v) getgenv().AimCFG.ShowFOV = v end)

-- 展開 / 收合
SettBtn.MouseButton1Click:Connect(function()
    settOpen = not settOpen
    if settOpen then
        SP.Visible = true
        local h = SPL.AbsoluteContentSize.Y + 24
        TweenService:Create(SP, TweenInfo.new(0.25, Enum.EasingStyle.Quart),
            {Size = UDim2.new(1, 0, 0, h)}):Play()
        SettBtn.Text = "  設定  ^"
    else
        TweenService:Create(SP, TweenInfo.new(0.2, Enum.EasingStyle.Quart),
            {Size = UDim2.new(1, 0, 0, 0)}):Play()
        task.delay(0.22, function() SP.Visible = false end)
        SettBtn.Text = "  設定  v"
    end
    task.defer(function() ApplyWinH(true) end)
end)

-- 右下角拖曳調整大小
local ResizeHandle = Instance.new("TextButton")
ResizeHandle.Size = UDim2.new(0, 16, 0, 16)
ResizeHandle.AnchorPoint = Vector2.new(1, 1)
ResizeHandle.Position = UDim2.new(1, -3, 1, -3)
ResizeHandle.BackgroundTransparency = 1
ResizeHandle.Text = ""; ResizeHandle.ZIndex = 10
ResizeHandle.Parent = Win

for i = 1, 3 do
    local line = Instance.new("Frame")
    line.Size = UDim2.new(0, 2+i*2, 0, 1)
    line.Position = UDim2.new(1, -(2+i*2), 1, -i*3)
    line.BackgroundColor3 = CLR.ResizeH; line.BorderSizePixel = 0
    line.Parent = ResizeHandle; RC(line, 1)
end

local resizing = false
local resizeStart, startSize
ResizeHandle.MouseButton1Down:Connect(function()
    resizing    = true
    resizeStart = UserInputService:GetMouseLocation()
    startSize   = Vector2.new(Win.AbsoluteSize.X, Win.AbsoluteSize.Y)
end)
table.insert(Conns, UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then resizing = false end
end))
table.insert(Conns, UserInputService.InputChanged:Connect(function(i)
    if resizing and i.UserInputType == Enum.UserInputType.MouseMovement then
        local mouse = UserInputService:GetMouseLocation()
        local newW  = math.clamp(startSize.X + (mouse.X - resizeStart.X), WIN_MIN_W, WIN_MAX_W)
        currentW    = newW
        local h = minimized and WIN_MIN_H or (WinList.AbsoluteContentSize.Y + 20)
        Win.Size = UDim2.new(0, newW, 0, h)
    end
end))

task.defer(function() ApplyWinH(false) end)
_G.AimUI_Refresh()
print("[TSB 自瞄 已載入")

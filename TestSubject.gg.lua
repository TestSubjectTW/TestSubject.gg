local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local CoreGui          = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

if not LocalPlayer.Character then
    LocalPlayer.CharacterAdded:Wait()
end
local Character = LocalPlayer.Character

local State = {
    Flight  = false,
    Speed   = false,
    InfJump = false,
    ESP     = false,
    NoClip  = false,
}

local Keybinds = {
    Flight     = Enum.KeyCode.F,
    Speed      = Enum.KeyCode.G,
    InfJump    = Enum.KeyCode.H,
    ESP        = Enum.KeyCode.J,
    NoClip     = Enum.KeyCode.N,
    Toggle_GUI = Enum.KeyCode.RightShift,
}

local Settings = {
    FlightSpeed = 100,
    SpeedValue  = 32,
}

local TeleportState = {
    SelectedPlayer = nil,
    FollowEnabled  = false,
    FollowDistance = 0,
    FollowSpeed    = 0.25,
}
local FollowConnection = nil

local Connections  = {}
local BodyVelocity, BodyGyro
local ESPObjects   = {}
local BindingKey   = nil

local function SafeDisconnect(name)
    if Connections[name] then
        pcall(function() Connections[name]:Disconnect() end)
        Connections[name] = nil
    end
end

local function GetHRP()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function GetHumanoid()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function GetCharRoot(plr)
    local char = plr and plr.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function IsTyping()
    return UserInputService:GetFocusedTextBox() ~= nil
end

local function StartFlight()
    local hrp = GetHRP()
    if not hrp then return end
    pcall(function()
        BodyVelocity           = Instance.new("BodyVelocity")
        BodyVelocity.MaxForce  = Vector3.new(1e5, 1e5, 1e5)
        BodyVelocity.Velocity  = Vector3.zero
        BodyVelocity.Parent    = hrp

        BodyGyro               = Instance.new("BodyGyro")
        BodyGyro.MaxTorque     = Vector3.new(1e5, 1e5, 1e5)
        BodyGyro.P             = 1e4
        BodyGyro.Parent        = hrp
    end)
    local hum = GetHumanoid()
    if hum then pcall(function() hum.PlatformStand = true end) end

    SafeDisconnect("FlightRender")
    Connections["FlightRender"] = RunService.RenderStepped:Connect(function()
        local hrp2 = GetHRP()
        if not hrp2 or not BodyVelocity or not BodyVelocity.Parent then return end
        local cf  = workspace.CurrentCamera.CFrame
        local dir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cf.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cf.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space)       then dir = dir + Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0,1,0) end
        BodyVelocity.Velocity = dir.Magnitude > 0 and dir.Unit * Settings.FlightSpeed or Vector3.zero
        BodyGyro.CFrame       = cf
    end)
end

local function StopFlight()
    SafeDisconnect("FlightRender")
    pcall(function() if BodyVelocity then BodyVelocity:Destroy() end end)
    pcall(function() if BodyGyro     then BodyGyro:Destroy()     end end)
    BodyVelocity = nil
    BodyGyro     = nil
    local hum = GetHumanoid()
    if hum then pcall(function() hum.PlatformStand = false end) end
end

local function ToggleFlight()
    State.Flight = not State.Flight
    if State.Flight then StartFlight() else StopFlight() end
end

local function ApplySpeed()
    SafeDisconnect("SpeedLoop")
    Connections["SpeedLoop"] = RunService.Heartbeat:Connect(function()
        local hum = GetHumanoid()
        if hum then pcall(function() hum.WalkSpeed = Settings.SpeedValue end) end
    end)
end

local function ResetSpeed()
    SafeDisconnect("SpeedLoop")
    local hum = GetHumanoid()
    if hum then pcall(function() hum.WalkSpeed = 16 end) end
end

local function ToggleSpeed()
    State.Speed = not State.Speed
    if State.Speed then ApplySpeed() else ResetSpeed() end
end

local function StartInfJump()
    SafeDisconnect("InfJump")
    Connections["InfJump"] = UserInputService.JumpRequest:Connect(function()
        local hum = GetHumanoid()
        if hum then pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end) end
    end)
end

local function StopInfJump() SafeDisconnect("InfJump") end

local function ToggleInfJump()
    State.InfJump = not State.InfJump
    if State.InfJump then StartInfJump() else StopInfJump() end
end

local function ClassifyPlayer(player)
    if player.Team then
        if player.Team == LocalPlayer.Team then
            return player.Team.TeamColor.Color
        else
            return Color3.fromRGB(220, 40, 40)
        end
    end
    return Color3.fromRGB(255, 255, 255)
end

local function AddESP(player)
    if player == LocalPlayer then return end
    if ESPObjects[player] then return end

    local function setupChar(char)
        pcall(function()
            if ESPObjects[player] then
                if ESPObjects[player].Highlight then ESPObjects[player].Highlight:Destroy() end
                if ESPObjects[player].Billboard then ESPObjects[player].Billboard:Destroy() end
            end

            local col = ClassifyPlayer(player)

            local hl = Instance.new("Highlight")
            hl.FillColor           = col
            hl.OutlineColor        = col
            hl.FillTransparency    = 0.82
            hl.OutlineTransparency = 0
            hl.Adornee             = char
            hl.Parent              = char

            local bb = Instance.new("BillboardGui")
            bb.Size       = UDim2.new(0, 100, 0, 30)
            bb.StudsOffset = Vector3.new(0, 3, 0)
            bb.AlwaysOnTop = true
            bb.Adornee    = char:FindFirstChild("Head") or char.PrimaryPart
            bb.Parent     = char

            local lbl = Instance.new("TextLabel")
            lbl.Size                   = UDim2.new(1, 0, 1, 0)
            lbl.BackgroundTransparency = 1
            lbl.TextColor3             = col
            lbl.TextStrokeTransparency = 0
            lbl.TextStrokeColor3       = Color3.fromRGB(0,0,0)
            lbl.Font                   = Enum.Font.GothamBold
            lbl.TextSize               = 14
            lbl.Text                   = player.Name
            lbl.Parent                 = bb

            ESPObjects[player] = {Highlight = hl, Billboard = bb}

            SafeDisconnect("ESP_TC_" .. player.Name)
            Connections["ESP_TC_" .. player.Name] = player:GetPropertyChangedSignal("Team"):Connect(function()
                if ESPObjects[player] then
                    local newCol = ClassifyPlayer(player)
                    pcall(function()
                        ESPObjects[player].Highlight.FillColor    = newCol
                        ESPObjects[player].Highlight.OutlineColor = newCol
                        lbl.TextColor3 = newCol
                    end)
                end
            end)
        end)
    end

    if player.Character then setupChar(player.Character) end
    SafeDisconnect("ESP_CA_" .. player.Name)
    Connections["ESP_CA_" .. player.Name] = player.CharacterAdded:Connect(setupChar)
end

local function RemoveESP(player)
    pcall(function()
        if ESPObjects[player] then
            if ESPObjects[player].Highlight then ESPObjects[player].Highlight:Destroy() end
            if ESPObjects[player].Billboard then ESPObjects[player].Billboard:Destroy() end
            ESPObjects[player] = nil
        end
    end)
    SafeDisconnect("ESP_CA_" .. player.Name)
    SafeDisconnect("ESP_TC_" .. player.Name)
end

local function StartESP()
    for _, p in ipairs(Players:GetPlayers()) do AddESP(p) end
    SafeDisconnect("ESP_PA"); SafeDisconnect("ESP_PR")
    Connections["ESP_PA"] = Players.PlayerAdded:Connect(AddESP)
    Connections["ESP_PR"] = Players.PlayerRemoving:Connect(RemoveESP)
end

local function StopESP()
    SafeDisconnect("ESP_PA"); SafeDisconnect("ESP_PR")
    for _, p in ipairs(Players:GetPlayers()) do RemoveESP(p) end
end

local function ToggleESP()
    State.ESP = not State.ESP
    if State.ESP then StartESP() else StopESP() end
end

local NoClipActive = false

local function StartNoClip()
    NoClipActive = true
    SafeDisconnect("NoClip")
    Connections["NoClip"] = RunService.Stepped:Connect(function()
        if not NoClipActive then return end
        local char = LocalPlayer.Character
        if not char then return end
        for _, obj in next, char:GetDescendants() do
            if obj:IsA("BasePart") then obj.CanCollide = false end
        end
    end)
end

local function StopNoClip()
    NoClipActive = false
    SafeDisconnect("NoClip")
    local char = LocalPlayer.Character
    if char then
        pcall(function()
            for _, obj in next, char:GetDescendants() do
                if obj:IsA("BasePart") then obj.CanCollide = true end
            end
        end)
    end
end

local function ToggleNoClip()
    State.NoClip = not State.NoClip
    if State.NoClip then StartNoClip() else StopNoClip() end
end

local function StopFollow()
    TeleportState.FollowEnabled = false
    if FollowConnection then
        FollowConnection:Disconnect()
        FollowConnection = nil
    end
end

local function StartFollow()
    StopFollow()
    TeleportState.FollowEnabled = true

    local prevPos = nil

    FollowConnection = RunService.Heartbeat:Connect(function(dt)
        if not TeleportState.FollowEnabled then return end

        local myRoot     = GetHRP()
        local targetRoot = GetCharRoot(TeleportState.SelectedPlayer)
        if not myRoot or not targetRoot then return end

        local targetPos = targetRoot.Position
        local alpha     = math.clamp(TeleportState.FollowSpeed * (dt * 60), 0, 1)
        local newPos    = myRoot.Position:Lerp(targetPos, alpha)

        myRoot.CFrame   = CFrame.new(newPos)
        prevPos         = newPos
    end)
end

local function TeleportToPlayer(player)
    local myRoot     = GetHRP()
    local targetRoot = GetCharRoot(player)
    if not myRoot or not targetRoot then return false end
    myRoot.CFrame = targetRoot.CFrame
    return true
end

local function TeleportToRandom()
    local others = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and GetCharRoot(p) then
            others[#others+1] = p
        end
    end
    if #others == 0 then return nil end
    local pick = others[math.random(1, #others)]
    TeleportToPlayer(pick)
    return pick
end

local function CleanupAll()
    if State.Flight  then StopFlight()  end
    if State.Speed   then ResetSpeed()  end
    if State.InfJump then StopInfJump() end
    if State.ESP     then StopESP()     end
    if State.NoClip  then StopNoClip()  end
    StopFollow()

    for k, c in pairs(Connections) do
        pcall(function() c:Disconnect() end)
        Connections[k] = nil
    end

    pcall(function() if BodyVelocity then BodyVelocity:Destroy() end end)
    pcall(function() if BodyGyro     then BodyGyro:Destroy()     end end)
    BodyVelocity = nil
    BodyGyro     = nil

    local hum = GetHumanoid()
    if hum then pcall(function() hum.PlatformStand = false end) end

    State.Flight  = false; State.Speed  = false
    State.InfJump = false; State.ESP    = false
    State.NoClip  = false
end

Connections["CharacterRefresh"] = LocalPlayer.CharacterAdded:Connect(function(char)
    Character = char
    task.wait(1)
    if State.Flight  then StopFlight();  StartFlight()  end
    if State.Speed   then ApplySpeed()                  end
    if State.InfJump then StopInfJump(); StartInfJump() end
    if State.NoClip  then StopNoClip();  StartNoClip()  end
    if State.ESP then
        for _, p in ipairs(Players:GetPlayers()) do
            if ESPObjects[p] then RemoveESP(p); AddESP(p) end
        end
    end
    if TeleportState.FollowEnabled and TeleportState.SelectedPlayer then
        task.wait(0.5)
        StartFollow()
    end
end)

pcall(function()
    local old = CoreGui:FindFirstChild("TestSubjectGUI")
    if old then old:Destroy() end
end)
pcall(function()
    local old = LocalPlayer.PlayerGui:FindFirstChild("TestSubjectGUI")
    if old then old:Destroy() end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name            = "TestSubjectGUI"
ScreenGui.ResetOnSpawn    = false
ScreenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder    = 999

local parentOk = pcall(function() ScreenGui.Parent = CoreGui end)
if not parentOk then ScreenGui.Parent = LocalPlayer.PlayerGui end

local C = {
    BG         = Color3.fromRGB(10,  10,  12),
    SideBar    = Color3.fromRGB(14,  14,  17),
    TitleBar   = Color3.fromRGB(13,  13,  16),
    ContentBG  = Color3.fromRGB(12,  12,  15),
    RowBG      = Color3.fromRGB(22,  22,  27),
    RowBG2     = Color3.fromRGB(18,  18,  22),
    ToggleOff  = Color3.fromRGB(55,  55,  62),
    ToggleOn   = Color3.fromRGB(185, 20,  40),
    Accent     = Color3.fromRGB(210, 25,  50),
    Text       = Color3.fromRGB(225, 225, 230),
    SubText    = Color3.fromRGB(125, 125, 135),
    Border     = Color3.fromRGB(35,  35,  42),
    RowBorder  = Color3.fromRGB(28,  28,  35),
    Close      = Color3.fromRGB(200, 45,  45),
    Minimize   = Color3.fromRGB(190, 145, 35),
    SideBtn    = Color3.fromRGB(18,  18,  22),
    SideBtnSel = Color3.fromRGB(28,  12,  16),
    SetKeyBG   = Color3.fromRGB(26,  26,  32),
    SetKeyAct  = Color3.fromRGB(80,  14,  24),
    TpBtnBG    = Color3.fromRGB(24,  24,  30),
    TpBtnHover = Color3.fromRGB(38,  18,  24),
    SearchBG   = Color3.fromRGB(18,  18,  22),
    ListSelBG  = Color3.fromRGB(38,  14,  20),
    ListHovBG  = Color3.fromRGB(28,  20,  24),
    StatusGood = Color3.fromRGB(100, 210, 130),
    StatusWarn = Color3.fromRGB(255, 160, 70),
    StatusErr  = Color3.fromRGB(220, 70,  70),
}

local function AddCorner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = p
    return c
end

local function AddStroke(p, col, th)
    local s = Instance.new("UIStroke")
    s.Color     = col or C.Border
    s.Thickness = th or 1.2
    s.Parent    = p
    return s
end

local MainFrame = Instance.new("Frame")
MainFrame.Name             = "MainFrame"
MainFrame.Size             = UDim2.new(0, 520, 0, 440)
MainFrame.Position         = UDim2.new(0.5, -260, 0.5, -220)
MainFrame.BackgroundColor3 = C.BG
MainFrame.BorderSizePixel  = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent           = ScreenGui
AddCorner(MainFrame, 10)
AddStroke(MainFrame, C.Border, 1.5)

local TitleBar = Instance.new("Frame")
TitleBar.Size             = UDim2.new(1, 0, 0, 40)
TitleBar.BackgroundColor3 = C.TitleBar
TitleBar.BorderSizePixel  = 0
TitleBar.ZIndex           = 5
TitleBar.Parent           = MainFrame
AddCorner(TitleBar, 10)

local TitlePatch = Instance.new("Frame")
TitlePatch.Size             = UDim2.new(1, 0, 0, 12)
TitlePatch.Position         = UDim2.new(0, 0, 1, -12)
TitlePatch.BackgroundColor3 = C.TitleBar
TitlePatch.BorderSizePixel  = 0
TitlePatch.ZIndex           = 5
TitlePatch.Parent           = TitleBar

local AccentLine = Instance.new("Frame")
AccentLine.Size                   = UDim2.new(1, 0, 0, 2)
AccentLine.Position               = UDim2.new(0, 0, 1, -2)
AccentLine.BackgroundColor3       = C.Accent
AccentLine.BackgroundTransparency = 0.5
AccentLine.BorderSizePixel        = 0
AccentLine.ZIndex                 = 6
AccentLine.Parent                 = TitleBar

local TitleDot = Instance.new("Frame")
TitleDot.Size             = UDim2.new(0, 7, 0, 7)
TitleDot.Position         = UDim2.new(0, 12, 0.5, -3)
TitleDot.BackgroundColor3 = C.Accent
TitleDot.BorderSizePixel  = 0
TitleDot.ZIndex           = 6
TitleDot.Parent           = TitleBar
AddCorner(TitleDot, 4)

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Text                   = "[TestSubject.gg]"
TitleLabel.Font                   = Enum.Font.GothamBold
TitleLabel.TextSize               = 14
TitleLabel.TextColor3             = C.Accent
TitleLabel.BackgroundTransparency = 1
TitleLabel.Size                   = UDim2.new(1, -110, 1, 0)
TitleLabel.Position               = UDim2.new(0, 24, 0, 0)
TitleLabel.TextXAlignment         = Enum.TextXAlignment.Left
TitleLabel.ZIndex                 = 6
TitleLabel.Parent                 = TitleBar

local MinBtn = Instance.new("TextButton")
MinBtn.Text             = "−"
MinBtn.Font             = Enum.Font.GothamBold
MinBtn.TextSize         = 17
MinBtn.TextColor3       = Color3.fromRGB(255,255,255)
MinBtn.BackgroundColor3 = C.Minimize
MinBtn.Size             = UDim2.new(0, 26, 0, 20)
MinBtn.Position         = UDim2.new(1, -64, 0.5, -10)
MinBtn.AutoButtonColor  = true
MinBtn.BorderSizePixel  = 0
MinBtn.ZIndex           = 7
MinBtn.Parent           = TitleBar
AddCorner(MinBtn, 5)

local CloseBtn = Instance.new("TextButton")
CloseBtn.Text             = "✕"
CloseBtn.Font             = Enum.Font.GothamBold
CloseBtn.TextSize         = 12
CloseBtn.TextColor3       = Color3.fromRGB(255,255,255)
CloseBtn.BackgroundColor3 = C.Close
CloseBtn.Size             = UDim2.new(0, 26, 0, 20)
CloseBtn.Position         = UDim2.new(1, -34, 0.5, -10)
CloseBtn.AutoButtonColor  = true
CloseBtn.BorderSizePixel  = 0
CloseBtn.ZIndex           = 7
CloseBtn.Parent           = TitleBar
AddCorner(CloseBtn, 5)

local LayoutFrame = Instance.new("Frame")
LayoutFrame.Size                   = UDim2.new(1, 0, 1, -40)
LayoutFrame.Position               = UDim2.new(0, 0, 0, 40)
LayoutFrame.BackgroundTransparency = 1
LayoutFrame.BorderSizePixel        = 0
LayoutFrame.Parent                 = MainFrame

local SideBar = Instance.new("Frame")
SideBar.Size             = UDim2.new(0, 110, 1, 0)
SideBar.BackgroundColor3 = C.SideBar
SideBar.BorderSizePixel  = 0
SideBar.Parent           = LayoutFrame
AddStroke(SideBar, C.Border, 1)

Instance.new("UIListLayout", SideBar).Padding = UDim.new(0, 4)

local SidePad = Instance.new("UIPadding")
SidePad.PaddingTop    = UDim.new(0, 10)
SidePad.PaddingLeft   = UDim.new(0, 7)
SidePad.PaddingRight  = UDim.new(0, 7)
SidePad.PaddingBottom = UDim.new(0, 10)
SidePad.Parent        = SideBar

local ContentArea = Instance.new("Frame")
ContentArea.Size             = UDim2.new(1, -110, 1, 0)
ContentArea.Position         = UDim2.new(0, 110, 0, 0)
ContentArea.BackgroundColor3 = C.ContentBG
ContentArea.BorderSizePixel  = 0
ContentArea.ClipsDescendants = true
ContentArea.Parent           = LayoutFrame

local Pages     = {}
local ActiveTab = nil

local function CreatePage()
    local page = Instance.new("ScrollingFrame")
    page.Size                  = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel       = 0
    page.ScrollBarThickness    = 3
    page.ScrollBarImageColor3  = C.Accent
    page.CanvasSize            = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize   = Enum.AutomaticSize.Y
    page.Visible               = false
    page.Parent                = ContentArea

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 7)
    layout.Parent  = page

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft   = UDim.new(0, 10)
    pad.PaddingRight  = UDim.new(0, 10)
    pad.PaddingTop    = UDim.new(0, 10)
    pad.PaddingBottom = UDim.new(0, 10)
    pad.Parent        = page

    return page
end

local function CreateFixedPage()
    local page = Instance.new("Frame")
    page.Size                   = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel        = 0
    page.ClipsDescendants       = true
    page.Visible                = false
    page.Parent                 = ContentArea
    return page
end

Pages.Movement = CreatePage()
Pages.Visuals  = CreatePage()
Pages.Misc     = CreatePage()
Pages.Teleport = CreateFixedPage()
Pages.Combat   = CreatePage()

local SideButtons = {}

local tabDefs = {
    {key = "Movement", icon = "⚡", label = "Movement"},
    {key = "Visuals",  icon = "👁",  label = "Visuals"},
    {key = "Misc",     icon = "⚙",  label = "Misc"},
    {key = "Teleport", icon = "⊕",  label = "Teleport"},
    {key = "Combat",   icon = "⚔",  label = "Combat"},
}

local tabKeys = {"Movement","Visuals","Misc","Teleport","Combat"}

local function SelectTab(key)
    for _, k in ipairs(tabKeys) do
        Pages[k].Visible = (k == key)
    end
    for _, def in ipairs(tabDefs) do
        local btn = SideButtons[def.key]
        if btn then
            if def.key == key then
                TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = C.SideBtnSel}):Play()
                local acc = btn:FindFirstChild("AccentBar")
                if acc then acc.Visible = true end
                local lbl = btn:FindFirstChildOfClass("TextLabel")
                if lbl then lbl.TextColor3 = C.Accent end
            else
                TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = C.SideBtn}):Play()
                local acc = btn:FindFirstChild("AccentBar")
                if acc then acc.Visible = false end
                local lbl = btn:FindFirstChildOfClass("TextLabel")
                if lbl then lbl.TextColor3 = C.SubText end
            end
        end
    end
    ActiveTab = key
end

for _, def in ipairs(tabDefs) do
    local btn = Instance.new("TextButton")
    btn.Name             = def.key
    btn.Size             = UDim2.new(1, 0, 0, 34)
    btn.BackgroundColor3 = C.SideBtn
    btn.BorderSizePixel  = 0
    btn.Text             = ""
    btn.AutoButtonColor  = false
    btn.Parent           = SideBar
    AddCorner(btn, 6)

    local accentBar = Instance.new("Frame")
    accentBar.Name             = "AccentBar"
    accentBar.Size             = UDim2.new(0, 3, 0, 18)
    accentBar.Position         = UDim2.new(0, 0, 0.5, -9)
    accentBar.BackgroundColor3 = C.Accent
    accentBar.BorderSizePixel  = 0
    accentBar.Visible          = false
    accentBar.Parent           = btn
    AddCorner(accentBar, 2)

    local lbl = Instance.new("TextLabel")
    lbl.Text                   = def.icon .. "  " .. def.label
    lbl.Font                   = Enum.Font.GothamBold
    lbl.TextSize               = 11
    lbl.TextColor3             = C.SubText
    lbl.BackgroundTransparency = 1
    lbl.Size                   = UDim2.new(1, -8, 1, 0)
    lbl.Position               = UDim2.new(0, 10, 0, 0)
    lbl.TextXAlignment         = Enum.TextXAlignment.Left
    lbl.Parent                 = btn

    SideButtons[def.key] = btn

    btn.MouseButton1Click:Connect(function() SelectTab(def.key) end)
    btn.MouseEnter:Connect(function()
        if ActiveTab ~= def.key then
            TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(24,14,18)}):Play()
        end
    end)
    btn.MouseLeave:Connect(function()
        if ActiveTab ~= def.key then
            TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = C.SideBtn}):Play()
        end
    end)
end

local function MakeToggle(parent, labelText, stateKey, toggleFn, keybindKey)
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1, 0, 0, 52)
    row.BackgroundColor3 = C.RowBG
    row.BorderSizePixel  = 0
    row.Parent           = parent
    AddCorner(row, 6)
    AddStroke(row, C.RowBorder, 0.8)

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Text                   = labelText
    nameLabel.Font                   = Enum.Font.GothamBold
    nameLabel.TextSize               = 13
    nameLabel.TextColor3             = C.Text
    nameLabel.BackgroundTransparency = 1
    nameLabel.Size                   = UDim2.new(0, 110, 0, 22)
    nameLabel.Position               = UDim2.new(0, 10, 0, 5)
    nameLabel.TextXAlignment         = Enum.TextXAlignment.Left
    nameLabel.Parent                 = row

    local kbLabel = Instance.new("TextLabel")
    kbLabel.Text                   = "[" .. Keybinds[keybindKey].Name .. "]"
    kbLabel.Font                   = Enum.Font.Gotham
    kbLabel.TextSize               = 10
    kbLabel.TextColor3             = C.SubText
    kbLabel.BackgroundTransparency = 1
    kbLabel.Size                   = UDim2.new(0, 110, 0, 18)
    kbLabel.Position               = UDim2.new(0, 10, 0, 28)
    kbLabel.TextXAlignment         = Enum.TextXAlignment.Left
    kbLabel.Parent                 = row

    local setKeyBtn = Instance.new("TextButton")
    setKeyBtn.Text             = "Set Key"
    setKeyBtn.Font             = Enum.Font.Gotham
    setKeyBtn.TextSize         = 10
    setKeyBtn.TextColor3       = C.Text
    setKeyBtn.BackgroundColor3 = C.SetKeyBG
    setKeyBtn.Size             = UDim2.new(0, 54, 0, 20)
    setKeyBtn.Position         = UDim2.new(1, -106, 0.5, -10)
    setKeyBtn.BorderSizePixel  = 0
    setKeyBtn.AutoButtonColor  = true
    setKeyBtn.Parent           = row
    AddCorner(setKeyBtn, 4)
    AddStroke(setKeyBtn, C.Border, 0.8)

    local pillBG = Instance.new("Frame")
    pillBG.Size             = UDim2.new(0, 44, 0, 22)
    pillBG.Position         = UDim2.new(1, -52, 0.5, -11)
    pillBG.BackgroundColor3 = C.ToggleOff
    pillBG.BorderSizePixel  = 0
    pillBG.Parent           = row
    AddCorner(pillBG, 11)

    local pillDot = Instance.new("Frame")
    pillDot.Size             = UDim2.new(0, 16, 0, 16)
    pillDot.Position         = UDim2.new(0, 3, 0.5, -8)
    pillDot.BackgroundColor3 = Color3.fromRGB(210, 210, 220)
    pillDot.BorderSizePixel  = 0
    pillDot.Parent           = pillBG
    AddCorner(pillDot, 8)

    local pillBtn = Instance.new("TextButton")
    pillBtn.Size               = UDim2.new(1, 0, 1, 0)
    pillBtn.BackgroundTransparency = 1
    pillBtn.Text               = ""
    pillBtn.Parent             = pillBG

    local function UpdatePill()
        local on = State[stateKey]
        TweenService:Create(pillBG, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
            BackgroundColor3 = on and C.ToggleOn or C.ToggleOff
        }):Play()
        TweenService:Create(pillDot, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
            Position = on and UDim2.new(0, 25, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        }):Play()
    end

    pillBtn.MouseButton1Click:Connect(function()
        toggleFn()
        UpdatePill()
    end)

    local waitingConn = nil
    setKeyBtn.MouseButton1Click:Connect(function()
        if BindingKey == keybindKey then
            BindingKey                 = nil
            setKeyBtn.Text             = "Set Key"
            setKeyBtn.BackgroundColor3 = C.SetKeyBG
            if waitingConn then waitingConn:Disconnect(); waitingConn = nil end
            return
        end
        BindingKey                 = keybindKey
        setKeyBtn.Text             = "Press..."
        setKeyBtn.BackgroundColor3 = C.SetKeyAct
        if waitingConn then waitingConn:Disconnect() end
        waitingConn = UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Keyboard then
                if BindingKey == keybindKey then
                    Keybinds[keybindKey]       = input.KeyCode
                    kbLabel.Text               = "[" .. input.KeyCode.Name .. "]"
                    setKeyBtn.Text             = "Set Key"
                    setKeyBtn.BackgroundColor3 = C.SetKeyBG
                    BindingKey                 = nil
                end
                if waitingConn then waitingConn:Disconnect(); waitingConn = nil end
            end
        end)
    end)

    return UpdatePill
end

local function MakeSlider(parent, labelText, minVal, maxVal, defaultVal, onChange)
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1, 0, 0, 52)
    row.BackgroundColor3 = C.RowBG2
    row.BorderSizePixel  = 0
    row.Parent           = parent
    AddCorner(row, 6)
    AddStroke(row, C.RowBorder, 0.8)

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Text                   = labelText
    nameLabel.Font                   = Enum.Font.Gotham
    nameLabel.TextSize               = 11
    nameLabel.TextColor3             = C.SubText
    nameLabel.BackgroundTransparency = 1
    nameLabel.Size                   = UDim2.new(0.65, 0, 0, 18)
    nameLabel.Position               = UDim2.new(0, 10, 0, 6)
    nameLabel.TextXAlignment         = Enum.TextXAlignment.Left
    nameLabel.Parent                 = row

    local valLabel = Instance.new("TextLabel")
    valLabel.Text                   = tostring(defaultVal)
    valLabel.Font                   = Enum.Font.GothamBold
    valLabel.TextSize               = 11
    valLabel.TextColor3             = C.Accent
    valLabel.BackgroundTransparency = 1
    valLabel.Size                   = UDim2.new(0.35, -10, 0, 18)
    valLabel.Position               = UDim2.new(0.65, 0, 0, 6)
    valLabel.TextXAlignment         = Enum.TextXAlignment.Right
    valLabel.Parent                 = row

    local track = Instance.new("Frame")
    track.Size             = UDim2.new(1, -20, 0, 6)
    track.Position         = UDim2.new(0, 10, 0, 34)
    track.BackgroundColor3 = Color3.fromRGB(36, 36, 44)
    track.BorderSizePixel  = 0
    track.Parent           = row
    AddCorner(track, 3)

    local pct0 = (defaultVal - minVal) / (maxVal - minVal)

    local fill = Instance.new("Frame")
    fill.Size             = UDim2.new(pct0, 0, 1, 0)
    fill.BackgroundColor3 = C.Accent
    fill.BorderSizePixel  = 0
    fill.Parent           = track
    AddCorner(fill, 3)

    local knob = Instance.new("Frame")
    knob.Size             = UDim2.new(0, 13, 0, 13)
    knob.Position         = UDim2.new(pct0, -6, 0.5, -6)
    knob.BackgroundColor3 = Color3.fromRGB(220, 220, 225)
    knob.BorderSizePixel  = 0
    knob.Parent           = track
    AddCorner(knob, 7)

    local trackBtn = Instance.new("TextButton")
    trackBtn.Size               = UDim2.new(1, 0, 0, 22)
    trackBtn.Position           = UDim2.new(0, 0, 0.5, -11)
    trackBtn.BackgroundTransparency = 1
    trackBtn.Text               = ""
    trackBtn.Parent             = track

    local dragging = false

    local function setVal(p)
        p = math.clamp(p, 0, 1)
        local val = math.floor(minVal + (maxVal - minVal) * p)
        fill.Size     = UDim2.new(p, 0, 1, 0)
        knob.Position = UDim2.new(p, -6, 0.5, -6)
        valLabel.Text = tostring(val)
        onChange(val)
    end

    trackBtn.MouseButton1Down:Connect(function() dragging = true end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    RunService.RenderStepped:Connect(function()
        if dragging then
            local mp = UserInputService:GetMouseLocation()
            local tp = track.AbsolutePosition
            local ts = track.AbsoluteSize
            setVal((mp.X - tp.X) / ts.X)
        end
    end)

    return setVal
end

local updateFlightPill  = MakeToggle(Pages.Movement, "Flight",        "Flight",  ToggleFlight,  "Flight")
MakeSlider(Pages.Movement, "Flight Speed", 50, 500, Settings.FlightSpeed, function(v)
    Settings.FlightSpeed = v
end)
local updateSpeedPill   = MakeToggle(Pages.Movement, "Speed",         "Speed",   ToggleSpeed,   "Speed")
MakeSlider(Pages.Movement, "Walk Speed", 16, 500, Settings.SpeedValue, function(v)
    Settings.SpeedValue = v
    if State.Speed then
        local hum = GetHumanoid()
        if hum then pcall(function() hum.WalkSpeed = v end) end
    end
end)
local updateInfJumpPill = MakeToggle(Pages.Movement, "Infinite Jump", "InfJump", ToggleInfJump, "InfJump")

local updateESPPill = MakeToggle(Pages.Visuals, "ESP", "ESP", ToggleESP, "ESP")

local updateNoClipPill = MakeToggle(Pages.Misc, "NoClip", "NoClip", ToggleNoClip, "NoClip")

local TP  = Pages.Teleport
local PAD = 10

local function TpSectionLabel(text, yPos)
    local lbl = Instance.new("TextLabel")
    lbl.Text                   = text
    lbl.Font                   = Enum.Font.GothamBold
    lbl.TextSize               = 10
    lbl.TextColor3             = C.SubText
    lbl.BackgroundTransparency = 1
    lbl.Size                   = UDim2.new(1, -PAD * 2, 0, 18)
    lbl.Position               = UDim2.new(0, PAD, 0, yPos)
    lbl.TextXAlignment         = Enum.TextXAlignment.Left
    lbl.Parent                 = TP
    return lbl
end

local TpStatus = Instance.new("Frame")
TpStatus.Size             = UDim2.new(1, -PAD * 2, 0, 26)
TpStatus.Position         = UDim2.new(0, PAD, 1, -PAD - 26)
TpStatus.BackgroundColor3 = C.RowBG2
TpStatus.BorderSizePixel  = 0
TpStatus.Parent           = TP
AddCorner(TpStatus, 5)
AddStroke(TpStatus, C.RowBorder, 0.8)

local TpStatusLabel = Instance.new("TextLabel")
TpStatusLabel.Text                   = "Ready."
TpStatusLabel.Font                   = Enum.Font.Gotham
TpStatusLabel.TextSize               = 11
TpStatusLabel.TextColor3             = C.StatusGood
TpStatusLabel.BackgroundTransparency = 1
TpStatusLabel.Size                   = UDim2.new(1, -10, 1, 0)
TpStatusLabel.Position               = UDim2.new(0, 8, 0, 0)
TpStatusLabel.TextXAlignment         = Enum.TextXAlignment.Left
TpStatusLabel.Parent                 = TpStatus

local function SetTpStatus(msg, col)
    TpStatusLabel.Text       = msg
    TpStatusLabel.TextColor3 = col or C.StatusGood
end

TpSectionLabel("TARGET PLAYER", PAD)

local TargetBanner = Instance.new("Frame")
TargetBanner.Size             = UDim2.new(1, -PAD * 2, 0, 30)
TargetBanner.Position         = UDim2.new(0, PAD, 0, PAD + 18)
TargetBanner.BackgroundColor3 = C.RowBG
TargetBanner.BorderSizePixel  = 0
TargetBanner.Parent           = TP
AddCorner(TargetBanner, 6)
AddStroke(TargetBanner, C.RowBorder, 0.8)

local TargetDot = Instance.new("Frame")
TargetDot.Size             = UDim2.new(0, 8, 0, 8)
TargetDot.Position         = UDim2.new(0, 10, 0.5, -4)
TargetDot.BackgroundColor3 = C.SubText
TargetDot.BorderSizePixel  = 0
TargetDot.Parent           = TargetBanner
AddCorner(TargetDot, 4)

local TargetNameLabel = Instance.new("TextLabel")
TargetNameLabel.Text                   = "None selected"
TargetNameLabel.Font                   = Enum.Font.GothamBold
TargetNameLabel.TextSize               = 12
TargetNameLabel.TextColor3             = C.SubText
TargetNameLabel.BackgroundTransparency = 1
TargetNameLabel.Size                   = UDim2.new(1, -28, 1, 0)
TargetNameLabel.Position               = UDim2.new(0, 24, 0, 0)
TargetNameLabel.TextXAlignment         = Enum.TextXAlignment.Left
TargetNameLabel.Parent                 = TargetBanner

local function UpdateTargetBanner()
    if TeleportState.SelectedPlayer then
        TargetNameLabel.Text       = TeleportState.SelectedPlayer.Name
        TargetNameLabel.TextColor3 = C.Text
        TargetDot.BackgroundColor3 = C.Accent
    else
        TargetNameLabel.Text       = "None selected"
        TargetNameLabel.TextColor3 = C.SubText
        TargetDot.BackgroundColor3 = C.SubText
    end
end

TpSectionLabel("PLAYER LIST", PAD + 18 + 30 + 8)

local SearchBar = Instance.new("TextBox")
SearchBar.PlaceholderText   = "🔍  Search players..."
SearchBar.PlaceholderColor3 = C.SubText
SearchBar.Text              = ""
SearchBar.Font              = Enum.Font.Gotham
SearchBar.TextSize          = 12
SearchBar.TextColor3        = C.Text
SearchBar.BackgroundColor3  = C.SearchBG
SearchBar.BorderSizePixel   = 0
SearchBar.ClearTextOnFocus  = false
SearchBar.Size              = UDim2.new(1, -PAD * 2, 0, 28)
SearchBar.Position          = UDim2.new(0, PAD, 0, PAD + 18 + 30 + 8 + 18)
SearchBar.TextXAlignment    = Enum.TextXAlignment.Left
SearchBar.Parent            = TP
AddCorner(SearchBar, 6)
AddStroke(SearchBar, C.Border, 0.8)
Instance.new("UIPadding", SearchBar).PaddingLeft = UDim.new(0, 8)

local LIST_Y     = PAD + 18 + 30 + 8 + 18 + 28 + 6
local LIST_H     = 140
local BTN_AREA_Y = LIST_Y + LIST_H + 8

local PlayerScroll = Instance.new("ScrollingFrame")
PlayerScroll.Size                  = UDim2.new(1, -PAD * 2, 0, LIST_H)
PlayerScroll.Position              = UDim2.new(0, PAD, 0, LIST_Y)
PlayerScroll.BackgroundColor3      = C.SearchBG
PlayerScroll.BorderSizePixel       = 0
PlayerScroll.ScrollBarThickness    = 3
PlayerScroll.ScrollBarImageColor3  = C.Accent
PlayerScroll.CanvasSize            = UDim2.new(0, 0, 0, 0)
PlayerScroll.AutomaticCanvasSize   = Enum.AutomaticSize.Y
PlayerScroll.Parent                = TP
AddCorner(PlayerScroll, 6)
AddStroke(PlayerScroll, C.RowBorder, 0.8)

local PlayerListLayout = Instance.new("UIListLayout", PlayerScroll)
PlayerListLayout.Padding   = UDim.new(0, 2)
PlayerListLayout.SortOrder = Enum.SortOrder.Name

local PlayerListPad = Instance.new("UIPadding", PlayerScroll)
PlayerListPad.PaddingTop    = UDim.new(0, 3)
PlayerListPad.PaddingBottom = UDim.new(0, 3)
PlayerListPad.PaddingLeft   = UDim.new(0, 3)
PlayerListPad.PaddingRight  = UDim.new(0, 3)

local function BuildPlayerList(filter)
    filter = (filter or ""):lower()
    for _, child in ipairs(PlayerScroll:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local name = plr.Name
            if filter == "" or name:lower():find(filter, 1, true) then
                local isSelected = (TeleportState.SelectedPlayer == plr)

                local btn = Instance.new("TextButton")
                btn.Name             = name
                btn.Text             = "  " .. name
                btn.Size             = UDim2.new(1, 0, 0, 28)
                btn.BackgroundColor3 = isSelected and C.ListSelBG or C.RowBG2
                btn.TextColor3       = isSelected and C.Accent or C.Text
                btn.Font             = Enum.Font.Gotham
                btn.TextSize         = 12
                btn.TextXAlignment   = Enum.TextXAlignment.Left
                btn.BorderSizePixel  = 0
                btn.AutoButtonColor  = false
                btn.Parent           = PlayerScroll
                AddCorner(btn, 5)

                if isSelected then
                    local selBar = Instance.new("Frame")
                    selBar.Size             = UDim2.new(0, 3, 0, 16)
                    selBar.Position         = UDim2.new(0, 0, 0.5, -8)
                    selBar.BackgroundColor3 = C.Accent
                    selBar.BorderSizePixel  = 0
                    selBar.Parent           = btn
                    AddCorner(selBar, 2)
                end

                btn.MouseEnter:Connect(function()
                    if TeleportState.SelectedPlayer ~= plr then
                        TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = C.ListHovBG}):Play()
                    end
                end)
                btn.MouseLeave:Connect(function()
                    if TeleportState.SelectedPlayer ~= plr then
                        TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = C.RowBG2}):Play()
                    end
                end)
                btn.MouseButton1Click:Connect(function()
                    TeleportState.SelectedPlayer = plr
                    UpdateTargetBanner()
                    SetTpStatus("Selected: " .. name)
                    BuildPlayerList(SearchBar.Text)
                end)
            end
        end
    end
end

BuildPlayerList()
SearchBar:GetPropertyChangedSignal("Text"):Connect(function()
    BuildPlayerList(SearchBar.Text)
end)
Players.PlayerAdded:Connect(function()
    task.wait(0.1); BuildPlayerList(SearchBar.Text)
end)
Players.PlayerRemoving:Connect(function(plr)
    if TeleportState.SelectedPlayer == plr then
        TeleportState.SelectedPlayer = nil
        UpdateTargetBanner()
        if TeleportState.FollowEnabled then
            StopFollow()
            SetTpStatus("Target left — follow stopped.", C.StatusWarn)
        else
            SetTpStatus("Target left the game.", C.StatusWarn)
        end
    end
    task.wait(0.1); BuildPlayerList(SearchBar.Text)
end)

TpSectionLabel("ACTIONS", BTN_AREA_Y)

local ABTN_Y   = BTN_AREA_Y + 18 + 4
local ABTN_H   = 30
local ABTN_GAP = 5

local function MakeTpButton(labelText, yPos, col)
    col = col or C.TpBtnBG
    local btn = Instance.new("TextButton")
    btn.Text             = labelText
    btn.Font             = Enum.Font.GothamBold
    btn.TextSize         = 12
    btn.TextColor3       = C.Text
    btn.BackgroundColor3 = col
    btn.Size             = UDim2.new(1, -PAD * 2, 0, ABTN_H)
    btn.Position         = UDim2.new(0, PAD, 0, yPos)
    btn.BorderSizePixel  = 0
    btn.AutoButtonColor  = false
    btn.Parent           = TP
    AddCorner(btn, 6)
    AddStroke(btn, C.RowBorder, 0.8)
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(38,18,24)}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundColor3 = col}):Play()
    end)
    return btn
end

local BtnTeleport = MakeTpButton("⚡  Teleport to Player", ABTN_Y)
BtnTeleport.MouseButton1Click:Connect(function()
    if not TeleportState.SelectedPlayer then SetTpStatus("No target selected!", C.StatusErr); return end
    local ok2 = TeleportToPlayer(TeleportState.SelectedPlayer)
    if ok2 then SetTpStatus("Teleported to " .. TeleportState.SelectedPlayer.Name .. "!")
    else SetTpStatus("Target has no character.", C.StatusWarn) end
end)

local BtnFollow     = MakeTpButton("▶  Follow Player: OFF", ABTN_Y + ABTN_H + ABTN_GAP)
local followBtnBase = C.TpBtnBG

local function UpdateFollowBtn()
    if TeleportState.FollowEnabled then
        BtnFollow.Text             = "⏹  Follow Player: ON"
        followBtnBase              = Color3.fromRGB(24, 50, 30)
        BtnFollow.BackgroundColor3 = followBtnBase
    else
        BtnFollow.Text             = "▶  Follow Player: OFF"
        followBtnBase              = C.TpBtnBG
        BtnFollow.BackgroundColor3 = followBtnBase
    end
end

BtnFollow.MouseButton1Click:Connect(function()
    if not TeleportState.SelectedPlayer then SetTpStatus("No target selected!", C.StatusErr); return end
    if TeleportState.FollowEnabled then
        StopFollow(); SetTpStatus("Follow stopped.")
    else
        StartFollow(); SetTpStatus("Following: " .. TeleportState.SelectedPlayer.Name)
    end
    UpdateFollowBtn()
end)

local BtnRandom = MakeTpButton("🎲  Teleport to Random", ABTN_Y + (ABTN_H + ABTN_GAP) * 2)
BtnRandom.MouseButton1Click:Connect(function()
    local picked = TeleportToRandom()
    if picked then SetTpStatus("Teleported to random: " .. picked.Name)
    else SetTpStatus("No other players with characters.", C.StatusWarn) end
end)

local CombatSettings = {
    FOVEnabled = false,
    FOVRadius  = 80,
}

local FOVContainer = Instance.new("Frame")
FOVContainer.Name                   = "FOVContainer"
FOVContainer.Size                   = UDim2.new(1, 0, 1, 0)
FOVContainer.BackgroundTransparency = 1
FOVContainer.BorderSizePixel        = 0
FOVContainer.ZIndex                 = 1
FOVContainer.Visible                = false
FOVContainer.Parent                 = ScreenGui

local FOVOuter = Instance.new("Frame")
FOVOuter.BackgroundColor3  = Color3.fromRGB(210, 25, 50)
FOVOuter.BackgroundTransparency = 1
FOVOuter.BorderSizePixel   = 0
FOVOuter.ZIndex            = 2
FOVOuter.Parent            = FOVContainer
AddCorner(FOVOuter, 999)

local FOVInner = Instance.new("Frame")
FOVInner.BackgroundColor3  = Color3.fromRGB(0, 0, 0)
FOVInner.BackgroundTransparency = 1
FOVInner.BorderSizePixel   = 0
FOVInner.ZIndex            = 3
FOVInner.Parent            = FOVOuter
AddCorner(FOVInner, 999)

local fovStroke = Instance.new("UIStroke", FOVOuter)
fovStroke.Color       = Color3.fromRGB(210, 25, 50)
fovStroke.Thickness   = 1.5
fovStroke.Transparency = 0

local function UpdateFOVCircle()
    local r   = CombatSettings.FOVRadius
    local cam = workspace.CurrentCamera
    if not cam then return end
    local vp  = cam.ViewportSize
    local cx  = vp.X / 2
    local cy  = vp.Y / 2
    local d   = r * 2
    FOVOuter.Size     = UDim2.new(0, d, 0, d)
    FOVOuter.Position = UDim2.new(0, cx - r, 0, cy - r)
end

Connections["FOVUpdate"] = RunService.RenderStepped:Connect(function()
    if CombatSettings.FOVEnabled then
        UpdateFOVCircle()
    end
end)

local function SetFOVVisible(on)
    CombatSettings.FOVEnabled = on
    FOVContainer.Visible       = on
    if on then UpdateFOVCircle() end
end

local function MakeCombatToggle(parent, labelText, getter, setter)
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1, 0, 0, 46)
    row.BackgroundColor3 = C.RowBG
    row.BorderSizePixel  = 0
    row.Parent           = parent
    AddCorner(row, 6)
    AddStroke(row, C.RowBorder, 0.8)

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Text                   = labelText
    nameLabel.Font                   = Enum.Font.GothamBold
    nameLabel.TextSize               = 13
    nameLabel.TextColor3             = C.Text
    nameLabel.BackgroundTransparency = 1
    nameLabel.Size                   = UDim2.new(1, -70, 1, 0)
    nameLabel.Position               = UDim2.new(0, 12, 0, 0)
    nameLabel.TextXAlignment         = Enum.TextXAlignment.Left
    nameLabel.Parent                 = row

    local pillBG = Instance.new("Frame")
    pillBG.Size             = UDim2.new(0, 44, 0, 22)
    pillBG.Position         = UDim2.new(1, -52, 0.5, -11)
    pillBG.BackgroundColor3 = C.ToggleOff
    pillBG.BorderSizePixel  = 0
    pillBG.Parent           = row
    AddCorner(pillBG, 11)

    local pillDot = Instance.new("Frame")
    pillDot.Size             = UDim2.new(0, 16, 0, 16)
    pillDot.Position         = UDim2.new(0, 3, 0.5, -8)
    pillDot.BackgroundColor3 = Color3.fromRGB(210, 210, 220)
    pillDot.BorderSizePixel  = 0
    pillDot.Parent           = pillBG
    AddCorner(pillDot, 8)

    local pillBtn = Instance.new("TextButton")
    pillBtn.Size               = UDim2.new(1, 0, 1, 0)
    pillBtn.BackgroundTransparency = 1
    pillBtn.Text               = ""
    pillBtn.Parent             = pillBG

    local function Refresh()
        local on = getter()
        TweenService:Create(pillBG, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
            BackgroundColor3 = on and C.ToggleOn or C.ToggleOff
        }):Play()
        TweenService:Create(pillDot, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
            Position = on and UDim2.new(0, 25, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        }):Play()
    end

    pillBtn.MouseButton1Click:Connect(function()
        setter(not getter())
        Refresh()
    end)

    Refresh()
    return Refresh
end

local function MakeSectionHeader(parent, text)
    local lbl = Instance.new("TextLabel")
    lbl.Text                   = text
    lbl.Font                   = Enum.Font.GothamBold
    lbl.TextSize               = 10
    lbl.TextColor3             = C.SubText
    lbl.BackgroundTransparency = 1
    lbl.Size                   = UDim2.new(1, 0, 0, 18)
    lbl.TextXAlignment         = Enum.TextXAlignment.Left
    lbl.Parent                 = parent
end

MakeSectionHeader(Pages.Combat, "VISUALS")

MakeCombatToggle(
    Pages.Combat,
    "FOV Circle",
    function() return CombatSettings.FOVEnabled end,
    function(val) SetFOVVisible(val) end
)

MakeSlider(Pages.Combat, "FOV Radius", 20, 400, CombatSettings.FOVRadius, function(v)
    CombatSettings.FOVRadius = v
    if CombatSettings.FOVEnabled then UpdateFOVCircle() end
end)

local infoRow = Instance.new("Frame")
infoRow.Size             = UDim2.new(1, 0, 0, 48)
infoRow.BackgroundColor3 = C.RowBG2
infoRow.BorderSizePixel  = 0
infoRow.Parent           = Pages.Combat
AddCorner(infoRow, 6)
AddStroke(infoRow, C.RowBorder, 0.8)

local infoLabel = Instance.new("TextLabel")
infoLabel.Text                   = "FOV Circle shows the aim radius\non screen as a visual reference."
infoLabel.Font                   = Enum.Font.Gotham
infoLabel.TextSize               = 11
infoLabel.TextColor3             = C.SubText
infoLabel.BackgroundTransparency = 1
infoLabel.Size                   = UDim2.new(1, -16, 1, 0)
infoLabel.Position               = UDim2.new(0, 8, 0, 0)
infoLabel.TextXAlignment         = Enum.TextXAlignment.Left
infoLabel.TextYAlignment         = Enum.TextYAlignment.Center
infoLabel.TextWrapped            = true
infoLabel.Parent                 = infoRow

local isDragging   = false
local dragStartPos, frameStartPos

TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        isDragging    = true
        dragStartPos  = input.Position
        frameStartPos = MainFrame.Position
    end
end)
TitleBar.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        isDragging = false
    end
end)
Connections["DragMove"] = UserInputService.InputChanged:Connect(function(input)
    if isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStartPos
        MainFrame.Position = UDim2.new(
            frameStartPos.X.Scale, frameStartPos.X.Offset + delta.X,
            frameStartPos.Y.Scale, frameStartPos.Y.Offset + delta.Y
        )
    end
end)

local minimized = false

MinBtn.MouseButton1Click:Connect(function()
    minimized           = not minimized
    LayoutFrame.Visible = not minimized
    TweenService:Create(MainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
        Size = minimized and UDim2.new(0, 520, 0, 40) or UDim2.new(0, 520, 0, 440)
    }):Play()
end)

CloseBtn.MouseButton1Click:Connect(function()
    SetFOVVisible(false)
    CleanupAll()
    ScreenGui:Destroy()
end)

local guiVisible = true

Connections["MainKeybind"] = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if IsTyping() then return end
    if gameProcessed then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if BindingKey ~= nil then return end

    if input.KeyCode == Keybinds.Toggle_GUI then
        guiVisible        = not guiVisible
        MainFrame.Visible = guiVisible
        return
    end

    if input.KeyCode == Keybinds.Flight  then ToggleFlight();  updateFlightPill()   end
    if input.KeyCode == Keybinds.Speed   then ToggleSpeed();   updateSpeedPill()    end
    if input.KeyCode == Keybinds.InfJump then ToggleInfJump(); updateInfJumpPill()  end
    if input.KeyCode == Keybinds.ESP     then ToggleESP();     updateESPPill()      end
    if input.KeyCode == Keybinds.NoClip  then ToggleNoClip();  updateNoClipPill()   end
end)

SelectTab("Movement")

print("[TestSubject.gg] Loaded! Toggle GUI: RightShift")

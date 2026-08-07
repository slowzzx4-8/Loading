--==================================================
-- GAME VERIFICATION (EAT THE WORLD ONLY)
--==================================================
local placeId = game.PlaceId
local gameId = game.GameId
if placeId ~= 16480898254 and gameId ~= 5677613211 and placeId ~= 5677613211 then
    game.Players.LocalPlayer:Kick("This script only works on Eat The World!")
    return
end

--==================================================
-- MAIN SERVICES & SAVE SYSTEM
--==================================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local TeleportService = game:GetService("TeleportService")
local PathfindingService = game:GetService("PathfindingService")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local Player = Players.LocalPlayer

-- Configurações e Save Manager
local ConfigFile = "VoidHub_EatTheWorld.json"
local loadedConfig = {}

if isfile and isfile(ConfigFile) then
    local success, data = pcall(function()
        return HttpService:JSONDecode(readfile(ConfigFile))
    end)
    if success and type(data) == "table" then
        loadedConfig = data
    end
end

-- Variables (carregando do save ou usando o padrão false/true)
local eatEnabled = loadedConfig.eatEnabled or false
local grabEnabled = loadedConfig.grabEnabled or false
local cubeCoinsEnabled = loadedConfig.cubeCoinsEnabled or false
local rewardsEnabled = loadedConfig.rewardsEnabled or false
local autoSpinEnabled = loadedConfig.autoSpinEnabled or false
local warningSellEnabled = loadedConfig.warningSellEnabled or false
local sellThreshold = loadedConfig.sellThreshold or 0
local sellEnabled = loadedConfig.sellEnabled or false
local antiRagdollEnabled = loadedConfig.antiRagdollEnabled or false
local hideBuildsEnabled = loadedConfig.hideBuildsEnabled or false
local autoSkipMapEnabled = loadedConfig.autoSkipMapEnabled or false
local autoReconnectEnabled = loadedConfig.autoReconnectEnabled or true
local antiLagEnabled = false
local infiniteJumpEnabled = false

local autoBuyMaxSizeEnabled = loadedConfig.autoBuyMaxSizeEnabled or false
local autoBuySpeedEnabled = loadedConfig.autoBuySpeedEnabled or false
local autoBuyMultiplierEnabled = loadedConfig.autoBuyMultiplierEnabled or false
local autoBuyEatSpeedEnabled = loadedConfig.autoBuyEatSpeedEnabled or false
local autoMoneyRainEnabled = loadedConfig.autoMoneyRainEnabled or false

local lastGrabMoveTime = 0
local currentGrabTarget = nil

local currentPath = nil
local currentWaypointIndex = 1
local pathComputeTime = 0

-- Anti-AFK
Player.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

math.randomseed(os.time())

--==================================================
-- HIDE SPECIFIC ITEM ON LOAD
--==================================================
pcall(function()
    local mapFolder = workspace:FindFirstChild("Map")
    if mapFolder and mapFolder:FindFirstChild("Fragmentable") then
        local children = mapFolder.Fragmentable:GetChildren()
        local itemToHide = children[1828]
        if itemToHide then
            for _, desc in ipairs(itemToHide:GetDescendants()) do
                if desc:IsA("BasePart") or desc:IsA("Decal") or desc:IsA("Texture") then
                    desc.Transparency = 1
                    if desc:IsA("BasePart") then desc.CanCollide = false end
                end
            end
            if itemToHide:IsA("BasePart") then
                itemToHide.Transparency = 1
                itemToHide.CanCollide = false
            end
        end
    end
end)

local function getValidFragments(mapFolder)
    local frags = {}
    if mapFolder and mapFolder:FindFirstChild("Fragmentable") then
        local bedrock = mapFolder:FindFirstChild("Bedrock")
        local bedrockY = -50
        if bedrock and bedrock:IsA("BasePart") then
            bedrockY = bedrock.Position.Y + (bedrock.Size.Y / 2) - 2
        end
        for _, obj in ipairs(mapFolder.Fragmentable:GetChildren()) do
            if obj:IsA("BasePart") and obj.Position.Y >= bedrockY then
                table.insert(frags, obj)
            end
        end
    end
    return frags
end

--==================================================
-- VOID UI INITIALIZATION
--==================================================
local VexUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/slowzzx4-8/Ui-library/refs/heads/main/Void%20Ui%20Library.lua"))()
local Window = VexUI:CreateWindow({
    Name = "Void Hub",
    Icon = "box",
    SideBarWidth = 160,
    Theme = "Dark",
    Transparent = true,
    Author = "By Slowzzx4",
    Resizable = false,
    Size = UDim2.new(0, 537, 0, 361),
    Position = UDim2.new(0.5, 7, 0.5, -47),
    ScrollableSidebar = true, -- Adicionando scroll nas abas para corrigir bugs de visualização
    User = {
        Enabled = true,
        Anonymous = false,
    },
})

-- Topbar Customizada
VexUI:CreateTopbarButton({
    Order = 1,
    Title = "@Slowzzx4",
    Icon = "at-sign",
    Callback = function() end
})

-- Botão abre/fecha (Largura aumentada ainda mais para 140px)
Window:EditOpenButton({
    Title = "Eat The World",
    Icon = "box",
    Transparency = 0.2,
    StrokeThickness = 2,
    Size = UDim2.new(0, 140, 0, 50),
    Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 120, 120)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 80, 80))
    },
    AutoRotation = false,
    CornerRadius = UDim.new(0,16),
})

-- Pop-up inicial recomendando servidor privado (em inglês)
task.spawn(function()
    task.wait(1)
    pcall(function()
        VexUI:Notification({
            Title = "Recommendation",
            Desc = "It is highly recommended to use this script in a Private Server!",
            Duration = 6
        })
    end)
end)

--==================================================
-- TABS
--==================================================
local FarmTab = Window:Tab({Title = "Farm", Icon = "swords", Border = true})
local UpgradeTab = Window:Tab({Title = "Upgrade", Icon = "trending-up", Border = true})
local SellClubesTab = Window:Tab({Title = "Sell Cubes", Icon = "shopping-cart", Border = true})
local EventosTab = Window:Tab({Title = "Events", Icon = "calendar-days", Border = true})
local DiversosTab = Window:Tab({Title = "Misc", Icon = "layout-grid", Border = true})
local ConfigTab = Window:Tab({Title = "Configs", Icon = "save", Border = true})

local Section = Window:Section({ Title = "Other", Icon = "hash" })
local Settings = Section:Tab({ Title = "Settings", Icon = "settings", Border = true})

Window:SelectTab(1)

--==================================================
-- AUTO FARM
--==================================================
FarmTab:Section({Title = "Auto Farm"})

FarmTab:Toggle({
    Title = "Auto Eat Block",
    Desc = "Bypasses eat limits via TemplateChunk exploit.",
    Default = eatEnabled,
    Callback = function(State)
        eatEnabled = State
    end,
})

FarmTab:Toggle({
    Title = "Auto Grab Block",
    Desc = "Pathfinds flawlessly. Anti-Player proximity injected.",
    Default = grabEnabled,
    Callback = function(State)
        grabEnabled = State
        if not State then
            pcall(function()
                currentGrabTarget = nil
                currentPath = nil
                local char = Player.Character
                if char and char:FindFirstChild("Humanoid") and char:FindFirstChild("HumanoidRootPart") then
                    char.HumanoidRootPart.Anchored = false
                    char.Humanoid.WalkSpeed = 16
                    char.Humanoid:MoveTo(char.HumanoidRootPart.Position)
                end
            end)
        end
    end,
})

FarmTab:Toggle({
    Title = "Auto Collect Rewards",
    Desc = "Fires remote continuously for instant claims.",
    Default = rewardsEnabled,
    Callback = function(State)
        rewardsEnabled = State
    end,
})

FarmTab:Toggle({
    Title = "Auto Spin",
    Desc = "Forces SpinEvent ping when timer is zero.",
    Default = autoSpinEnabled,
    Callback = function(State)
        autoSpinEnabled = State
    end,
})

--==================================================
-- UPGRADE
--==================================================
UpgradeTab:Section({Title = "Smart Upgrades"})

UpgradeTab:Toggle({
    Title = "Auto Buy Max Size",
    Desc = "Spams PurchaseEvent instantly if cubes afford it.",
    Default = autoBuyMaxSizeEnabled,
    Callback = function(State)
        autoBuyMaxSizeEnabled = State
    end,
})

UpgradeTab:Toggle({
    Title = "Auto Buy Speed",
    Desc = "Spams PurchaseEvent instantly if cubes afford it.",
    Default = autoBuySpeedEnabled,
    Callback = function(State)
        autoBuySpeedEnabled = State
    end,
})

UpgradeTab:Toggle({
    Title = "Auto Buy Multiplier",
    Desc = "Spams PurchaseEvent instantly if cubes afford it.",
    Default = autoBuyMultiplierEnabled,
    Callback = function(State)
        autoBuyMultiplierEnabled = State
    end,
})

UpgradeTab:Toggle({
    Title = "Auto Buy Eat Speed",
    Desc = "Spams PurchaseEvent instantly if cubes afford it.",
    Default = autoBuyEatSpeedEnabled,
    Callback = function(State)
        autoBuyEatSpeedEnabled = State
    end,
})

--==================================================
-- AUTO SELL
--==================================================
SellClubesTab:Section({Title = "Sell Area"})

SellClubesTab:Toggle({
    Title = "Auto Sell Max Block",
    Desc = "Intercepts max warning GUI to trigger instant sell.",
    Default = warningSellEnabled,
    Callback = function(State)
        warningSellEnabled = State
    end,
})

SellClubesTab:Input({
    Title = "Set Auto Sell Limit",
    Desc = "Target size limit (e.g., 5000).",
    Callback = function(Text)
        local parsed = tonumber(string.match(Text, "%d+"))
        if parsed then sellThreshold = parsed else sellThreshold = 0 end
    end,
})

SellClubesTab:Toggle({
    Title = "Auto Sell Number",
    Desc = "Executes custom sell threshold rules dynamically.",
    Default = sellEnabled,
    Callback = function(State)
        sellEnabled = State
    end,
})

--==================================================
-- EVENTOS
--==================================================
EventosTab:Section({Title = "Event Exploits"})

EventosTab:Toggle({
    Title = "Auto Collect Cubes",
    Desc = "Magnetizes ALL workspace cubes (ignores ownership).",
    Default = cubeCoinsEnabled,
    Callback = function(State)
        cubeCoinsEnabled = State
    end,
})

EventosTab:Toggle({
    Title = "Auto Money Rain",
    Desc = "Triggers SummonEvent continuously (req >=3 tokens).",
    Default = autoMoneyRainEnabled,
    Callback = function(State)
        autoMoneyRainEnabled = State
    end,
})

--==================================================
-- DIVERSOS (Misc)
--==================================================
DiversosTab:Section({Title = "Other Functions"})

DiversosTab:Toggle({
    Title = "Infinite Jump",
    Desc = "Forces StateType jumping on mid-air requests.",
    Default = infiniteJumpEnabled,
    Callback = function(State)
        infiniteJumpEnabled = State
    end,
})
game:GetService("UserInputService").JumpRequest:Connect(function()
    if infiniteJumpEnabled then
        local char = Player.Character
        if char and char:FindFirstChildOfClass("Humanoid") then
            char:FindFirstChildOfClass("Humanoid"):ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

DiversosTab:Toggle({
    Title = "Anti Lag",
    Desc = "Disables shadows & materials to spoof client load.",
    Default = antiLagEnabled,
    Callback = function(State)
        antiLagEnabled = State
    end,
})

DiversosTab:Toggle({
    Title = "Anti Ragdoll",
    Desc = "Directly fires unRagdoll event to keep you standing.",
    Default = antiRagdollEnabled,
    Callback = function(State)
        antiRagdollEnabled = State
    end,
})

DiversosTab:Toggle({
    Title = "Hide ALL Buildings",
    Desc = "Caches map buildings in RepStorage to skyrocket FPS.",
    Default = hideBuildsEnabled,
    Callback = function(State)
        hideBuildsEnabled = State
    end,
})

DiversosTab:Toggle({
    Title = "Auto Skip Map",
    Desc = "Bypasses map loop with SetServerSettings payload.",
    Default = autoSkipMapEnabled,
    Callback = function(State)
        autoSkipMapEnabled = State
    end,
})

DiversosTab:Toggle({
    Title = "Auto Reconnect",
    Desc = "Force rejoin instance upon network drop.",
    Default = autoReconnectEnabled,
    Callback = function(State)
        autoReconnectEnabled = State
    end,
})

--==================================================
-- CONFIGS (SAVE/LOAD) - Em Inglês
--==================================================
ConfigTab:Section({Title = "Configuration Data"})

ConfigTab:Button({
    Title = "Save Configuration",
    Callback = function()
        local currentSettings = {
            eatEnabled = eatEnabled,
            grabEnabled = grabEnabled,
            cubeCoinsEnabled = cubeCoinsEnabled,
            rewardsEnabled = rewardsEnabled,
            autoSpinEnabled = autoSpinEnabled,
            warningSellEnabled = warningSellEnabled,
            sellThreshold = sellThreshold,
            sellEnabled = sellEnabled,
            antiRagdollEnabled = antiRagdollEnabled,
            hideBuildsEnabled = hideBuildsEnabled,
            autoSkipMapEnabled = autoSkipMapEnabled,
            autoReconnectEnabled = autoReconnectEnabled,
            antiLagEnabled = antiLagEnabled,
            infiniteJumpEnabled = infiniteJumpEnabled,
            autoBuyMaxSizeEnabled = autoBuyMaxSizeEnabled,
            autoBuySpeedEnabled = autoBuySpeedEnabled,
            autoBuyMultiplierEnabled = autoBuyMultiplierEnabled,
            autoBuyEatSpeedEnabled = autoBuyEatSpeedEnabled,
            autoMoneyRainEnabled = autoMoneyRainEnabled
        }

        if writefile then
            local json = HttpService:JSONEncode(currentSettings)
            writefile(ConfigFile, json)
            VexUI:Notification({Title = "Configuration Saved!", Desc = "Your preferences have been successfully stored.", Duration = 3})
        else
            VexUI:Notification({Title = "Save Failed", Desc = "Your executor does not support writefile.", Duration = 3})
        end
    end
})

ConfigTab:Button({
    Title = "Delete Configuration",
    Callback = function()
        if delfile and isfile and isfile(ConfigFile) then
            delfile(ConfigFile)
            VexUI:Notification({Title = "Configuration Deleted!", Desc = "Default values will apply on next execution.", Duration = 3})
        else
            VexUI:Notification({Title = "File Not Found", Desc = "No saved configuration file exists.", Duration = 3})
        end
    end
})

--==================================================
-- ABA SETTINGS
--==================================================
Settings:Section({Title = "Window Configuration"})

Settings:Dropdown({
	Title = "Theme",
	Option = {"Dark","Light","Forest","Amethyst"},
	Value = "Dark",
	Callback = function(Value)
		Window:SetTheme(Value)
	end
})

Settings:Toggle({
    Title = "Transparent UI",
    Default = true,
    Callback = function(Value)
        Window:SetTransparency(Value)
    end
})

local SettingsGroup = Settings:Group({})
SettingsGroup:Toggle({
    Title = "UI Resizing",
    Default = false,
    Callback = function(Value)
        Window:SetResizable(Value)
    end
})

SettingsGroup:Keybind({
    Title = "Toggle UI Keybind",
    Callback = function(key)
        Window:SetToggleKey(Enum.KeyCode[key])
    end
})

local n1, n2 = 537, 361 
Settings:Section({Title = "Manual Size Control"})
Settings:Slider({
    Title = "X Size",
    Value = { Min = 410, Max = 700, Default = 537 },
    Step = 1,
    Callback = function(Value) n1 = Value end
})
Settings:Slider({
    Title = "Z Size",
    Value = { Min = 280, Max = 700, Default = 361 },
    Step = 1,
    Callback = function(Value) n2 = Value end
})
Settings:Button({
    Title = "Apply New Size",
    Callback = function()
        Window:Resize(n1, n2)
    end
})

Settings:Section({Title = "Actions"})
Settings:Button({
    Title = "To Center",
    Callback = function()
        Window:ToCenter()
    end
})
Settings:Button({
    Title = "Destroy UI",
    Callback = function()
        Window:Destroy()
    end
})

Settings:Section({Title = ""})
Settings:Section({Title = "User Settings"})
Settings:Toggle({
    Title = "User Enabled",
    Default = true,
    Callback = function(Value)
        Window:UserEnabled(Value)
    end
})

Settings:Toggle({
    Title = "Anonymous Mode",
    Default = false,
    Callback = function(Value)
        Window:Anonymous(Value)
    end
})

--==================================================
-- BACKGROUND LOOPS
--==================================================

-- Loop: Auto Reconnect
GuiService.ErrorMessageChanged:Connect(function()
    if autoReconnectEnabled then
        task.wait(0.1)
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, Player)
    end
end)

-- Loop: Smart Upgrades (MaxSize, Speed, Multiplier, EatSpeed)
task.spawn(function()
    local upgradeList = {
        {Name = "MaxSize", Check = function() return autoBuyMaxSizeEnabled end},
        {Name = "Speed", Check = function() return autoBuySpeedEnabled end},
        {Name = "Multiplier", Check = function() return autoBuyMultiplierEnabled end},
        {Name = "EatSpeed", Check = function() return autoBuyEatSpeedEnabled end},
    }

    while task.wait(1) do
        pcall(function()
            local gui = Player:FindFirstChild("PlayerGui")
            if gui and gui:FindFirstChild("ScreenGui") then
                local shop = gui.ScreenGui:FindFirstChild("Shop")
                if shop then
                    local cubesLabel = shop.CubeFrame.CounterFrame:FindFirstChild("Cubes")
                    if cubesLabel then
                        local cubesTxt = string.gsub(cubesLabel.Text, "%D", "")
                        local cubes = tonumber(cubesTxt) or 0
                        
                        for _, upg in ipairs(upgradeList) do
                            if upg.Check() then
                                local upgradeFrame = shop.ShopFrames.Upgrades.UpgradeList:FindFirstChild(upg.Name)
                                if upgradeFrame then
                                    local priceLabel = upgradeFrame.BuyFrame:FindFirstChild("Price")
                                    if priceLabel then
                                        local priceTxt = string.gsub(priceLabel.Text, "%D", "")
                                        local price = tonumber(priceTxt) or math.huge
                                        
                                        if cubes >= price and price > 0 then
                                            ReplicatedStorage.Events.PurchaseEvent:FireServer(upg.Name)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end)
    end
end)

-- Loop: Auto Money Rain
task.spawn(function()
    while task.wait(1) do
        if autoMoneyRainEnabled then
            pcall(function()
                local tokens = Player:FindFirstChild("Tokens")
                if tokens and tokens.Value >= 3 then
                    ReplicatedStorage.Events.SummonEvent:FireServer("Money Rain")
                end
            end)
        end
    end
end)

-- Loop: Anti Lag
task.spawn(function()
    while task.wait(1) do
        if antiLagEnabled then
            pcall(function()
                game.Lighting.GlobalShadows = false
                for _, obj in ipairs(workspace:GetDescendants()) do
                    if obj:IsA("BasePart") and obj.CastShadow then
                        obj.Material = Enum.Material.SmoothPlastic
                        obj.Reflectance = 0
                        obj.CastShadow = false
                    end
                end
            end)
        end
    end
end)

-- Loop: ANTI-VOID & KEEP INSIDE BEDROCK AREA
task.spawn(function()
    while task.wait(0.1) do
        pcall(function()
            local char = Player.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local root = char.HumanoidRootPart
                local map = workspace:FindFirstChild("Map")
                local bedrock = map and map:FindFirstChild("Bedrock")

                if bedrock and bedrock:IsA("BasePart") then
                    local lowestY = bedrock.Position.Y + (bedrock.Size.Y / 2) - 3
                    
                    if root.Position.Y < lowestY then
                        local safeCFrame = CFrame.new(0, lowestY + 40, 0)
                        local frags = getValidFragments(map)
                        if #frags > 0 then
                            local rFrag = frags[math.random(1, #frags)]
                            safeCFrame = rFrag.CFrame + Vector3.new(0, 15, 0)
                        end

                        root.Anchored = false
                        root.CFrame = safeCFrame
                        currentPath = nil
                    end

                    local bedSize = bedrock.Size
                    local bedPos = bedrock.Position
                    
                    local minX = bedPos.X - (bedSize.X / 2)
                    local maxX = bedPos.X + (bedSize.X / 2)
                    local minZ = bedPos.Z - (bedSize.Z / 2)
                    local maxZ = bedPos.Z + (bedSize.Z / 2)

                    local currentX = root.Position.X
                    local currentZ = root.Position.Z

                    local clampedX = math.clamp(currentX, minX, maxX)
                    local clampedZ = math.clamp(currentZ, minZ, maxZ)

                    if currentX ~= clampedX or currentZ ~= clampedZ then
                        root.CFrame = CFrame.new(clampedX, root.Position.Y, clampedZ)
                    end
                end
            end
        end)
    end
end)

-- Loop: Auto Spin
task.spawn(function()
    while task.wait(1) do
        if autoSpinEnabled then
            pcall(function()
                local timeLabel = Player.PlayerGui.ScreenGui.Rewards.Spin.NextSpin.Time
                if timeLabel and timeLabel.Text then
                    local justNumbers = string.gsub(timeLabel.Text, "%D", "")
                    if justNumbers == "" or tonumber(justNumbers) == 0 then
                        local Event = ReplicatedStorage.Events:FindFirstChild("SpinEvent")
                        if Event then Event:FireServer() end
                    end
                end
            end)
        end
    end
end)

-- Loop: Auto Eat Block
task.spawn(function()
    while task.wait(0.2) do
        if eatEnabled then
            pcall(function()
                if workspace:FindFirstChild("Chunks") and workspace.Chunks:FindFirstChild("TemplateChunk") then
                    local char = Player.Character
                    if char and char:FindFirstChild("Events") and char.Events:FindFirstChild("Eat") then
                        char.Events.Eat:FireServer()
                    end
                end
            end)
        end
    end
end)

-- Loop: Auto Grab Block & Anti-Player
task.spawn(function()
    while task.wait(0.1) do
        if grabEnabled then
            pcall(function()
                local char = Player.Character
                if not char then return end

                local root = char:FindFirstChild("HumanoidRootPart")
                local hum = char:FindFirstChild("Humanoid")
                local mapFolder = workspace:FindFirstChild("Map")

                if root and hum and hum.Health > 0 then

                    -- ====== ANTI-PLAYER RANGE (Safe Distance) ======
                    local safeDistance = 30
                    local playerTooClose = false

                    for _, other in ipairs(Players:GetPlayers()) do
                        if other ~= Player and other.Character and other.Character:FindFirstChild("HumanoidRootPart") then
                            local dist = (other.Character.HumanoidRootPart.Position - root.Position).Magnitude
                            if dist < safeDistance then
                                playerTooClose = true
                                break
                            end
                        end
                    end

                    if playerTooClose and mapFolder then
                        local allFrags = getValidFragments(mapFolder)
                        local distantFrags = {}
                        for _, f in ipairs(allFrags) do
                            if (f.Position - root.Position).Magnitude > 60 then
                                table.insert(distantFrags, f)
                            end
                        end
                        if #distantFrags > 0 then
                            local escapeFrag = distantFrags[math.random(1, #distantFrags)]
                            root.CFrame = escapeFrag.CFrame + Vector3.new(0, 15, 0)
                            currentPath = nil
                            currentGrabTarget = nil
                        end
                        task.wait(0.5)
                        return
                    end
                    -- ===============================================

                    local rayOrigin = root.Position
                    local rayParams = RaycastParams.new()
                    rayParams.FilterDescendantsInstances = {char}
                    rayParams.FilterType = Enum.RaycastFilterType.Exclude

                    local rayDirectionDown = Vector3.new(0, -8, 0)
                    local floorHit = workspace:Raycast(rayOrigin, rayDirectionDown, rayParams)
                    local isOnGround = (hum.FloorMaterial ~= Enum.Material.Air)

                    if isOnGround then
                        hum:ChangeState(Enum.HumanoidStateType.Jumping)
                        hum.Jump = true 
                    end

                    local isOnBedrock = false
                    if floorHit and floorHit.Instance then
                        if mapFolder and mapFolder:FindFirstChild("Bedrock") then
                            if floorHit.Instance == mapFolder.Bedrock or floorHit.Instance:IsDescendantOf(mapFolder.Bedrock) then
                                isOnBedrock = true
                            end
                        end
                    end

                    if isOnGround and not isOnBedrock and char:FindFirstChild("Events") and char.Events:FindFirstChild("Grab") then
                        char.Events.Grab:FireServer(false, false, false)
                    end

                    if mapFolder then
                        local fragments = getValidFragments(mapFolder)
                        if #fragments > 0 then
                            local distToTarget = currentGrabTarget and (root.Position - currentGrabTarget.Position).Magnitude or math.huge

                            if not currentGrabTarget or distToTarget < 3 or (tick() - lastGrabMoveTime > 6) then
                                lastGrabMoveTime = tick()
                                
                                local distantTargets = {}
                                for _, frag in ipairs(fragments) do
                                    if (frag.Position - root.Position).Magnitude > 30 then
                                        table.insert(distantTargets, frag)
                                    end
                                end
                                
                                if #distantTargets > 0 then
                                    currentGrabTarget = distantTargets[math.random(1, #distantTargets)]
                                else
                                    currentGrabTarget = fragments[math.random(1, #fragments)]
                                end
                                
                                currentPath = nil 
                            end

                            if currentGrabTarget then
                                local targetPos = currentGrabTarget.Position + Vector3.new(0, 5, 0)
                                root.Anchored = false
                                hum.WalkSpeed = 60 

                                if isOnBedrock then
                                    local rFrag = fragments[math.random(1, #fragments)]
                                    root.CFrame = rFrag.CFrame + Vector3.new(0, 15, 0)
                                    currentPath = nil
                                    task.wait(0.3) 
                                    return
                                end

                                if tick() - pathComputeTime > 1.5 or not currentPath then
                                    pathComputeTime = tick()
                                    local path = PathfindingService:CreatePath({
                                        AgentRadius = 2,
                                        AgentHeight = 5,
                                        AgentCanJump = true
                                    })

                                    local success, _ = pcall(function()
                                        path:ComputeAsync(root.Position, targetPos)
                                    end)

                                    if success and path.Status == Enum.PathStatus.Success then
                                        currentPath = path:GetWaypoints()
                                        currentWaypointIndex = 2
                                    else
                                        currentPath = nil
                                    end
                                end

                                if currentPath and currentWaypointIndex <= #currentPath then
                                    local wp = currentPath[currentWaypointIndex]
                                    local flatDist = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(wp.Position.X, 0, wp.Position.Z)).Magnitude

                                    if flatDist < 3 then
                                        currentWaypointIndex = currentWaypointIndex + 1
                                        if currentWaypointIndex <= #currentPath then
                                            wp = currentPath[currentWaypointIndex]
                                        end
                                    end

                                    if wp then
                                        hum:MoveTo(wp.Position)
                                    end
                                else
                                    hum:MoveTo(targetPos)
                                end
                            end
                        end
                    end
                end
            end)
        end
    end
end)

-- Loop: Anti Ragdoll
task.spawn(function()
    while task.wait(0.5) do
        if antiRagdollEnabled then
            pcall(function()
                game.ReplicatedStorage.Events.unRagdoll:FireServer()
            end)
        end
    end
end)

-- Loop: Auto Skip Map
task.spawn(function()
    while task.wait(60) do
        if autoSkipMapEnabled then
            pcall(function()
                local Event = ReplicatedStorage.Events:FindFirstChild("SetServerSettings")
                if Event then Event:FireServer({ MapTime = 0 }) end
            end)
        end
    end
end)

-- Loop: Auto Sell Max Block
task.spawn(function()
    while task.wait(1) do
        if warningSellEnabled then
            pcall(function()
                local screenGui = Player:FindFirstChild("PlayerGui") and Player.PlayerGui:FindFirstChild("ScreenGui")
                if screenGui and screenGui:FindFirstChild("Sell") and screenGui.Sell:FindFirstChild("WarningText") then
                    if screenGui.Sell.WarningText.Visible then
                        local char = Player.Character
                        if char and char:FindFirstChild("Events") and char.Events:FindFirstChild("Sell") then
                            char.Events.Sell:FireServer()
                        end
                    end
                end
            end)
        end
    end
end)

-- Loop: Auto Sell Number
task.spawn(function()
    while task.wait(1) do
        if sellEnabled and sellThreshold > 0 then
            pcall(function()
                local leaderstats = Player:FindFirstChild("leaderstats")
                if leaderstats and leaderstats:FindFirstChild("Size") then
                    local currentSize = tonumber(leaderstats.Size.Value) or 0
                    if currentSize >= sellThreshold then
                        local char = Player.Character
                        if char and char:FindFirstChild("Events") and char.Events:FindFirstChild("Sell") then
                            char.Events.Sell:FireServer()
                        end
                    end
                end
            end)
        end
    end
end)

-- Loop: Auto Collect Coins
task.spawn(function()
    while task.wait(0.2) do
        if cubeCoinsEnabled then
            pcall(function()
                local char = Player.Character
                if char and char:FindFirstChild("HumanoidRootPart") then
                    local rootCFrame = char.HumanoidRootPart.CFrame
                    for _, obj in ipairs(workspace:GetDescendants()) do
                        if obj.Name == "Cube" and obj:IsA("BasePart") then
                            if obj:FindFirstChild("TouchInterest") then
                                if firetouchinterest then
                                    firetouchinterest(char.HumanoidRootPart, obj, 0)
                                    task.wait()
                                    firetouchinterest(char.HumanoidRootPart, obj, 1)
                                else
                                    obj.CFrame = rootCFrame
                                end
                            end
                            obj.Transparency = 1
                            for _, child in ipairs(obj:GetDescendants()) do
                                if child:IsA("BasePart") or child:IsA("Decal") or child:IsA("Texture") then
                                    child.Transparency = 1
                                elseif child:IsA("ParticleEmitter") or child:IsA("Trail") or child:IsA("Beam") or child:IsA("Light") then
                                    child.Enabled = false
                                end
                            end
                        end
                    end
                end
            end)
        end
    end
end)

-- Loop: Auto Collect Rewards
task.spawn(function()
    while task.wait(3) do
        if rewardsEnabled then
            pcall(function()
                local timedRewards = Player:FindFirstChild("TimedRewards")
                if timedRewards then
                    local children = timedRewards:GetChildren()
                    for i = 1, math.min(9, #children) do
                        pcall(function()
                            ReplicatedStorage.Events.RewardEvent:FireServer(children[i])
                        end)
                        task.wait(0.1)
                    end
                end
            end)
        end
    end
end)

-- Loop: Hide ALL Buildings
task.spawn(function()
    while task.wait(1) do
        pcall(function()
            local map = workspace:FindFirstChild("Map")
            if hideBuildsEnabled then
                if map and map:FindFirstChild("Buildings") then
                    map.Buildings.Name = "Buildings_Hidden"
                    map.Buildings_Hidden.Parent = ReplicatedStorage
                end
            else
                if ReplicatedStorage:FindFirstChild("Buildings_Hidden") then
                    ReplicatedStorage.Buildings_Hidden.Name = "Buildings"
                    ReplicatedStorage.Buildings.Parent = map
                end
            end
        end)
    end
end)

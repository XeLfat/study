-- ตัวแปร
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local plr = Players.LocalPlayer
local Tutorial = plr.PlayerGui.HUD:WaitForChild("Tutorial")
local Plots = workspace.Plots
local RS = game:GetService("ReplicatedStorage")
local BuyItem = RS:WaitForChild("Remotes"):WaitForChild("BuyItem")
local PlaceItem = RS:WaitForChild("Remotes"):WaitForChild("PlaceItem")
local vim = game:GetService("VirtualInputManager")
local currentPlot = nil
local GeorgePos = nil

local function Walk(targetPosition)
    local character = plr.Character
    if not character then return end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    -- ให้ตัวละครเดินไปที่ตำแหน่งเป้าหมาย
    humanoid:MoveTo(targetPosition)

    -- เช็คตอนถึงเป้าหมาย
    humanoid.MoveToFinished:Wait()
end

local function Findplot()
    for i, plot in ipairs(Plots:GetChildren()) do
        local playerSign = plot:FindFirstChild("PlayerSign")
        if playerSign then
            local billboard = playerSign:FindFirstChild("BillboardGui")
            if billboard then
                local textLabel = billboard:FindFirstChild("TextLabel")
                if textLabel.Text == plr.Name then
                    currentPlot = plot
                end
            end
        end
    end
end
local function FindGeorge()
    local george = currentPlot:WaitForChild("NPCs"):WaitForChild("George")
                       :WaitForChild("RootPart")
    GeorgePos = george.Position + Vector3.new(4, 0, 0)
    print(GeorgePos)
end

local function BuySeed(seedName) BuyItem:FireServer(seedName) end

if Tutorial.Visible then
    Findplot()
    FindGeorge()
    Walk(GeorgePos)
    vim:SendKeyEvent(true, Enum.KeyCode.E, false, game)
    task.wait(0.1)
    vim:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    for i = 1, 2 do
    BuySeed("Cactus Seed")
    asd
    end
end

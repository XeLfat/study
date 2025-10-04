-- ===== CONFIG =====
local ITEM_NAME = "Cactus"
local ITEM_ID = "c67c7669-6c8b-4ecb-9c67-44aba3c7a3d6"
local PLANT_DELAY = 1.2

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
--Functions
local function Walk(targetPosition, timeout)
    timeout = timeout or 8
    local character = plr.Character or plr.CharacterAdded:Wait()
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return
    end

    humanoid:MoveTo(targetPosition)
    local t0 = tick()
    while tick() - t0 < timeout do
        if (humanoid.RootPart.Position - targetPosition).Magnitude < 3 then
            break
        end
        if humanoid.MoveToFinished:Wait(0.25) then
            break
        end
        humanoid:MoveTo(targetPosition)
    end
end

local function Findplot()
    for _, plot in ipairs(Plots:GetChildren()) do
        local playerSign = plot:FindFirstChild("PlayerSign")
        local billboard = playerSign and playerSign:FindFirstChild("BillboardGui")
        local textLabel = billboard and billboard:FindFirstChild("TextLabel")
        if textLabel and textLabel.Text == plr.Name then
            currentPlot = plot
            return plot
        end
    end
    return nil
end

-- ก่อนใช้ ต้องรอให้เจอ
while not Findplot() do
    task.wait(0.25)
end

local function FindGeorge()
    assert(currentPlot, "currentPlot is nil")
    local georgeRoot = currentPlot:WaitForChild("NPCs"):WaitForChild("George"):WaitForChild("HumanoidRootPart")
    GeorgePos = georgeRoot.Position + Vector3.new(4, 0, 0)
end

local function BuySeed(seedName)
    BuyItem:FireServer(seedName)
end

local function getGrassTiles(plot)
    local tiles, rows = {}, plot and plot:FindFirstChild("Rows")
    if not rows then
        return tiles
    end
    for _, row in ipairs(rows:GetChildren()) do
        local grassFolder = row:FindFirstChild("Grass")
        if grassFolder then
            for _, inst in ipairs(grassFolder:GetChildren()) do
                if inst:IsA("BasePart") then
                    table.insert(tiles, inst)
                end
            end
        end
    end
    return tiles
end

local function randomCFrameOnTop(part)
    local margin = 0.15
    local halfX = part.Size.X * (0.5 - margin)
    local halfZ = part.Size.Z * (0.5 - margin)
    local ox = (math.random() * 2 - 1) * halfX
    local oz = (math.random() * 2 - 1) * halfZ
    local pos = (part.CFrame * CFrame.new(ox, part.Size.Y / 2, oz)).Position
    return CFrame.new(pos)
end

local function isTileEmpty(tile)
    local occ = tile:GetAttribute("Occupied")
    if occ ~= nil then
        return not occ
    end
    -- fallback: ไม่มี attribute ก็เช็กลูกหยาบ ๆ
    for _, c in ipairs(tile:GetChildren()) do
        if c:IsA("Model") or c:IsA("BasePart") then
            return false
        end
    end
    return true
end

local function pickEmptyThenAny(tiles)
    local empty = {}
    for _, t in ipairs(tiles) do
        if isTileEmpty(t) then
            table.insert(empty, t)
        end
    end
    local list = (#empty > 0) and empty or tiles
    return list[math.random(1, #list)]
end

local function plant(tile)
    PlaceItem:FireServer(
        {
            ID = ITEM_ID,
            CFrame = randomCFrameOnTop(tile),
            Item = ITEM_NAME,
            Floor = tile
        }
    )
end

if Tutorial.Visible then
    local character = plr.Character
    if not character then
        return
    end

    local hrp = (plr.Character or plr.CharacterAdded:Wait()):WaitForChild("HumanoidRootPart")
    local plpos = hrp.Position
    Findplot()
    FindGeorge()
    Walk(GeorgePos)
    vim:SendKeyEvent(true, Enum.KeyCode.E, false, game)
    task.wait(0.1)
    vim:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    task.wait(2)
    BuySeed("Cactus Seed")
    task.wait(1)
    BuySeed("Cactus Seed")
    task.wait(1)
    Walk(plpos)
    task.wait(2)
    for i = 1, 2 do
        local tiles = getGrassTiles(currentPlot) -- รีเฟรชทุกรอบ
        if #tiles > 0 then
            local t = pickEmptyThenAny(tiles)
            plant(t)
            task.wait(PLANT_DELAY)
        end
    end
end

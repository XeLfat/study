-- ===== CONFIG =====
local ITEM_NAME = "Cactus"
local ITEM_ID   = "c67c7669-6c8b-4ecb-9c67-44aba3c7a3d6"
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

local function getGrassTiles(plot: Instance)
    local tiles = {}
    local rows = plot:FindFirstChild("Rows")
    if not rows then return tiles end

    -- ไล่ทุกโฟลเดอร์แถว (1..7) ที่เห็นในรูป
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

local function randomCFrameOnTop(part: BasePart)
    local margin = 0.1
    local halfX = part.Size.X * (0.5 - margin)
    local halfZ = part.Size.Z * (0.5 - margin)
    local ox = (math.random()*2 - 1) * halfX
    local oz = (math.random()*2 - 1) * halfZ
    local pos = (part.CFrame * CFrame.new(ox, part.Size.Y/2, oz)).Position
    return CFrame.new(pos)
end

local function isTileEmpty(tile: BasePart)
    -- ตัวอย่าง: ถ้ามี Model/Part ลูกอยู่ แปลว่าไม่ว่าง
    for _, c in ipairs(tile:GetChildren()) do
        if c:IsA("Model") or c:IsA("BasePart") then
            return false
        end
    end
    -- หากเกมมี Attribute/Value บอกสถานะ เช่น tile:GetAttribute("Occupied")
    -- ก็เช็กเพิ่มได้ที่นี่
    return true
end

local function plant(tile: BasePart)
    PlaceItem:FireServer({
        ID = ITEM_ID,
        CFrame = randomCFrameOnTop(tile),
        Item = ITEM_NAME,
        Floor = tile
    })
end

if Tutorial.Visible then
  local character = plr.Character
    if not character then return end

    local humanoid = character:WaitForChild("HumanoidRootPart")
    
  local plpos = humanoid.Position
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
    local allTiles = getGrassTiles(currentPlot)
    for i = 1,2 do
    if #allTiles > 0 then
        -- เลือกเฉพาะที่ว่างก่อน; ถ้าว่างไม่มีเลยก็สุ่มจากทั้งหมด
        local empty = {}
        for _, t in ipairs(allTiles) do
            if isTileEmpty(t) then table.insert(empty, t) end
        end
        local pickFrom = (#empty > 0) and empty or allTiles
        local target = pickFrom[math.random(1, #pickFrom)]
        plant(target)
        end
    end
    task.wait(PLANT_DELAY)
end

-- บันทึก
-- git add .
-- git commit -m "ข้อความ"
-- git push origin main
-- loadstring
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/XeLfat/study/refs/heads/main/tmith.lua"))()
-- https://pastebin.com/raw/CX2pQcmE
-- loadstring(game:HttpGet("https://pastebin.com/raw/CX2pQcmE"))()
-- คำสั่งเอาไฟล์ github มาใส่เครื่องเรา
-- # อยู่ในโฟลเดอร์โปรเจกต์ของคุณ
-- git status
-- git remote -v
-- git fetch origin
-- git branch -M main               # ให้แน่ใจว่าใช้ชื่อ main
-- git pull --rebase origin main --allow-unrelated-histories
-- # ถ้ามี conflict ให้แก้ไฟล์ แล้วรัน:
-- git add .
-- git rebase --continue            # ทำซ้ำจนจบ rebase
-- git push -u origin main

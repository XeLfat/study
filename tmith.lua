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
local BrainrotPos = nil

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
                    local CanPlace = inst:GetAttribute("CanPlace")
                    if CanPlace then
                        table.insert(tiles, inst)
                    end
                end
            end
        end
    end
    print("[GrassTiles] พบ", #tiles, "บล็อกที่ปลูกได้")
    return tiles
end

local function randomPointOnTile(tile, margin)
    margin = margin or 0.15
    local halfX = tile.Size.X * (0.5 - margin)
    local halfZ = tile.Size.Z * (0.5 - margin)
    local ox = (math.random() * 2 - 1) * halfX
    local oz = (math.random() * 2 - 1) * halfZ
    local pos = (tile.CFrame * CFrame.new(ox, tile.Size.Y / 2, oz)).Position
    return pos
end

local function getExistingPlants(plot)
    local plantsFolder = plot:FindFirstChild("Plants")
    local plants = {}
    if not plantsFolder then
        return plants
    end
    for _, p in ipairs(plantsFolder:GetChildren()) do
        if p:GetAttribute("Owner") == plr.Name then
            local pos = p:GetAttribute("Position")
            local size = p:GetAttribute("Size") or 1
            if typeof(pos) == "Vector3" then
                table.insert(plants, {position = pos, size = size})
            end
        end
    end
    return plants
end

local function isSpotFree(point, plants, minGap)
    minGap = minGap or 0.6 -- เว้นระยะขั้นต่ำ (ปรับได้)
    for _, pl in ipairs(plants) do
        -- ใช้ size ของพืชช่วยกันชน (เผื่อบางชนิดใหญ่)
        local needGap = math.max(minGap, (pl.size or 1) * 0.5)
        if (point - pl.position).Magnitude <= needGap then
            return false
        end
    end
    return true
end

local function pickRandomFreePoint(tile, plants, tries, margin, minGap)
    tries = tries or 12
    for _ = 1, tries do
        local pt = randomPointOnTile(tile, margin)
        if isSpotFree(pt, plants, minGap) then
            return pt
        end
    end
    return nil -- ไม่เจอจุดว่างภายในจำนวนครั้งที่กำหนด
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

local function findLatestCactusId(seed)
    -- 1) หาใน Backpack / Character (บางเกมยัด Attribute "ID" ไว้ที่ Tool)
    local containers = {plr.Backpack, plr.Character}
    for _, container in ipairs(containers) do
        if container then
            for _, tool in ipairs(container:GetChildren()) do
                if tool:IsA("Tool") then
                    local itemName = tool:GetAttribute("ItemName")
                    if itemName == seed then
                        local id = tool:GetAttribute("ID")
                        if id then
                            return id
                        end
                    end
                end
            end
        end
    end
    return nil
end

local function EquipTool(toolItemName) -- ใช้ Attribute ItemName เช่น "Cactus Seed"
    local character = plr.Character or plr.CharacterAdded:Wait()

    -- 1) ถ้าถืออยู่แล้ว ให้ใช้ต่อได้เลย
    for _, tool in ipairs(character:GetChildren()) do
        if tool:IsA("Tool") and tool:GetAttribute("ItemName") == toolItemName then
            return tool
        end
    end

    -- 2) ถ้าอยู่ใน Backpack ให้ย้ายมาถือ
    local backpack = plr:FindFirstChild("Backpack")
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") and tool:GetAttribute("ItemName") == toolItemName then
                tool.Parent = character
                -- รอให้ถือสำเร็จจริง
                for _ = 1, 15 do
                    if character:FindFirstChild(tool.Name) then
                        break
                    end
                    task.wait(0.05)
                end
                return tool
            end
        end
    end

    warn("❌ ไม่พบ Tool สำหรับ:", toolItemName)
    return nil
end
local function plant(tile, seed)
    -- หา ID ล่าสุดของเมล็ด (จาก Backpack / Character)
    local id = findLatestCactusId(seed)
    if not id then
        warn("❌ หา ID ของ " .. seed .. " ไม่เจอ")
        return
    end

    -- ถือ Tool ก่อน (ต้องถือก่อนยิง Remote)
    local tool = EquipTool(seed)
    if not tool then
        warn("⚠️ ไม่มี Tool ให้ถือ:", seed)
        return
    end

    -- หา “จุดสุ่ม” ที่จะปลูก (ไม่ชนพืชเดิม)
    local planted = getExistingPlants(currentPlot)
    local spot = pickRandomFreePoint(tile, planted, 12, 0.15, 0.6)
    if not spot then
        warn("❌ ไม่มีจุดว่างใน tile นี้")
        return
    end

    -- แยกชื่อ Item จาก seed ("Cactus Seed" → "Cactus")
    local plantitem = seed:match("^(%S+)")

    -- ยิง Remote (ตาม RemoteSpy)
    local args = {
        {
            ID = id,
            CFrame = CFrame.new(spot),
            Item = plantitem,
            Floor = tile
        }
    }

    print(string.format("🌱 ปลูก %s (%s) ที่ตำแหน่ง (%.1f, %.1f, %.1f)", plantitem, id, spot.X, spot.Y, spot.Z))
    game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("PlaceItem"):FireServer(unpack(args))

    -- แคชตำแหน่งไว้กันสุ่มซ้ำในรอบเดียวกัน
    table.insert(planted, {position = spot, size = 1})
end

local function brainrodspart(plot)
    local brainrots = plot:FindFirstChild("Brainrots")
    if not brainrots then
        return
    end
    for _, brainrot in ipairs(brainrots:GetChildren()) do
        local Enabled = brainrot:GetAttribute("Enabled")
        if Enabled then
            local brainrotbase = brainrot
            for _, v in ipairs(brainrotbase:GetChildren()) do
                if v:IsA("BasePart") and v.Name == "Center" then
                    BrainrotPos = v.Position
                end
            end
        end
    end
end
if Tutorial.Visible then
    local character = plr.Character
    if not character then
        return
    end

    local hrp = (plr.Character or plr.CharacterAdded:Wait()):WaitForChild("HumanoidRootPart")
    local plpos = hrp.Position
    Findplot()
    print(currentPlot)
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
        local tiles = getGrassTiles(currentPlot)
        if #tiles == 0 then
            warn("❌ ไม่พบ tile ที่ปลูกได้")
            break
        end

        local planted = getExistingPlants(currentPlot)
        local tile = pickEmptyThenAny(tiles)

        if tile and tile:GetAttribute("CanPlace") then
            -- ✅ ถ้าวางได้ ค่อยทำงานต่อ
            local seed = "Cactus Seed"
            local tool = EquipTool(seed)
            if tool then
                local char = plr.Character or plr.CharacterAdded:Wait()
                for _ = 1, 15 do
                    if char:FindFirstChild(tool.Name) then
                        break
                    end
                    task.wait(0.05)
                end

                plant(tile, seed)
                task.wait(PLANT_DELAY + 0.1)
            else
                warn("⚠️ ไม่มี Tool สำหรับ:", seed)
            end
        else
            -- ❌ ถ้าวางไม่ได้ แค่ข้ามเฉย ๆ ไม่ต้อง continue
            warn("⚠️ Tile นี้วางไม่ได้ ข้าม")
        end
    end
    task.wait(15)
    local brainrod = "Noobini Bananini"
    local tool = EquipTool(brainrod)
    if tool then
        local char = plr.Character or plr.CharacterAdded:Wait()
        for _ = 1, 15 do
            if char:FindFirstChild(tool.Name) then
                break
            end
            task.wait(0.05)
        end
    else
        warn("⚠️ ไม่มี Tool สำหรับ:", brainrod)
    end
    brainrodspart(currentPlot)
    Walk(BrainrotPos)
    task.wait(1)
    vim:SendKeyEvent(true, Enum.KeyCode.E, false, game)
    task.wait(2)
    vim:SendKeyEvent(false, Enum.KeyCode.E, false, game)
end

-- =========================
-- Plants vs Brainrots – Auto Loop (No-Walk + Webhook + Collect/1min)
-- by you & helper 😄
-- =========================
_G.Enabled = true

-- ===== CONFIG =====
local PLANT_DELAY = 1.2
local COLLECT_INTERVAL = 60 -- วินาที: เดินเก็บเงินทุก ๆ 1 นาที
local MAX_PLATFORM_IDX = 80 -- ไล่ตรวจแพลตฟอร์มได้สูงสุดถึงหมายเลขนี้
local WEBHOOK_URL = "PUT_YOUR_WEBHOOK_HERE" -- วาง URL Discord Webhook (หรือ "" ถ้าไม่ใช้)
local MAX_ROW_IDX = 7
-- ===== SERVICES =====
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local VIM = game:GetService("VirtualInputManager")
local Http = game:GetService("HttpService")
local plr = Players.LocalPlayer
local Plots = workspace:WaitForChild("Plots")

-- ===== WEBHOOK HELPERS (optional) =====
local function _postWebhook(payload)
    if not WEBHOOK_URL or WEBHOOK_URL == "" then
        return
    end
    local req = getgenv().http_request or request or (syn and syn.request) or http_request
    local body = Http:JSONEncode(payload)
    local headers = {["Content-Type"] = "application/json"}
    if req then
        pcall(
            function()
                req({Url = WEBHOOK_URL, Method = "POST", Headers = headers, Body = body})
            end
        )
    end
end
local function sendText(msg)
    _postWebhook({content = msg, username = "AutoPvB"})
end
local function sendEmbed(title, desc, color, fields)
    _postWebhook(
        {
            username = "AutoPvB",
            embeds = {
                {
                    title = title,
                    description = desc,
                    color = color or 0x57F287,
                    fields = fields,
                    timestamp = DateTime.now():ToIsoDate()
                }
            }
        }
    )
end

-- ===== FIND MY PLOT =====
local currentPlot
local function Findplot()
    for _, plot in ipairs(Plots:GetChildren()) do
        local sign = plot:FindFirstChild("PlayerSign")
        local bb = sign and sign:FindFirstChild("BillboardGui")
        local tl = bb and bb:FindFirstChild("TextLabel")
        if tl and tl.Text == plr.Name then
            currentPlot = plot
            return plot
        end
    end
end
while not Findplot() do
    task.wait(0.25)
end

-- ===== TILES / PLANTS =====
local function getGrassTiles(plot)
    local tiles, rows = {}, plot and plot:FindFirstChild("Rows")
    if not rows then
        return tiles
    end
    for _, row in ipairs(rows:GetChildren()) do
        local g = row:FindFirstChild("Grass")
        if g then
            for _, inst in ipairs(g:GetChildren()) do
                if inst:IsA("BasePart") then
                    local CanPlace = inst:GetAttribute("CanPlace")
                    if CanPlace then
                        table.insert(tiles, inst)
                    end
                end
            end
        end
    end
    return tiles
end

local function randomPointOnTile(tile, margin)
    margin = margin or 0.15
    local hx, hz = tile.Size.X * (0.5 - margin), tile.Size.Z * (0.5 - margin)
    local ox = (math.random() * 2 - 1) * hx
    local oz = (math.random() * 2 - 1) * hz
    return (tile.CFrame * CFrame.new(ox, tile.Size.Y / 2, oz)).Position
end

local function getExistingPlants(plot)
    local folder, res = plot:FindFirstChild("Plants"), {}
    if not folder then
        return res
    end
    for _, p in ipairs(folder:GetChildren()) do
        if p:GetAttribute("Owner") == plr.Name then
            local pos = p:GetAttribute("Position")
            local sz = p:GetAttribute("Size")
            if typeof(pos) == "Vector3" then
                table.insert(res, {position = pos, size = sz})
            end
        end
    end
    return res
end

local function isSpotFree(point, plants, minGap)
    minGap = minGap or 0.6
    for _, pl in ipairs(plants) do
        local need = math.max(minGap, (pl.size or 1) * 0.5)
        if (point - pl.position).Magnitude <= need then
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
    return nil
end

local function isTileEmpty(tile)
    local occ = tile:GetAttribute("Occupied")
    if occ ~= nil then
        return not occ
    end
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
    return (#list > 0) and list[math.random(1, #list)] or nil
end

-- ===== TOOLS / SEEDS =====
local function EquipTool(toolItemName)
    local char = plr.Character or plr.CharacterAdded:Wait()
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") and tool:GetAttribute("ItemName") == toolItemName then
            return tool
        end
    end
    local bag = plr:FindFirstChild("Backpack")
    if bag then
        for _, tool in ipairs(bag:GetChildren()) do
            if tool:IsA("Tool") and tool:GetAttribute("ItemName") == toolItemName then
                tool.Parent = char
                for _ = 1, 15 do
                    if char:FindFirstChild(tool.Name) then
                        break
                    end
                    task.wait(0.05)
                end
                return tool
            end
        end
    end
    return nil
end

local function findLatestSeedId(seedName)
    local containers = {plr.Character, plr.Backpack}
    for _, bag in ipairs(containers) do
        if bag then
            for _, tool in ipairs(bag:GetChildren()) do
                if tool:IsA("Tool") and tool:GetAttribute("ItemName") == seedName then
                    local id = tool:GetAttribute("ID")
                    if id then
                        return id
                    end
                end
            end
        end
    end
    return nil
end

-- ซื้อเมล็ดผ่าน Remote โดยตรง + webhook
local function BuySeed(seedName)
    if not seedName or seedName == "" then
        return false
    end
    local ok, err =
        pcall(
        function()
            RS.Remotes.BuyItem:FireServer(seedName)
        end
    )
    if ok then
        sendEmbed("🛒 ซื้อเมล็ด", ("ซื้อ **%s** สำเร็จ"):format(seedName), 0x5865F2)
    else
        sendEmbed("🛒 ซื้อเมล็ดล้มเหลว", ("**%s**\n```%s```"):format(seedName, tostring(err)), 0xED4245)
    end
    return ok
end

-- ปลูก 1 ต้น (สุ่มจุดบน tile) + webhook
local function plant(tile, seedName)
    if not tile then
        return
    end
    local id = findLatestSeedId(seedName)
    if not id then
        sendEmbed("🌱 ปลูกล้มเหลว", "หา **ID** ของ seed ไม่เจอ: `" .. tostring(seedName) .. "`", 0xED4245)
        return
    end
    if not EquipTool(seedName) then
        sendEmbed("🌱 ปลูกล้มเหลว", "ไม่มี/ถือ **Tool** ไม่ได้: `" .. tostring(seedName) .. "`", 0xED4245)
        return
    end

    local planted = getExistingPlants(currentPlot)
    local spot = pickRandomFreePoint(tile, planted, 12, 0.15, 0.6)
    if not spot then
        sendEmbed("🌱 ปลูกล้มเหลว", "ไม่พบตำแหน่งว่างบน tile", 0xED4245)
        return
    end

    local item = seedName:match("^(%S+)") -- "Cactus Seed" -> "Cactus"
    local ok, err =
        pcall(
        function()
            RS.Remotes.PlaceItem:FireServer(
                {
                    ID = id,
                    CFrame = CFrame.new(spot),
                    Item = item,
                    Floor = tile
                }
            )
        end
    )

    if ok then
        sendEmbed(
            "🌱 ปลูกสำเร็จ",
            ("ปลูก **%s** บน `%s`\nตำแหน่ง `(%.1f, %.1f, %.1f)`"):format(
                item,
                tile:GetFullName(),
                spot.X,
                spot.Y,
                spot.Z
            ),
            0x57F287,
            {{name = "SeedID", value = "`" .. tostring(id) .. "`", inline = true}}
        )
    else
        sendEmbed("🌱 ปลูกล้มเหลว", "PlaceItem error:\n```" .. tostring(err) .. "```", 0xED4245)
    end
end

-- รายชื่อเมล็ดที่ถืออยู่จริง (ดู Attribute Seed/Uses)
local function getOwnedSeeds()
    local res, containers = {}, {plr.Backpack, plr.Character}
    for _, bag in ipairs(containers) do
        if bag then
            for _, tool in ipairs(bag:GetChildren()) do
                if tool:IsA("Tool") and tool:GetAttribute("Seed") then
                    local name = tool:GetAttribute("ItemName") or tool.Name
                    local uses = tonumber(tool:GetAttribute("Uses")) or 1
                    table.insert(res, {Name = name, Uses = uses})
                end
            end
        end
    end
    return res
end

local function plantOwnedSeeds()
    local free, used, cap = getFreePlantSlots()
    if free <= 0 then
        sendEmbed(
            "🌱 ถึงลิมิตปลูก",
            ("ปลูกแล้ว %d/%d — รอสั่งซื้อ Row ใหม่ก่อนค่อยปลูกต่อ"):format(used, cap),
            0xFAA61A
        )
        return
    end

    local seeds = getOwnedSeeds()
    if #seeds == 0 then
        return
    end

    for _, s in ipairs(seeds) do
        if free <= 0 then
            break
        end
        if EquipTool(s.Name) then
            local char = plr.Character or plr.CharacterAdded:Wait()
            for _ = 1, 15 do
                if char:FindFirstChild(s.Name) then
                    break
                end
                task.wait(0.05)
            end

            -- ปลูกได้เท่าที่มีช่องว่าง
            local usesToPlant = math.min(s.Uses or 1, free)
            for i = 1, usesToPlant do
                local tiles = getGrassTiles(currentPlot)
                if #tiles == 0 then
                    return
                end
                local t = pickEmptyThenAny(tiles)
                if t and t:GetAttribute("CanPlace") then
                    plant(t, s.Name)
                    free = free - 1
                    if free <= 0 then
                        break
                    end
                    task.wait(PLANT_DELAY + 0.1)
                end
            end
        end
    end
end

-- ===== SHOP (GUI) =====
-- แปลงข้อความราคา -> number (รองรับ $, คอมมา, ช่องว่าง, ทศนิยม และ k/m/b/t)
local function parsePrice(txt)
    txt = tostring(txt or "")
    txt = txt:lower():gsub("%$", ""):gsub(",", ""):gsub("%s+", "")
    local mult = 1
    if txt:find("k") then
        mult = 1e3
        txt = txt:gsub("k", "")
    elseif txt:find("m") then
        mult = 1e6
        txt = txt:gsub("m", "")
    elseif txt:find("b") then
        mult = 1e9
        txt = txt:gsub("b", "")
    elseif txt:find("t") then
        mult = 1e12
        txt = txt:gsub("t", "")
    end
    local n = tonumber(txt) or 0
    return math.floor(n * mult + 0.5)
end

local function readSeedShop()
    local main = plr.PlayerGui:FindFirstChild("Main")
    if not main then
        return {}
    end
    local seedsRoot = main:FindFirstChild("Seeds")
    if not seedsRoot then
        return {}
    end
    local sf = seedsRoot:FindFirstChild("Frame") and seedsRoot.Frame:FindFirstChild("ScrollingFrame")
    if not sf then
        return {}
    end
    local items = {}
    for _, seedFrame in ipairs(sf:GetChildren()) do
        if seedFrame:IsA("Frame") then
            local name = seedFrame.Name
            local buy = seedFrame:FindFirstChild("Buttons") and seedFrame.Buttons:FindFirstChild("Buy")
            local priceLabel = buy and buy:FindFirstChild("TextLabel")
            if priceLabel and typeof(priceLabel.Text) == "string" then
                table.insert(items, {SeedName = name, Price = parsePrice(priceLabel.Text)})
            end
        end
    end
    table.sort(
        items,
        function(a, b)
            return a.Price > b.Price
        end
    ) -- แพง→ถูก
    return items
end

local function pickBestAffordableSeed(money, items)
    for _, it in ipairs(items) do
        if money >= it.Price then
            return it
        end
    end
    return nil
end

-- ===== BRAINROT =====
local function EquipBestBrainrot()
    pcall(
        function()
            RS.Remotes.EquipBestBrainrots:FireServer()
        end
    )
end

-- ===== PLATFORMS (No-Walk) – ข้ามช่องที่มี Attribute `Rebirth` =====
local function isPlatformOwned(slot)
    local priceVal = slot:FindFirstChild("PlatformPrice")
    local price = priceVal and tonumber(priceVal.Value) or 0
    local rebirthAttr = slot:GetAttribute("Rebirth")
    if rebirthAttr and tonumber(rebirthAttr) and tonumber(rebirthAttr) > 0 then
        return false, "rebirth"
    end
    return (not priceVal) or (price <= 0), nil
end

-- ใช้ parsePrice(txt) เดิมของคุณได้เลย (แปลง "$5,000" → 5000)

local function getPlatformPrice(slot)
    local priceObj = slot:FindFirstChild("PlatformPrice")
    if not priceObj then
        return 0
    end

    -- กรณีเป็น NumberValue/IntValue
    if priceObj:IsA("NumberValue") or priceObj:IsA("IntValue") then
        return tonumber(priceObj.Value) or 0
    end

    -- กรณีเป็นโฟลเดอร์ UI ที่มี TextLabel: Money
    local moneyLabel = nil
    for _, d in ipairs(priceObj:GetDescendants()) do
        if d:IsA("TextLabel") and d.Name == "Money" then
            moneyLabel = d
            break
        end
    end
    if moneyLabel and typeof(moneyLabel.Text) == "string" then
        return parsePrice(moneyLabel.Text) -- "$5,000" -> 5000
    end

    return 0
end

local function findNextPlatformToBuy_NoRebirth()
    local plants = currentPlot and currentPlot:FindFirstChild("Plants")
    if not plants then
        return nil
    end

    for i = 2, MAX_PLATFORM_IDX do
        local slot = plants:FindFirstChild(tostring(i))
        if not slot then
            break
        end

        -- ข้ามช่องที่มีเงื่อนไข Rebirth
        local reb = slot:GetAttribute("Rebirth")
        if reb and tonumber(reb) and tonumber(reb) > 0 then
            -- skip
        else
            local price = getPlatformPrice(slot)
            -- ถ้ายังมีราคา > 0 แปลว่ายังไม่ได้ซื้อ
            if price and price > 0 then
                return i, price
            end
        end
    end
    return nil
end

local function tryBuyNextPlatform_NoWalk()
    local idx, price = findNextPlatformToBuy_NoRebirth()
    if not idx then
        return false
    end
    local money = (plr.leaderstats and plr.leaderstats.Money and plr.leaderstats.Money.Value) or 0
    if money < price then
        sendEmbed("🧱 ซื้อแพลตฟอร์ม", ("ยังซื้อ **#%d** ไม่ได้ (ต้องการ $%s)"):format(idx, tostring(price)), 0xFAA61A)
        return false
    end
    EquipBestBrainrot() -- บางเกมเช็ก state
    local ok, err =
        pcall(
        function()
            RS.Remotes.BuyPlatform:FireServer(tostring(idx))
        end
    )
    if ok then
        sendEmbed("🧱 ซื้อแพลตฟอร์มสำเร็จ", ("ซื้อช่อง **#%d** ราคา **$%s**"):format(idx, tostring(price)), 0x57F287)
    else
        sendEmbed("🧱 ซื้อแพลตฟอร์มล้มเหลว", "```" .. tostring(err) .. "```", 0xED4245)
    end
    return ok
end

-- ===== COLLECT MONEY: เดินเหยียบ Center ของทุกแพลตฟอร์มที่เป็นของเราแล้ว =====
local function collectMoneyOnAllCenters(options)
    options = options or {}
    local dwell = options.dwell or 0.35
    local doJump = (options.jump == nil) and true or options.jump
    local maxIdx = options.maxIdx or MAX_PLATFORM_IDX

    local plants = currentPlot and currentPlot:FindFirstChild("Plants")
    if not plants then
        return
    end
    local character = plr.Character or plr.CharacterAdded:Wait()
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return
    end

    local moneyBefore = (plr.leaderstats and plr.leaderstats.Money and plr.leaderstats.Money.Value) or 0
    local visited, skippedRebirth = 0, 0

    for i = 1, maxIdx do
        local slot = plants:FindFirstChild(tostring(i))
        if not slot then
            break
        end
        local owned, reason = isPlatformOwned(slot)
        if owned then
            local center = slot:FindFirstChild("Center")
            if center and center:IsA("BasePart") then
                humanoid:MoveTo(center.Position)
                humanoid.MoveToFinished:Wait()
                if doJump then
                    VIM:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                    task.wait(0.05)
                    VIM:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
                end
                visited = visited + 1
                task.wait(dwell)
            end
        elseif reason == "rebirth" then
            skippedRebirth = skippedRebirth + 1
        end
    end

    local moneyAfter = (plr.leaderstats and plr.leaderstats.Money and plr.leaderstats.Money.Value) or moneyBefore
    local gain = moneyAfter - moneyBefore
    sendEmbed(
        "💰 เก็บเงินจาก Brainrot",
        ("เดินเก็บครบ **%d จุด**, ข้าม Rebirth **%d**\nได้เงินเพิ่ม **$%s** (รวมปัจจุบัน $%s)"):format(
            visited,
            skippedRebirth,
            tostring(gain),
            tostring(moneyAfter)
        ),
        0xFEE75C
    )
end

-- อ่านราคา + stock จาก UI ร้าน (กันร้านปิด/ยังไม่โหลด)
local function getAvailableSeeds()
    local main = plr.PlayerGui:FindFirstChild("Main")
    local seedsUI = main and main:FindFirstChild("Seeds")
    local frame = seedsUI and seedsUI:FindFirstChild("Frame")
    local scrolling = frame and frame:FindFirstChild("ScrollingFrame")
    if not scrolling then
        return {}
    end

    local list = {}
    for _, seedFrame in ipairs(scrolling:GetChildren()) do
        if seedFrame:IsA("Frame") and seedFrame:FindFirstChild("Buttons") then
            local name = seedFrame.Name
            local buy = seedFrame.Buttons:FindFirstChild("Buy")
            local priceLabel = buy and buy:FindFirstChild("TextLabel")
            local stockLabel = seedFrame:FindFirstChild("Stock")
            if priceLabel and stockLabel then
                local price = parsePrice(priceLabel.Text)
                local stock = tonumber((stockLabel.Text or ""):match("x(%d+)")) or 0
                if stock > 0 then
                    table.insert(list, {Name = name, Price = price, Stock = stock})
                end
            end
        end
    end
    table.sort(
        list,
        function(a, b)
            return a.Price > b.Price
        end
    ) -- แพง -> ถูก
    return list
end

-- ใช้ parsePrice(txt) ของคุณอยู่แล้ว (แปลง $5,000 / $5k → number)

local function getRowPrice(rowFolder)
    -- workspace.Plots[<id>].Rows["n"].Button.Main.SurfaceGui.TextLabel
    local button = rowFolder:FindFirstChild("Button")
    local main = button and button:FindFirstChild("Main")
    local sg = main and main:FindFirstChild("SurfaceGui")
    local label = sg and sg:FindFirstChild("TextLabel")
    if label and typeof(label.Text) == "string" then
        return parsePrice(label.Text)
    end
    return 0
end

local function findNextRowToBuy()
    if not currentPlot then
        return nil
    end
    local rows = currentPlot:FindFirstChild("Rows")
    if not rows then
        return nil
    end

    -- เริ่มจาก 2 เพราะแถว 1 มักได้มาตั้งแต่แรก
    for i = 2, MAX_ROW_IDX do
        local rf = rows:FindFirstChild(tostring(i))
        if not rf then
            break
        end

        local enabled = rf:GetAttribute("Enabled")
        if enabled == true then
            -- ซื้อแล้ว ข้าม
        else
            local price = getRowPrice(rf)
            if price and price > 0 then
                return i, price, rf
            end
        end
    end
    return nil
end
local function tryBuyNextRow_NoWalk()
    local idx, price = findNextRowToBuy()
    if not idx then
        return false
    end

    local money = (plr.leaderstats and plr.leaderstats.Money and plr.leaderstats.Money.Value) or 0
    if money < price then
        sendEmbed(
            "🌿 ซื้อแถวปลูกพืช",
            ("เงินไม่พอซื้อ **Row #%d** (ต้องการ $%s)"):format(idx, tostring(price)),
            0xFAA61A
        )
        return false
    end

    local ok, err =
        pcall(
        function()
            -- ตัวอย่างจากคุณ: FireServer(2) แบบเลขล้วน
            RS.Remotes.BuyRow:FireServer(idx)
        end
    )

    if ok then
        sendEmbed(
            "🌿 ซื้อแถวปลูกพืชสำเร็จ",
            ("ซื้อ **Row #%d** ราคา **$%s** (+5 slot)"):format(idx, tostring(price)),
            0x57F287
        )
    else
        sendEmbed("🌿 ซื้อแถวล้มเหลว", "```" .. tostring(err) .. "```", 0xED4245)
    end
    return ok
end
local function getPlantCapacity()
    if not currentPlot then
        return 0
    end
    local rows = currentPlot:FindFirstChild("Rows")
    if not rows then
        return 0
    end
    local enabledCount = 0
    for _, rf in ipairs(rows:GetChildren()) do
        if rf:GetAttribute("Enabled") == true then
            enabledCount = enabledCount + 1
        end
    end
    return enabledCount * 5 -- เกมนี้แถวละ +5
end

-- นับจำนวนแถว (Row) ที่ใช้งานอยู่ แล้วคูณ 5 = ความจุปลูกสูงสุด
local function getPlantCapacity()
    if not currentPlot then
        return 0
    end
    local rows = currentPlot:FindFirstChild("Rows")
    if not rows then
        return 0
    end

    local enabled = 0
    for _, rf in ipairs(rows:GetChildren()) do
        if rf:IsA("Folder") then
            local en = rf:GetAttribute("Enabled")
            -- บางแมพ Row#1 อาจไม่มี Attribute ให้ถือว่าใช้ได้เสมอ
            if en == true or (en == nil and rf.Name == "1") then
                enabled = enabled + 1
            end
        end
    end
    return enabled * 5
end

-- นับจำนวน “ต้นไม้ของเรา” ที่ปลูกอยู่จริงใน plot ตอนนี้
local function getMyPlantCount()
    if not currentPlot then
        return 0
    end
    local folder = currentPlot:FindFirstChild("Plants")
    if not folder then
        return 0
    end

    local n = 0
    for _, p in ipairs(folder:GetChildren()) do
        -- ในรูป Owner เป็นชื่อผู้เล่น (เช่น "AJKJ9098a")
        if p:GetAttribute("Owner") == plr.Name then
            n = n + 1
        end
    end
    return n
end

local function getFreePlantSlots()
    local cap = getPlantCapacity()
    local used = getMyPlantCount()
    return math.max(0, cap - used), used, cap
end

-- ===== MAIN LOOP (ทุกอย่างรวมไว้ที่นี่) =====
local lastCollect = tick()
sendText("🔁 เริ่ม Auto PvB (No-Walk + Webhook + Collect/1min)")
local lastCap = getPlantCapacity()
while _G.Enabled do
    -- 1) ซื้อเมล็ดที่แพงสุดที่ซื้อไหว (เช็กจาก GUI โดยตรง + มีสต็อก)
    local seeds = getAvailableSeeds()
    local money = (plr.leaderstats and plr.leaderstats.Money and plr.leaderstats.Money.Value) or 0

    for _, seed in ipairs(seeds) do
        if money >= seed.Price then
            print(("🪴 ซื้อ %s ราคา $%d (เหลือ %d ชิ้น)"):format(seed.Name, seed.Price, seed.Stock))
            BuySeed(seed.Name)
            sendEmbed(
                "🪴 ซื้อเมล็ดใหม่",
                ("ซื้อ **%s** ราคา `$%d`\nเหลือในร้าน `%d` ชิ้น"):format(seed.Name, seed.Price, seed.Stock),
                0x00FF00
            )
            task.wait(0.3)
            -- รีเฟรชเงินทันที เผื่อซื้อหลายรอบในอนาคต
            money = (plr.leaderstats and plr.leaderstats.Money and plr.leaderstats.Money.Value) or money
            break -- ซื้อแค่ชนิดเดียวต่อรอบ
        end
    end

    -- 2) ปลูกตามจำนวนเมล็ดที่มีจริง (ห้ามเกินความจุ)
    local freeSlots, usedSlots, capSlots = getFreePlantSlots()
    if freeSlots > 0 then
        plantOwnedSeeds()
    else
        -- เต็มแล้ว: พยายามซื้อ Row เพิ่มแทนการปลูก
        tryBuyNextRow_NoWalk()
    end
    -- 2) ปลูกตามจำนวนเมล็ดที่มีจริง
    plantOwnedSeeds()

    -- 3) เดินเก็บเงินเฉพาะเมื่อครบเวลา (ทุก COLLECT_INTERVAL วินาที)
    if tick() - lastCollect >= COLLECT_INTERVAL then
        collectMoneyOnAllCenters({dwell = 0.35, jump = true, maxIdx = MAX_PLATFORM_IDX})
        lastCollect = tick()
    end

    -- 4) ลองซื้อแพลตฟอร์มถัดไป (ข้ามช่องที่มี Rebirth)
    tryBuyNextPlatform_NoWalk()
    tryBuyNextRow_NoWalk()
    local cap = getPlantCapacity()

    if cap > lastCap then
        sendEmbed("📈 เพิ่มความจุปลูก", ("จาก **%d** → **%d** ต้น"):format(lastCap, cap), 0x00FFFF)
        lastCap = cap
    end
    task.wait(1)
end

sendText("⏹ หยุด Auto PvB")

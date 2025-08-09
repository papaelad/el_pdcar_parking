local QBCore = exports['qb-core']:GetCoreObject()
local vehiclesFile = "pdcar_vehicles.json"
local fineLogFile = "fine_logs.json"
local vehicleLog = {}

Config = {}
Config.AllowedRanks = {
    ["chief"] = true,
    ["captain"] = true,
    ["lieutenant"] = true
}
Config.AllowedRanksToSave = {
    ["chief"] = true,
    ["captain"] = true
}


function LoadVehicles()
    local data = LoadResourceFile(GetCurrentResourceName(), vehiclesFile)
    return data and json.decode(data) or {}
end

function SaveVehicles(vehicles)
    SaveResourceFile(GetCurrentResourceName(), vehiclesFile, json.encode(vehicles, { indent = true }), -1)
end

function LoadFines()
    local data = LoadResourceFile(GetCurrentResourceName(), fineLogFile)
    return data and json.decode(data) or {}
end

function SaveFineLog(entry)
    local logs = LoadFines()
    table.insert(logs, entry)
    SaveResourceFile(GetCurrentResourceName(), fineLogFile, json.encode(logs, { indent = true }), -1)
end

function SyncVehiclesToAll(vehicles)
    for _, player in pairs(QBCore.Functions.GetPlayers()) do
        TriggerClientEvent("pdcar:client:LoadVehicles", player, vehicles)
    end
end


-- טעינה אוטומטית לכל השוטרים
AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() then
        local vehicles = LoadVehicles()
        for _, player in pairs(QBCore.Functions.GetPlayers()) do
            local Player = QBCore.Functions.GetPlayer(player)
            if Player and Player.PlayerData.job.name == "police" then
                TriggerClientEvent("pdcar:client:LoadVehicles", player, vehicles)
            end
        end
        print("[pdcar] רכבים נטענו בהצלחה.")
    end
end)

-- שמירת רכב חדש
RegisterServerEvent("pdcar:server:SaveVehicle")
AddEventHandler("pdcar:server:SaveVehicle", function(division, model, coords, heading)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or Player.PlayerData.job.name ~= "police" then return end

    local rank = Player.PlayerData.job.grade.name
    if not Config.AllowedRanksToSave[rank] then
        TriggerClientEvent("QBCore:Notify", src, "⛔ אין לך הרשאה לשמור רכבים.", "error")
        return
    end

    local vehicleData = {
        model = model,
        spawn = { x = coords.x, y = coords.y, z = coords.z },
        heading = heading,
        savedAt = os.time()
    }

    local vehicles = LoadVehicles()
    vehicles[division] = vehicles[division] or {}
    table.insert(vehicles[division], vehicleData)

    SaveVehicles(vehicles)
    TriggerClientEvent("QBCore:Notify", src, "✅ הרכב נשמר ליחידה: " .. division, "success")
    SyncVehiclesToAll(vehicles)
    print("[pdcar] רכב נשמר ליחידה " .. division .. " על ידי " .. Player.PlayerData.charinfo.firstname)
end)

-- מחיקת רכב
RegisterServerEvent("pdcar:server:DeleteVehicle")
AddEventHandler("pdcar:server:DeleteVehicle", function(division, index)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or Player.PlayerData.job.name ~= "police" then return end

    local rank = Player.PlayerData.job.grade.name
    if not Config.AllowedRanks[rank] then
        TriggerClientEvent("QBCore:Notify", src, "❌ אין לך הרשאה למחוק רכבים.", "error")
        return
    end

    local vehicles = LoadVehicles()
    if vehicles[division] and vehicles[division][index] then
        table.remove(vehicles[division], index)
        SaveVehicles(vehicles)
        TriggerClientEvent("QBCore:Notify", src, "✅ הרכב נמחק מהיחידה: " .. division, "success")
        SyncVehiclesToAll(vehicles)
        print("[pdcar] רכב נמחק מהיחידה " .. division)
    else
        TriggerClientEvent("QBCore:Notify", src, "❌ לא נמצא רכב למחיקה.", "error")
    end
end)

-- לוג לקיחת רכב
RegisterServerEvent("pdcar:server:LogVehicleTaken")
AddEventHandler("pdcar:server:LogVehicleTaken", function(model, plate)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local cid = Player.PlayerData.citizenid
    vehicleLog[cid] = {
        citizenid = cid,
        name = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname,
        model = model,
        plate = plate,
        takenAt = os.time(),
        returned = false
    }
end)

-- לוג החזרת רכב
RegisterServerEvent("pdcar:server:LogVehicleReturned")
AddEventHandler("pdcar:server:LogVehicleReturned", function(plate)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local cid = Player.PlayerData.citizenid
    if vehicleLog[cid] and vehicleLog[cid].plate == plate then
        vehicleLog[cid].returned = true
        vehicleLog[cid].returnedAt = os.time()
    end
end)

-- תשלום קנס
RegisterNetEvent("pdcar:server:PayFine")
AddEventHandler("pdcar:server:PayFine", function(amount, method)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local paid = false
    if method == "cash" and Player.PlayerData.money.cash >= amount then
        Player.Functions.RemoveMoney("cash", amount)
        paid = true
    elseif method == "bank" and Player.PlayerData.money.bank >= amount then
        Player.Functions.RemoveMoney("bank", amount)
        paid = true
    elseif method == "credit" and Player.PlayerData.money.card and Player.PlayerData.money.card >= amount then
        Player.Functions.RemoveMoney("card", amount)
        paid = true
    end

    if paid then
        TriggerClientEvent("QBCore:Notify", src, "💸 שילמת קנס של $" .. amount .. " באמצעות " .. method, "success")
        TriggerClientEvent("pdcar:client:FinePaid", src)

        local logEntry = {
            name = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname,
            citizenid = Player.PlayerData.citizenid,
            amount = amount,
            method = method,
            timestamp = os.time()
        }

        SaveFineLog(logEntry)
        print("[pdcar] קנס שולם: $" .. amount .. " על ידי " .. logEntry.name)
    else
        TriggerClientEvent("QBCore:Notify", src, "❌ אין מספיק כסף ב־" .. method, "error")
    end
end)

-- תפריט ניהולי להצגת רכבים שנלקחו
QBCore.Commands.Add("pdmenu", "תפריט ניהולי לרכבים", {}, false, function(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player or Player.PlayerData.job.name ~= "police" then return end

    local logList = {}
    for _, data in pairs(vehicleLog) do
        table.insert(logList, data)
    end

    TriggerClientEvent("pdcar:client:OpenVehicleLogMenu", source, logList)
end)

-- פקודת סטטיסטיקות
QBCore.Commands.Add("pdstats", "סטטיסטיקות רכבים וקנסות", {}, false, function(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player or Player.PlayerData.job.name ~= "police" then return end

    local totalTaken = 0
    local totalReturned = 0
    for _, v in pairs(vehicleLog) do
        totalTaken = totalTaken + 1
        if v.returned then totalReturned = totalReturned + 1 end
    end

    local fines = LoadFines()
    local totalFines = #fines
    local totalAmount = 0
    for _, fine in pairs(fines) do
        totalAmount = totalAmount + (fine.amount or 0)
    end

    local msg = string.format("📊 סטטיסטיקות:\n🚓 רכבים שנלקחו: %d\n✅ רכבים שהוחזרו: %d\n💸 קנסות שולמו: %d\n💰 סכום כולל: $%d",
        totalTaken, totalReturned, totalFines, totalAmount)

    TriggerClientEvent("QBCore:Notify", source, msg, "primary", 10000)
end)

-- פקודת ניקוי רכבים ישנים (עם פרמטר ימים)
QBCore.Commands.Add("pdclean", "ניקוי רכבים שלא נגעו בהם X ימים", {
    { name = "days", help = "מספר ימים לניקוי (ברירת מחדל: 7)" }
}, false, function(source, args)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player or Player.PlayerData.job.name ~= "police" then return end

    local daysThreshold = tonumber(args[1]) or 7
    local cutoff = os.time() - (daysThreshold * 86400)

    local vehicles = LoadVehicles()
    local cleaned = 0

    for division, list in pairs(vehicles) do
        local newList = {}
        for _, vehicle in ipairs(list) do
            if vehicle.savedAt and vehicle.savedAt >= cutoff then
                table.insert(newList, vehicle)
            else
                cleaned = cleaned + 1
            end
        end
        vehicles[division] = newList
    end

    SaveVehicles(vehicles)
    SyncVehiclesToAll(vehicles)

    TriggerClientEvent("QBCore:Notify", source,
        "🧹 נמחקו " .. cleaned .. " רכבים ישנים (יותר מ־" .. daysThreshold .. " ימים).", "success")

    print("[pdcar] ניקוי רכבים ישנים בוצע. סך הכל נמחקו: " .. cleaned)
end)

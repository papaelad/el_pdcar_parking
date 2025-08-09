local QBCore = exports['qb-core']:GetCoreObject()
local assignedVehicle = nil
local returnBlip = nil
local gpsBlip = nil
local currentVehicles = {}
local garageZone = nil
local finePed = nil

-- יצירת אזור חנייה עם PolyZone
CreateThread(function()
    garageZone = BoxZone:Create(vector3(385.97, -1627.57, 29.37), 10.0, 10.0, {
        name = "pd_garage",
        heading = 0,
        minZ = 27.0,
        maxZ = 32.0
    })
end)

local function IsInGarageZone()
    return garageZone and garageZone:isPointInside(GetEntityCoords(PlayerPedId()))
end

local function IsSpawnClear(coords)
    local veh = GetClosestVehicle(coords.x, coords.y, coords.z, 3.0, 0, 70)
    return veh == 0
end

-- טעינת רכבים
RegisterNetEvent("pdcar:client:LoadVehicles", function(vehicles)
    local playerData = QBCore.Functions.GetPlayerData()
    if playerData.job.name ~= 'police' then return end

    currentVehicles = vehicles
    for division, cars in pairs(vehicles) do
        for _, config in ipairs(cars) do
            local hash = config.model
            RequestModel(hash)
            while not HasModelLoaded(hash) do Wait(10) end

            if not IsSpawnClear(config.spawn) then goto continue end

            local vehicle = CreateVehicle(hash, config.spawn.x, config.spawn.y, config.spawn.z, config.heading, false, false)
            SetEntityAsMissionEntity(vehicle, true, true)
            SetVehicleDoorsLocked(vehicle, 2)
            SetVehicleUndriveable(vehicle, true)
            FreezeEntityPosition(vehicle, true)

            exports['qb-target']:AddTargetEntity(vehicle, {
                options = {
                    {
                        label = "🚓 קח רכב משטרתי",
                        icon = "fas fa-car",
                        action = function()
                            if not IsInGarageZone() then
                                QBCore.Functions.Notify('❌ אתה לא באזור החנייה.', 'error')
                                return
                            end
                            if assignedVehicle then
                                QBCore.Functions.Notify('❌ תחזיר קודם את הרכב הנוכחי.', 'error')
                                return
                            end

                            FreezeEntityPosition(vehicle, false)
                            SetVehicleUndriveable(vehicle, false)
                            SetVehicleDoorsLocked(vehicle, 1)
                            SetVehicleEngineOn(vehicle, true, true, true)

                            local plate = GetVehicleNumberPlateText(vehicle)
                            TriggerEvent('vehiclekeys:client:SetOwner', plate)
                            TriggerServerEvent("pdcar:server:LogVehicleTaken", config.model, plate)

                            assignedVehicle = {
                                entity = vehicle,
                                spawn = config.spawn,
                                heading = config.heading,
                                model = config.model,
                                takenAt = os.time()
                            }

                            QBCore.Functions.Notify('🚓 הרכב נפתח. החזר אותו לנקודה המסומנת.', 'success', 5000)

                            if returnBlip then RemoveBlip(returnBlip) end
                            returnBlip = AddBlipForCoord(config.spawn.x, config.spawn.y, config.spawn.z)
                            SetBlipSprite(returnBlip, 1)
                            SetBlipColour(returnBlip, 3)
                            SetBlipScale(returnBlip, 0.7)
                            BeginTextCommandSetBlipName("STRING")
                            AddTextComponentString("נקודת החזרה")
                            EndTextCommandSetBlipName(returnBlip)

                            if gpsBlip then RemoveBlip(gpsBlip) end
                            gpsBlip = AddBlipForEntity(vehicle)
                            SetBlipSprite(gpsBlip, 225)
                            SetBlipColour(gpsBlip, 38)
                            SetBlipScale(gpsBlip, 0.8)
                            BeginTextCommandSetBlipName("STRING")
                            AddTextComponentString("רכב משטרתי שלך")
                            EndTextCommandSetBlipName(gpsBlip)
                        end
                    }
                },
                distance = 2.5
            })

            ::continue::
        end
    end
end)

-- פקודות GPS ותחזוקה
RegisterCommand("trackpdcar", function()
    if assignedVehicle and DoesEntityExist(assignedVehicle.entity) then
        local coords = GetEntityCoords(assignedVehicle.entity)
        SetNewWaypoint(coords.x, coords.y)
        QBCore.Functions.Notify("📍 מיקום הרכב סומן על המפה.", "primary")
    else
        QBCore.Functions.Notify("❌ אין רכב פעיל או שהוא נעלם.", "error")
    end
end, false)

RegisterCommand("checkpdcar", function()
    if not assignedVehicle or not DoesEntityExist(assignedVehicle.entity) then
        QBCore.Functions.Notify("❌ אין רכב פעיל לבדיקה.", "error")
        return
    end

    local veh = assignedVehicle.entity
    local health = GetVehicleEngineHealth(veh)

    if health < 300 then
        exports['qb-menu']:openMenu({
            {
                header = "🧰 תחזוקת רכב",
                txt = "הרכב פגוע. בחר פעולה:",
                isMenuHeader = true
            },
            {
                header = "🔧 תקן רכב",
                txt = "תיקון מלא ללא עלות",
                params = {
                    event = "pdcar:client:RepairVehicle"
                }
            },
            {
                header = "💸 שלם קנס על נזק",
                txt = "קנס: $2000",
                params = {
                    event = "pdcar:client:PayFineChoice",
                    args = { method = "bank", amount = 2000 }
                }
            }
        })
    else
        QBCore.Functions.Notify("✅ הרכב תקין.", "success")
    end
end, false)

RegisterNetEvent("pdcar:client:RepairVehicle", function()
    if assignedVehicle and DoesEntityExist(assignedVehicle.entity) then
        SetVehicleFixed(assignedVehicle.entity)
        QBCore.Functions.Notify("🔧 הרכב תוקן בהצלחה.", "success")
    end
end)

-- AI Dispatcher
CreateThread(function()
    while true do
        Wait(300000)
        if assignedVehicle and assignedVehicle.takenAt then
            local elapsed = os.time() - assignedVehicle.takenAt
            if elapsed > 3600 then
                QBCore.Functions.Notify("⏰ עברו יותר משעה מאז שלקחת את הרכב. אנא החזר אותו.", "warning")
            end
        end
    end
end)

-- ממשק ניהולי NUI
RegisterCommand("openpdcarui", function()
    SetNuiFocus(true, true)
    SendNUIMessage({ action = "open", data = currentVehicles })
end, false)

RegisterNUICallback("close", function()
    SetNuiFocus(false, false)
end)

RegisterNUICallback("deleteVehicle", function(data)
    TriggerServerEvent("pdcar:server:DeleteVehicle", data.division, data.index)
end)

-- פד קנס
CreateThread(function()
    RequestModel("s_m_y_cop_01")
    while not HasModelLoaded("s_m_y_cop_01") do Wait(10) end

    finePed = CreatePed(0, "s_m_y_cop_01", 385.97, -1627.57, 28.37, 312.38, false, true)
    FreezeEntityPosition(finePed, true)
    SetEntityInvincible(finePed, true)
    SetBlockingOfNonTemporaryEvents(finePed, true)

    exports['qb-target']:AddTargetEntity(finePed, {
        options = {
            {
                label = "💸 שלם קנס על רכב שאבד",
                icon = "fas fa-money-bill",
                action = function()
                    local playerData = QBCore.Functions.GetPlayerData()
                    if playerData.job.name ~= 'police' then
                        QBCore.Functions.Notify('❌ רק לשוטרים מותר לגשת לפד.', 'error')
                        return
                    end

                    if not assignedVehicle then
                        QBCore.Functions.Notify('✅ אין לך רכב פעיל. אין צורך לשלם קנס.', 'success')
                        return
                    end

                    local veh = assignedVehicle.entity
                    if DoesEntityExist(veh) then
                        QBCore.Functions.Notify('❌ הרכב שלך עדיין קיים. תחזיר אותו קודם.', 'error')
                        return
                    end

                    exports['qb-menu']:openMenu({
                        {
                            header = "בחר אמצעי תשלום",
                            icon = "fas fa-credit-card",
                            txt = "קנס: $5000",
                            isMenuHeader = true
                        },
                        {
                            header = "💵 מזומן",
                            txt = "שלם מהכיס",
                            icon = "fas fa-money-bill",
                            params = {
                                event = "pdcar:client:PayFineChoice",
                                args = { method = "cash", amount = 5000 }                            }
                        },
                        {
                            header = "🏦 בנק",
                            txt = "שלם מחשבון הבנק",
                            icon = "fas fa-university",
                            params = {
                                event = "pdcar:client:PayFineChoice",
                                args = { method = "bank", amount = 5000 }
                            }
                        },
                        {
                            header = "💳 אשראי",
                            txt = "שלם בכרטיס",
                            icon = "fas fa-credit-card",
                            params = {
                                event = "pdcar:client:PayFineChoice",
                                args = { method = "credit", amount = 5000 }
                            }
                        }
                    })
                end
            }
        },
        distance = 2.5
    })
end)

RegisterNetEvent("pdcar:client:PayFineChoice", function(data)
    TriggerServerEvent("pdcar:server:PayFine", data.amount, data.method)
end)

RegisterNetEvent("pdcar:client:FinePaid", function()
    assignedVehicle = nil
    if gpsBlip then RemoveBlip(gpsBlip) gpsBlip = nil end
    if returnBlip then RemoveBlip(returnBlip) returnBlip = nil end
    QBCore.Functions.Notify("✅ הקנס שולם. תוכל לקחת רכב חדש.", "success")
end)

-- תפריט שמירת רכב לפי יחידה
RegisterNetEvent("pdcar:client:OpenSaveMenu", function()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local heading = GetEntityHeading(playerPed)
    local vehicle = GetVehiclePedIsIn(playerPed, false)

    if vehicle == 0 then
        QBCore.Functions.Notify("❌ אתה לא בתוך רכב.", "error")
        return
    end

    local model = GetEntityModel(vehicle)
    local displayName = GetDisplayNameFromVehicleModel(model)
    local label = GetLabelText(displayName)

    local divisions = {
        "ATAN Unit",
        "YASAM Unit",
        "YAMAR Unit",
        "Sior Unit",
        "Pikdo Unit"
    }

    local menu = {
        {
            header = "בחר יחידה לשמירת הרכב",
            txt = "רכב: " .. label,
            icon = "fas fa-car",
            isMenuHeader = true
        }
    }

    for _, division in ipairs(divisions) do
        table.insert(menu, {
            header = "📁 " .. division,
            txt = "שמור את '" .. label .. "' ליחידה זו",
            params = {
                event = "pdcar:client:ConfirmSaveVehicle",
                args = {
                    division = division,
                    model = model,
                    coords = coords,
                    heading = heading
                }
            }
        })
    end

    exports['qb-menu']:openMenu(menu)
end)

RegisterNetEvent("pdcar:client:ConfirmSaveVehicle", function(data)
    TriggerServerEvent("pdcar:server:SaveVehicle", data.division, data.model, data.coords, data.heading)
end)

RegisterCommand("savepdcar", function()
    local PlayerData = QBCore.Functions.GetPlayerData()
    if PlayerData.job.name == "police" then
        TriggerEvent("pdcar:client:OpenSaveMenu")
    else
        QBCore.Functions.Notify("⛔ הפקודה זמינה רק לשוטרים.", "error")
    end
end, false)

-- תפריט ניהולי להצגת רכבים שנלקחו
RegisterNetEvent("pdcar:client:OpenVehicleLogMenu", function(log)
    local menu = {}
    table.insert(menu, {
        header = "📋 לוג רכבים שנלקחו",
        isMenuHeader = true
    })

    for _, data in pairs(log) do
        local status = data.returned and "✅ הוחזר" or "🚓 בשימוש"
        local timeTaken = os.date("%d/%m/%Y %H:%M:%S", data.takenAt or 0)
        local label = string.format("%s | %s | %s | %s", data.name, data.model, data.plate, status)

        table.insert(menu, {
            header = label,
            txt = "נלקח בתאריך: " .. timeTaken,
            icon = "fas fa-car",
            disabled = true
        })
    end

    if #menu == 1 then
        table.insert(menu, {
            header = "אין רכבים פעילים",
            txt = "לא נלקחו רכבים כרגע",
            icon = "fas fa-ban",
            disabled = true
        })
    end

    exports['qb-menu']:openMenu(menu)
end)

-- 🧪 פקודת בדיקה לטעינת רכבים (למפתחים)
RegisterCommand("pdcar_test", function()
    print("רכבים טעונים:")
    for division, list in pairs(currentVehicles) do
        print("יחידה:", division)
        for i, v in ipairs(list) do
            print("  #" .. i, v.model, "ב־", v.spawn.x, v.spawn.y, v.spawn.z)
        end
    end
end, false)

RegisterCommand("pdcar_ui", function()
    SendNUIMessage({
        action = "openVehicleManager",
        vehicles = currentVehicles
    })
    SetNuiFocus(true, true)
end, false)

RegisterNUICallback("closeUI", function(_, cb)
    SetNuiFocus(false, false)
    cb("ok")
end)

RegisterKeyMapping("pdcar_ui", "פתח תפריט ניהול רכבים", "keyboard", "F10")

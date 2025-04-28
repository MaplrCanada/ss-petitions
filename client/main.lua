local QBCore = exports['qb-core']:GetCoreObject()
local isPetitionOpen = false
local PlayerData = {}

-- Initialize player data
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload')
AddEventHandler('QBCore:Client:OnPlayerUnload', function()
    PlayerData = {}
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate')
AddEventHandler('QBCore:Client:OnJobUpdate', function(JobInfo)
    PlayerData.job = JobInfo
end)

-- Notification handler
function ShowNotification(message)
    if Config.NotificationSystem == 'qb' then
        QBCore.Functions.Notify(message, "primary")
    elseif Config.NotificationSystem == 'okok' then
        exports['okokNotify']:Alert("Petition System", message, 5000, 'info')
    else
        -- Default notification
        SetNotificationTextEntry('STRING')
        AddTextComponentString(message)
        DrawNotification(0, 1)
    end
end

-- Create command if enabled
if Config.UseCommand then
    RegisterCommand(Config.CommandName, function()
        TriggerEvent('ss-petition:client:openMenu')
    end)
end

-- Open petition menu
RegisterNetEvent('ss-petition:client:openMenu')
AddEventHandler('ss-petition:client:openMenu', function()
    if isPetitionOpen then return end
    isPetitionOpen = true
    
    -- Get petition data before opening UI
    QBCore.Functions.TriggerCallback('ss-petition:server:getPetitionData', function(data) 
        -- Send data to NUI
        SendNUIMessage({
            action = "openPetition",
            petitions = data.petitions,
            isAdmin = data.isAdmin,
            playerInfo = {
                citizenid = PlayerData.citizenid,
                name = PlayerData.charinfo.firstname .. ' ' .. PlayerData.charinfo.lastname
            },
            config = {
                theme = Config.UI.theme,
                maxLength = Config.PetitionSettings.maxPetitionLength,
                requiredSignatures = Config.PetitionSettings.requiredSignatures
            }
        })
        
        -- Show cursor and set NUI focus
        SetNuiFocus(true, true)
    end)
end)

-- Location-based interaction
CreateThread(function()
    if not Config.UseCommand then
        while true do
            Wait(0)
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local isInRange = false
            
            for _, location in pairs(Config.Locations) do
                local distance = #(playerCoords - location.coords)
                
                if distance < location.radius then
                    isInRange = true
                    
                    -- Show interaction help text
                    DrawText3D(location.coords.x, location.coords.y, location.coords.z, "[E] Open Petition Board")
                    
                    if IsControlJustReleased(0, 38) then -- E key
                        TriggerEvent('ss-petition:client:openMenu')
                    end
                end
                
                -- Draw marker if enabled
                if location.marker.enabled and distance < 10.0 then
                    DrawMarker(
                        location.marker.type, 
                        location.coords.x, location.coords.y, location.coords.z - 0.95, 
                        0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 
                        location.marker.size.x, location.marker.size.y, location.marker.size.z, 
                        location.marker.color.r, location.marker.color.g, location.marker.color.b, location.marker.color.a, 
                        false, true, 2, nil, nil, false
                    )
                end
            end
            
            if not isInRange then
                Wait(500)
            end
        end
    end
end)

-- Create blips if enabled
CreateThread(function()
    if not Config.UseCommand then
        for _, location in pairs(Config.Locations) do
            if location.blip.enabled then
                local blip = AddBlipForCoord(location.coords.x, location.coords.y, location.coords.z)
                SetBlipSprite(blip, location.blip.sprite)
                SetBlipDisplay(blip, 4)
                SetBlipScale(blip, location.blip.scale)
                SetBlipColour(blip, location.blip.color)
                SetBlipAsShortRange(blip, true)
                BeginTextCommandSetBlipName("STRING")
                AddTextComponentString(location.blip.label)
                EndTextCommandSetBlipName(blip)
            end
        end
    end
end)

-- NUI callbacks
RegisterNUICallback('closePetition', function(_, cb)
    SetNuiFocus(false, false)
    isPetitionOpen = false
    cb('ok')
end)

RegisterNUICallback('createPetition', function(data, cb)
    TriggerServerEvent('ss-petition:server:createPetition', data)
    cb('ok')
end)

RegisterNUICallback('signPetition', function(data, cb)
    TriggerServerEvent('ss-petition:server:signPetition', data)
    cb('ok')
end)

RegisterNUICallback('adminAction', function(data, cb)
    TriggerServerEvent('ss-petition:server:adminAction', data)
    cb('ok')
end)

RegisterNUICallback('refreshPetitions', function(_, cb)
    QBCore.Functions.TriggerCallback('ss-petition:server:getPetitionData', function(data) 
        cb(data)
    end)
end)

-- Helper function for 3D text
function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    local px, py, pz = table.unpack(GetGameplayCamCoords())
    
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString(text)
    DrawText(_x, _y)
    local factor = (string.len(text)) / 370
    DrawRect(_x, _y + 0.0125, 0.015 + factor, 0.03, 41, 11, 41, 68)
end

-- Notification events
RegisterNetEvent('ss-petition:client:showNotification')
AddEventHandler('ss-petition:client:showNotification', function(message)
    ShowNotification(message)
end)
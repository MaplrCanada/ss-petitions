--client/main.lua
local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = {}
local PetitionBlips = {}
local isNearPetitionBoard = false
local isBusy = false

-- Initialize
Citizen.CreateThread(function()
    Wait(1000)
    PlayerData = QBCore.Functions.GetPlayerData()
    if not Config.UseCommand then
        CreatePetitionBlips()
    end
end)

-- Update player data when it changes
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    PlayerData.job = JobInfo
end)

-- Create blips for petition boards
function CreatePetitionBlips()
    for _, coords in pairs(Config.PetitionBoardCoords) do
        local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(blip, Config.BlipSettings.sprite)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, Config.BlipSettings.scale)
        SetBlipColour(blip, Config.BlipSettings.color)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(Config.BlipSettings.name)
        EndTextCommandSetBlipName(blip)
        table.insert(PetitionBlips, blip)
    end
end

-- Remove blips when resource stops
AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end
    for _, blip in pairs(PetitionBlips) do
        RemoveBlip(blip)
    end
end)

-- Check if player is near a petition board
Citizen.CreateThread(function()
    while true do
        if not Config.UseCommand then
            local playerPed = PlayerPedId()
            local coords = GetEntityCoords(playerPed)
            isNearPetitionBoard = false
            
            for _, boardCoords in pairs(Config.PetitionBoardCoords) do
                local distance = #(coords - vector3(boardCoords.x, boardCoords.y, boardCoords.z))
                if distance < Config.InteractionDistance then
                    isNearPetitionBoard = true
                    break
                end
            end
            
            if isNearPetitionBoard and not isBusy then
                DrawMarker(2, coords.x, coords.y, coords.z + 0.3, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.3, 0.3, 255, 255, 255, 100, false, true, 2, false, nil, nil, false)
                QBCore.Functions.DrawText3D(coords.x, coords.y, coords.z + 0.2, "[E] Open Petition Board")
                
                if IsControlJustReleased(0, 38) then -- E key
                    OpenPetitionMenu()
                end
            end
        end
        
        Wait(isNearPetitionBoard and 0 or 1000)
    end
end)

-- Command to open petition menu
if Config.UseCommand then
    RegisterCommand('petition', function()
        OpenPetitionMenu()
    end, false)
end

-- Open the petition menu
function OpenPetitionMenu()
    if isBusy then return end
    
    isBusy = true
    QBCore.Functions.TriggerCallback('ss-petitions:server:CheckIsAdmin', function(isAdmin)
        QBCore.Functions.TriggerCallback('ss-petitions:server:GetPetitions', function(petitions)
            SetNuiFocus(true, true)
            SendNUIMessage({
                action = "openMenu",
                petitions = petitions,
                playerData = {
                    citizenid = PlayerData.citizenid,
                    name = PlayerData.charinfo.firstname .. ' ' .. PlayerData.charinfo.lastname,
                    isAdmin = isAdmin
                },
                config = {
                    categories = Config.Categories,
                    maxLength = Config.MaxPetitionLength,
                    maxPlayerPetitions = Config.MaxPlayerPetitions,
                    allowAnonymous = Config.AllowAnonymousPetitions,
                    requireApproval = Config.RequireApproval
                }
            })
            isBusy = false
        end)
    end)
end

function IsPlayerAdmin()
    local isAdmin = false
    local p = promise.new()
    
    QBCore.Functions.TriggerCallback('ss-petitions:server:CheckIsAdmin', function(result)
        isAdmin = result
        p:resolve(isAdmin)
    end)
    
    return Citizen.Await(p)
end

-- NUI Callbacks
RegisterNUICallback('close', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('createPetition', function(data, cb)
    QBCore.Functions.TriggerCallback('ss-petitions:server:CreatePetition', function(success, message)
        cb({success = success, message = message})
    end, data)
end)

RegisterNUICallback('signPetition', function(data, cb)
    QBCore.Functions.TriggerCallback('ss-petitions:server:SignPetition', function(success, message)
        cb({success = success, message = message})
    end, data.id)
end)

RegisterNUICallback('deletePetition', function(data, cb)
    QBCore.Functions.TriggerCallback('ss-petitions:server:DeletePetition', function(success, message)
        cb({success = success, message = message})
    end, data.id)
end)

RegisterNUICallback('approvePetition', function(data, cb)
    QBCore.Functions.TriggerCallback('ss-petitions:server:CheckIsAdmin', function(isAdmin)
        if not isAdmin then
            cb({success = false, message = "You don't have permission to do this"})
            return
        end
        
        QBCore.Functions.TriggerCallback('ss-petitions:server:ApprovePetition', function(success, message)
            cb({success = success, message = message})
        end, data.id)
    end)
end)

RegisterNUICallback('rejectPetition', function(data, cb)
    QBCore.Functions.TriggerCallback('ss-petitions:server:CheckIsAdmin', function(isAdmin)
        if not isAdmin then
            cb({success = false, message = "You don't have permission to do this"})
            return
        end
        
        QBCore.Functions.TriggerCallback('ss-petitions:server:RejectPetition', function(success, message)
            cb({success = success, message = message})
        end, data.id)
    end)
end)

RegisterNUICallback('getPetitionDetails', function(data, cb)
    QBCore.Functions.TriggerCallback('ss-petitions:server:GetPetitionDetails', function(petition)
        cb(petition)
    end, data.id)
end)

RegisterNUICallback('getPlayerPetitions', function(data, cb)
    QBCore.Functions.TriggerCallback('ss-petitions:server:GetPlayerPetitions', function(petitions)
        cb(petitions)
    end)
end)

-- Display notifications from server
RegisterNetEvent('ss-petitions:client:Notify')
AddEventHandler('ss-petitions:client:Notify', function(message, type)
    if Config.NotificationSystem == "qbcore" then
        QBCore.Functions.Notify(message, type)
    elseif Config.NotificationSystem == "okok" then
        exports['okokNotify']:Alert("Petitions", message, 5000, type)
    else
        -- Custom notification or default
        SetNotificationTextEntry('STRING')
        AddTextComponentString(message)
        DrawNotification(false, false)
    end
end)
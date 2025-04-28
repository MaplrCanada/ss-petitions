-- server/main.lua
local QBCore = exports['qb-core']:GetCoreObject()
local Petitions = {}

-- Create a unique ID for petitions
local function CreatePetitionId()
    return tostring(os.time() .. math.random(1000, 9999))
end

QBCore.Functions.CreateCallback('ss-petitions:server:isAdmin', function(source, cb)
    cb(IsPlayerAdmin(source))
end)



-- Create a new petition
QBCore.Functions.CreateCallback('ss-petitions:server:createPetition', function(source, cb, data)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb(false) end
    
    local citizenId = Player.PlayerData.citizenid
    
    -- Check for cooldown
    for _, petition in pairs(Petitions) do
        if petition.citizenId == citizenId and (os.time() - petition.timestamp) < (Config.PetitionCooldown * 60) then
            local remainingTime = math.ceil(((Config.PetitionCooldown * 60) - (os.time() - petition.timestamp)) / 60)
            cb(false, "You need to wait " .. remainingTime .. " minutes before submitting another petition.")
            return
        end
    end
    
    -- Create petition
    local petitionId = CreatePetitionId()
    local newPetition = {
        id = petitionId,
        citizenId = citizenId,
        playerName = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname,
        title = data.title,
        description = data.description,
        category = data.category,
        timestamp = os.time(),
        status = "pending", -- pending, inprogress, resolved, rejected
        assignedAdmin = nil,
        comments = {},
    }
    
    Petitions[petitionId] = newPetition
    cb(true, "Petition submitted successfully!")
    
    -- Notify admins
    for _, player in pairs(QBCore.Functions.GetPlayers()) do
        if IsPlayerAdmin(player) then
            TriggerClientEvent('QBCore:Notify', player, "New petition submitted: " .. data.title, "primary", 5000)
        end
    end
end)

-- Get player's petitions
QBCore.Functions.CreateCallback('ss-petitions:server:getMyPetitions', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb({}) end
    
    local citizenId = Player.PlayerData.citizenid
    local myPetitions = {}
    
    for _, petition in pairs(Petitions) do
        if petition.citizenId == citizenId then
            table.insert(myPetitions, petition)
        end
    end
    
    cb(myPetitions)
end)

-- Get all petitions (admin only)
QBCore.Functions.CreateCallback('ss-petitions:server:getAllPetitions', function(source, cb)
    if not IsPlayerAdmin(source) then 
        cb({})
        return
    end
    
    local petitionsList = {}
    for _, petition in pairs(Petitions) do
        table.insert(petitionsList, petition)
    end
    
    -- Sort by timestamp (newest first)
    table.sort(petitionsList, function(a, b)
        return a.timestamp > b.timestamp
    end)
    
    cb(petitionsList)
end)

-- Update petition status (admin only)
QBCore.Functions.CreateCallback('ss-petitions:server:updatePetition', function(source, cb, petitionId, status, comment)
    if not IsPlayerAdmin(source) then
        cb(false)
        return
    end
    
    if Petitions[petitionId] then
        local adminPlayer = QBCore.Functions.GetPlayer(source)
        local adminName = adminPlayer.PlayerData.charinfo.firstname .. " " .. adminPlayer.PlayerData.charinfo.lastname
        
        Petitions[petitionId].status = status
        Petitions[petitionId].assignedAdmin = adminName
        
        if comment and comment ~= "" then
            table.insert(Petitions[petitionId].comments, {
                author = adminName,
                text = comment,
                timestamp = os.time()
            })
        end
        
        -- Notify the petition creator
        local targetPlayer = QBCore.Functions.GetPlayerByCitizenId(Petitions[petitionId].citizenId)
        if targetPlayer then
            TriggerClientEvent('QBCore:Notify', targetPlayer.PlayerData.source, "Your petition status has been updated to: " .. status, "primary", 5000)
        end
        
        cb(true, "Petition updated successfully")
    else
        cb(false, "Petition not found")
    end
end)

-- Register commands
QBCore.Commands.Add(Config.PetitionCommand, 'Submit a petition or request to admins', {}, false, function(source)
    TriggerClientEvent('ss-petitions:client:openPetitionMenu', source)
end)

QBCore.Commands.Add(Config.AdminPetitionCommand, 'View and manage petitions (Admin Only)', {}, false, function(source)
    if IsPlayerAdmin(source) then
        TriggerClientEvent('ss-petitions:client:openAdminPanel', source)
    else
        TriggerClientEvent('QBCore:Notify', source, "You don't have permission to use this command", "error")
    end
end)
-- config.lua
Config = {}

-- General Settings
Config.UseCommand = true -- If true, players can use /petition command. If false, they need to go to coordinates
Config.PetitionBoardCoords = {
    {x = -544.75, y = -204.10, z = 38.22}, -- Example: City Hall
    {x = 447.35, y = -975.57, z = 30.69},  -- Example: Police Station
    -- Add more locations as needed
}
Config.InteractionDistance = 3.0 -- Distance to interact with petition boards
Config.BlipSettings = {
    sprite = 181,
    color = 3,
    scale = 0.7,
    name = "Petition Board"
}

-- Petition Settings
Config.MaxPetitionLength = 500       -- Maximum characters in a petition
Config.MaxActivePetitions = 50       -- Maximum number of active petitions in the system
Config.MaxPlayerPetitions = 3        -- Maximum active petitions per player
Config.PetitionExpiryDays = 7        -- Number of days before petitions expire
Config.RequiredSignatures = 15       -- Signatures required for a petition to be "successful"
Config.AllowAnonymousPetitions = true -- Allow players to submit anonymous petitions
Config.RequireApproval = true        -- Require admin approval before petition is public
Config.CooldownMinutes = 30          -- Cooldown between petition submissions (minutes)

-- Admin Settings
Config.AdminGroups = {"admin", "mod", "superadmin"} -- Groups that can manage petitions

-- Categories for petitions
Config.Categories = {
    "Server Suggestions",
    "Bug Reports",
    "Event Ideas",
    "Rule Changes",
    "Other"
}

-- Notification System
Config.NotificationSystem = "qbcore" -- Options: "qbcore", "okok", "custom"

-- Framework Settings
Config.CoreObject = "QBCore" -- The name of your core object
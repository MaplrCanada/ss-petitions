-- config.lua
Config = {}

-- Command to open the petition menu for regular players
Config.PetitionCommand = 'petition'

-- Command to open the admin petition review panel
Config.AdminPetitionCommand = 'adminpetitions'

-- Minimum admin level required to view/handle petitions
Config.MinAdminLevel = 'admin' -- Options typically include: 'mod', 'admin', 'god'

-- Maximum length of petition title
Config.MaxTitleLength = 50

-- Maximum length of petition description
Config.MaxDescLength = 500

-- Cooldown between petitions (in minutes)
Config.PetitionCooldown = 10

-- Categories for petitions
Config.Categories = {
    'Bug Report',
    'Player Report',
    'Question',
    'Suggestion',
    'Other'
}
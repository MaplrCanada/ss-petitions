fx_version 'cerulean'
game 'gta5'

description 'QB-Petition - Advanced Petition System'
version '1.0.0'
author 'Your Name'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/assets/fonts/*.ttf',
    'html/assets/img/*.png',
}

lua54 'yes'
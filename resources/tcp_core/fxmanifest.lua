fx_version 'cerulean'
game 'gta5'

author 'TCP'
description 'Lightweight TCP core framework'
version '0.1.0'

dependency 'oxmysql'

shared_scripts {
    '@oxmysql/lib/MySQL.lua',
    'shared/config.lua',
    'shared/utils.lua'
}

server_scripts {
    'server/main.lua',
    'server/callbacks.lua',
    'server/identifiers.lua',
    'server/playerdata.lua',
    'server/permissions.lua',
    'modules/chat_commands/server/main.lua'
}

client_scripts {
    'client/main.lua',
    'client/callbacks.lua',
    'modules/chat_commands/client/main.lua',
    'modules/hud/client/main.lua'
}

ui_page 'modules/hud/html/index.html'

files {
    'modules/chat_commands/theme/style.css',
    'modules/hud/html/index.html',
    'modules/hud/html/style.css',
    'modules/hud/html/script.js'
}

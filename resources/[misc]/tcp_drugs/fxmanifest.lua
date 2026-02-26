fx_version 'cerulean'
game 'gta5'

name        'tcp_drugs'
description 'Drug growing, processing, and selling system'
version     '1.0.0'

ui_page 'nui/dialogue.html'

files {
    'nui/dialogue.html',
    'nui/dialogue.js',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client.lua',
    'dev.lua',   -- remove when zone placement is done
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

dependencies {
    'ox_inventory',
    'ox_target',
    'ox_lib',
    'ND_Core',
}

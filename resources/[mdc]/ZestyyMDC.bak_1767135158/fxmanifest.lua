fx_version 'cerulean'
game 'gta5'

author 'Zestyy'
description 'Master MDC Integration'
version '1.0.0'

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/style.css',
    'ui/script.js'
}

shared_scripts {
    '@ox_lib/init.lua',
    'shared.lua'
}

client_scripts {
    'client.lua',
    'gstmapper_client.lua'
}
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua',
    'gstmapper_server.lua'
}

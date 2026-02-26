fx_version 'cerulean'
game 'gta5'
lua54 'yes'

description 'TCP DMV - Licensing & Registration for California Project'
author 'Spark / Gemini'

dependencies {
    'ND_Core',
    'oxmysql',
    'ox_lib'
}

shared_script '@ox_lib/init.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

client_scripts {
    'client/main.lua'
}

exports {
    'getPersonData',
    'getVehicleData',
    'updateLicense',
    'flagVehicle'
}

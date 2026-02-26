fx_version 'cerulean'
game 'gta5'
lua54 'yes'

description 'Vehicle repair interaction using ox_target'

shared_script '@ox_lib/init.lua'

client_scripts {
    'config.lua',
    'client.lua'
}

dependencies {
    'ox_lib',
    'ox_target'
}

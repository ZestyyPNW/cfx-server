fx_version 'cerulean'

game 'gta5'

lua54 'yes'

description 'tcp_core (includes SimpleHUD)'

dependencies {
	'chat',
	'ND_Core',
	'ox_target'
}

ui_page 'ui/index.html'

files {
	'ui/index.html',
	'ui/style.css',
	'ui/script.js',
	'ui/notification.wav',
	'ui/notify_sound.wav',
	'postals.json'
}

shared_scripts {
	'config.lua',
	'sheriff_config.lua',
	'@ZestyyMDC/shared.lua'
}

client_scripts {
        'client/utils.lua',
        'client/c_backwalk.lua',
        'client/c_brakelights.lua',
        'client/c_moveover.lua',
        'client/c_weapons.lua',
        'client/c_doors.lua',
        'client/c_vehicle_state.lua',
        'client/c_damage_feed.lua',
        'client/c_injury_effects.lua',
        'client/sheriff_npc.lua',
        'src/client.lua',
        'modules/notifications/client/main.lua'
}

server_scripts {
        'config_server.lua',
        'src/server.lua',
        'server/sheriff_npc.lua',
        'modules/notifications/server/main.lua'
}
exports {
	'getAOP',
	'getPostal',
	'getStreetAndCrossAtCoord',
	'getLocationAtCoord'
}

server_exports {
	'getPostal'
}

provide 'nearest-postal'

fx_version 'cerulean'
game 'gta5'

name 'tcp_radio'
description 'In-vehicle radio with spatial audio'
author 'TCP'

dependency 'xsound'

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'radio_overlay.png'
}

client_script 'client.lua'
server_script 'server.lua'

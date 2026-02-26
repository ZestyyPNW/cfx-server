-- fxmanifest.lua
fx_version 'cerulean'
game 'gta5'

ui_page 'html/index.html'

files {
  'html/index.html',
  'html/app.js',
  'html/style.css',
  'html/frontend/assets/imgs/*.png',
  'ui/frontend/assets/imgs/*.png'
}

shared_scripts {
  'shared.lua',
  'config.lua',
  'codes.lua'
}
client_scripts {
  'client.lua',
  'gstmapper_client.lua'
}
server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server.lua',
  'gstmapper_server.lua',
  'worksheet_handler.lua'
}

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'PNWS Connect'
description 'Connect network bridge: join authorization, session tracking, sanctions sync'
version '0.1.0'

server_scripts { 'server/main.lua' }

convar_category 'Connect Bridge' {
    { 'Connect API base URL', 'connect_api_base', 'string', 'https://connect.primalnetworks.co' },
    { 'Connect service token', 'connect_service_token', 'string', '' },
    { 'Offline decision cache seconds', 'connect_cache_ttl', 'number', 300 },
}

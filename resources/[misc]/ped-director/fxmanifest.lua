fx_version 'cerulean'
game 'gta5'

author 'Claude'
description 'Spawn AI peds with animations for R* Editor videos'
version '1.3.0'

dependencies {
    'RageUI'
}

files {
    'stream/**/*.ycd',
    'stream/**/*.ytyp',
    'stream/**/*.ydr',
    'stream/**/*.ytd',
    'client/rpemotes/AnimationList.lua',
    'client/rpemotes/AnimationListCustom.lua',
    'client/rpemotes/ped_director_bulk_anims.txt',
    'presets.json'
}

server_script 'server.lua'



data_file 'DLC_ITYP_REQUEST' 'stream/props/Scully/scully_props.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/props/KnjghPizzaSlices/knjgh_pizzas.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/props/vedere/vedere_props.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/props/KayKayMods/kaykaymods_props.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/props/rpemotesreborn/rpemotesreborn_props.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/props/Brummiee/brummie_props.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/props/NattyLollipops/natty_props_lollipops.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/props/CandyApple/apple_1.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/props/EP/pprp_icefishing.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/props/PNWParksFan/pnwsigns.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/props/UltraRingCase/ultra_ringcase.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/props/PataMods/pata_props.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/props/BzzziProps/bzzz_camp_props.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/props/BzzziProps/bzzz_props.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/props/BzzziProps/samnick_prop_lighter01.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/props/BzzziProps/bzzz_murderpack.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/props/badge2/copbadge.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/props/Pride Props/prideprops_ytyp.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/props/Pride Props/lilflags_ytyp.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/props/badge1/badge1.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/props/rpemotesreborn/prop_vin_storytime_popcorn.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/props/BzzzFoodPack/bzzz_foodpack.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/props/babe/bebekbus.ytyp'
client_scripts {
    -- RageUI (must be loaded into this resource context)
    '@RageUI/src/RageUI.lua',
    '@RageUI/src/Menu.lua',
    '@RageUI/src/MenuController.lua',
    '@RageUI/src/components/*.lua',
    '@RageUI/src/elements/*.lua',
    '@RageUI/src/items/*.lua',

    -- Resource Scripts
    'client/rpemotes/init.lua',
    'client/*.lua'
}

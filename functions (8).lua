



fx_version "cerulean"
game "gta5"
lua54 "yes"
title "LB PicChat"
description "A social media addon app for LB Phone."
author "Breze & Loaf"
version "1.2.0"
shared_script {
    "config/*.lua",
    "shared/**/*.lua"
}
client_script "client/**.lua"
server_scripts {
    "@oxmysql/lib/MySQL.lua",
    "server/**/*.lua",
}
files {
    "config/locales/*.json",
    "ui/dist/**/*",
    "ui/icon.png"
}
ui_page "ui/dist/index.html"
escrow_ignore {
    "*/custom/**",
    "shared/**",
    "config/**",
    "server/apiKeys.lua"
}
dependency '/assetpacks'

         


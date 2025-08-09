fx_version 'cerulean'
game 'gta5'

author 'Elad'
description 'Advanced Police Vehicle Management System with GPS, Maintenance, NUI, AI Dispatcher, and Stats'
version '3.0.0'

-- קבצי לקוח ושרת
client_scripts {
    'client/client.lua'
}

server_scripts {
    'server/server.lua'
}

-- קבצים משותפים (אם תוסיף config בעתיד)
shared_scripts {
    '@qb-core/shared/locale.lua',
    'config.lua'
}

-- ממשק ניהולי NUI
ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

-- תלות במשאבים נדרשים
dependencies {
    'qb-core',
    'qb-target',
    'qb-menu',
    'qb-vehiclekeys',
    'PolyZone'
}

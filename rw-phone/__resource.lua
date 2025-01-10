fx_version 'cerulean'
game 'gta5'
lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua'
}

client_scripts {
    'client/**.lua',
    'config.lua',
}

server_scripts {
    '@mysql-async/lib/MySQL.lua', -- Ganti Jika kamu menggunakan selain mysql-async
    'server/*.lua',
    'config.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/js/*.js',
    'html/img/*.png',
    'html/css/*.css',
    'html/fonts/*.ttf',
    'html/fonts/*.otf',
    'html/fonts/*.woff',
    'html/img/backgrounds/*.png',
    'html/img/apps/*.png',
}

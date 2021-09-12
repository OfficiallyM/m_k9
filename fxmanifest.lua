fx_version 'cerulean'
game 'gta5'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/libraries/axios.min.js',
    'html/libraries/vue.min.js',
    'html/libraries/vuetify.js',
    'html/libraries/vuetify.css',
    'html/style.css',
    'html/script.js',
    'html/images/dog_left.png',
    'html/images/dog_right.png',
    'html/images/husky.png',
    'html/images/rottweiler.png',
    'html/images/shepherd.png',
    'html/images/retriever.png'
}

server_scripts { 
    'server/main.lua',
}

shared_scripts {
    '@qb-core/import.lua',
    'config.lua',
} 

client_scripts {
    'client/main.lua' 
} 


function onCreate()
    setProperty('defaultCamZoom', 0.8)

    makeLuaSprite('rockslide', 'rockslide', 0, 0)
    screenCenter('rockslide', 'xy')
    setProperty('rockslide.antialiasing', true)
    setProperty('rockslide.active', false)
    addLuaSprite('rockslide', false)
end

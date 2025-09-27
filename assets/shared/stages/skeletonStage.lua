
function onCreate()
    setProperty('defaultCamZoom', 0.8)

    makeLuaSprite('darkness', 'darkness', 0, 0)
    screenCenter('darkness', 'xy')
    setProperty('darkness.antialiasing', true)
    setProperty('darkness.active', false)
    addLuaSprite('darkness', false)
end

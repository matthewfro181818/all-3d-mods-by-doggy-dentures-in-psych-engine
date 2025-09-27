
function onCreate()
    setProperty('defaultCamZoom', 0.66)

    makeLuaSprite('redfloor', 'redfloor', 0, 0)
    screenCenter('redfloor', 'xy')
    setProperty('redfloor.antialiasing', true)
    setProperty('redfloor.active', false)
    addLuaSprite('redfloor', false)
end

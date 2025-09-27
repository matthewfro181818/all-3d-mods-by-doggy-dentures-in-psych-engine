
function onCreate()
    setProperty('defaultCamZoom', 0.85)

    makeLuaSprite('bedroom', 'bedroom', 0, 0)
    setGraphicSize('bedroom', math.floor(getProperty('bedroom.width') * 0.9))
    updateHitbox('bedroom')
    screenCenter('bedroom', 'xy')
    setProperty('bedroom.antialiasing', true)
    setProperty('bedroom.active', false)
    addLuaSprite('bedroom', false)
end

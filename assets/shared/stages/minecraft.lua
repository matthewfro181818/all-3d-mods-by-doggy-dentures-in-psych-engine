
function onCreate()
    setProperty('defaultCamZoom', 0.9)

    makeLuaSprite('flatland', 'flatland', 0, 0)
    screenCenter('flatland', 'xy')
    setProperty('flatland.antialiasing', true)
    setScrollFactor('flatland', 0.9, 0.9)
    setProperty('flatland.active', false)
    addLuaSprite('flatland', false)
end

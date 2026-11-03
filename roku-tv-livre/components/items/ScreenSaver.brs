sub init()
    m.overlay = m.top.findNode("overlay")
    m.floater = m.top.findNode("floater")
    m.ssPoster = m.top.findNode("ssPoster")
    m.ssTitle = m.top.findNode("ssTitle")
    m.ssClock = m.top.findNode("ssClock")
    m.clockTimer = m.top.findNode("clockTimer")
    m.clockTimer.observeField("fire", "onClockTick")
    m.moveTimer = m.top.findNode("moveTimer")
    m.moveTimer.observeField("fire", "onMove")
    m.posX = 860
    m.posY = 340
    m.dirX = 1
    m.dirY = 1
end sub

sub onActive()
    if m.top.active
        updateClock()
        randomStart()
        m.overlay.visible = true
        m.floater.visible = true
        m.clockTimer.control = "start"
        m.moveTimer.control = "start"
    else
        m.overlay.visible = false
        m.floater.visible = false
        m.clockTimer.control = "stop"
        m.moveTimer.control = "stop"
    end if
end sub

sub onPoster()
    m.ssPoster.uri = m.top.posterUri
end sub

sub onTitle()
    m.ssTitle.text = m.top.title
end sub

sub randomStart()
    m.posX = 200 + Rnd(1400)
    m.posY = 100 + Rnd(500)
    m.dirX = 1
    if Rnd(2) = 1 then m.dirX = -1
    m.dirY = 1
    if Rnd(2) = 1 then m.dirY = -1
    m.floater.translation = [m.posX, m.posY]
end sub

sub onMove()
    stepX = 80 + Rnd(60)
    stepY = 60 + Rnd(40)
    m.posX = m.posX + m.dirX * stepX
    m.posY = m.posY + m.dirY * stepY
    if m.posX < 100 then m.posX = 100 : m.dirX = 1
    if m.posX > 1620 then m.posX = 1620 : m.dirX = -1
    if m.posY < 60 then m.posY = 60 : m.dirY = 1
    if m.posY > 620 then m.posY = 620 : m.dirY = -1
    m.floater.translation = [m.posX, m.posY]
end sub

sub onClockTick()
    updateClock()
end sub

sub updateClock()
    dt = CreateObject("roDateTime")
    dt.toLocalTime()
    h = dt.getHours()
    mi = dt.getMinutes()
    hStr = h.ToStr()
    if h < 10 then hStr = "0" + hStr
    mStr = mi.ToStr()
    if mi < 10 then mStr = "0" + mStr
    m.ssClock.text = hStr + ":" + mStr
end sub

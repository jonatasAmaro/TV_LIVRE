sub init()
    m.osd = m.top.findNode("osd")
    m.stateLbl = m.top.findNode("stateLbl")
    m.timeLbl = m.top.findNode("timeLbl")
    m.barFill = m.top.findNode("barFill")
    m.knob = m.top.findNode("knob")
    m.seekTimer = m.top.findNode("seekTimer")
    m.seekTimer.observeField("fire", "onSeekTick")
    m.hideTimer = m.top.findNode("hideTimer")
    m.hideTimer.observeField("fire", "onHide")
    m.panelTimer = m.top.findNode("panelTimer")
    m.panelTimer.observeField("fire", "onPanelIdle")
    m.bg = m.top.findNode("bg")
    m.buttons = m.top.findNode("buttons")
    m.hintLbl = m.top.findNode("hintLbl")
    m.btnBg = []
    m.btnIcon = []
    for i = 0 to 2
        m.btnBg.Push(m.top.findNode("btnBg" + i.ToStr()))
        m.btnIcon.Push(m.top.findNode("btnIcon" + i.ToStr()))
    end for
    m.seekDir = 0
    m.seekPos = 0
    m.seekTicks = 0
    m.panel = false
    m.btn = 1
end sub

sub onActive()
    if m.top.active then return
    m.seekTimer.control = "stop"
    m.hideTimer.control = "stop"
    m.seekDir = 0
    if m.panel then closePanel()
    m.osd.visible = false
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    v = m.top.video
    if v = invalid then return false
    if m.panel
        handled = panelKey(key, press)
        if handled then return true
    else if key = "up"
        if press then openPanel()
        return true
    end if
    if key = "OK" or key = "play"
        if press then togglePause()
        return true
    end if
    dir = 0
    if key = "right" or key = "fastforward" then dir = 1
    if key = "left" or key = "rewind" then dir = -1
    if dir = 0 then return false
    if m.top.live then return true
    if press
        startSeek(dir)
    else
        endSeek()
    end if
    return true
end function

sub togglePause()
    v = m.top.video
    if v.state = "paused"
        v.control = "resume"
        showOsd(Int(v.position), "Reproduzindo")
        hideLater()
        updateButtons(false)
    else
        v.control = "pause"
        m.hideTimer.control = "stop"
        showOsd(Int(v.position), "Pausado")
        updateButtons(true)
    end if
end sub

' ---------- Media panel (Up) ----------

' Panel keys; returns false for keys it leaves to the default handling (Play, Rew, FF).
function panelKey(key as String, press as Boolean) as Boolean
    if key = "up" then return true
    if key = "down" or key = "back"
        if press then closePanel()
        return true
    end if
    if key = "left" or key = "right"
        if press and m.seekDir = 0
            if key = "left" and m.btn > 0 then m.btn--
            if key = "right" and m.btn < 2 then m.btn++
            updateButtons(m.top.video.state = "paused")
            m.panelTimer.control = "start"
        end if
        return true
    end if
    if key = "OK"
        if m.btn = 1
            if press then togglePause()
        else if not m.top.live
            if press
                startSeek(m.btn - 1)
            else
                endSeek()
            end if
        end if
        m.panelTimer.control = "start"
        return true
    end if
    return false
end function

sub openPanel()
    m.panel = true
    m.btn = 1
    m.hideTimer.control = "stop"
    m.bg.translation = [0, 770]
    m.bg.height = 310
    m.stateLbl.visible = false
    m.hintLbl.visible = false
    m.buttons.visible = true
    paused = m.top.video.state = "paused"
    updateButtons(paused)
    showOsd(Int(m.top.video.position), "")
    m.panelTimer.control = "start"
end sub

sub closePanel()
    m.panel = false
    m.panelTimer.control = "stop"
    m.buttons.visible = false
    m.bg.translation = [0, 860]
    m.bg.height = 220
    m.stateLbl.visible = true
    m.hintLbl.visible = true
    if m.top.video <> invalid and m.top.video.state = "paused"
        showOsd(Int(m.top.video.position), "Pausado")
    else
        m.osd.visible = false
    end if
end sub

' Closes after a few idle seconds while playing; stays open while paused.
sub onPanelIdle()
    if m.seekDir = 0 and m.top.video.state <> "paused" then closePanel()
end sub

' Focused button: solid white circle with a black icon.
sub updateButtons(paused as Boolean)
    if paused
        m.btnIcon[1].uri = "pkg:/images/media_play.png"
    else
        m.btnIcon[1].uri = "pkg:/images/media_pause.png"
    end if
    for i = 0 to 2
        if i = m.btn
            m.btnBg[i].opacity = 1
            m.btnIcon[i].blendColor = "0x000000FF"
        else
            m.btnBg[i].opacity = 0.25
            m.btnIcon[i].blendColor = "0xFFFFFFFF"
        end if
    end for
end sub

' ---------- Continuous seek ----------

sub startSeek(dir as Integer)
    if m.seekDir <> 0 then return
    m.seekDir = dir
    m.seekTicks = 0
    m.seekPos = Int(m.top.video.position)
    m.hideTimer.control = "stop"
    moveSeek(10)
    m.seekTimer.control = "start"
end sub

' Every 0.25 s while held: 10 s steps, then 30 s after ~2 s, 60 s after ~5 s.
sub onSeekTick()
    m.seekTicks++
    stepSecs = 10
    if m.seekTicks >= 8 then stepSecs = 30
    if m.seekTicks >= 20 then stepSecs = 60
    moveSeek(stepSecs)
end sub

sub moveSeek(stepSecs as Integer)
    dur = Int(m.top.video.duration)
    m.seekPos = m.seekPos + m.seekDir * stepSecs
    if m.seekPos < 0 then m.seekPos = 0
    if dur > 10 and m.seekPos > dur - 5 then m.seekPos = dur - 5
    label = "Avançando"
    if m.seekDir < 0 then label = "Voltando"
    showOsd(m.seekPos, label)
end sub

' The video jumps once, on release, so the stream is not re-buffered at every step.
sub endSeek()
    m.seekTimer.control = "stop"
    if m.seekDir = 0 then return
    m.seekDir = 0
    v = m.top.video
    v.seek = m.seekPos
    if v.state = "paused"
        showOsd(m.seekPos, "Pausado")
    else
        showOsd(m.seekPos, "Reproduzindo")
        hideLater()
    end if
end sub

' ---------- Bar ----------

sub showOsd(secs as Integer, state as String)
    dur = Int(m.top.video.duration)
    m.stateLbl.text = state
    if dur > 0
        m.timeLbl.text = Fmt_Time(secs) + " / " + Fmt_Time(dur)
        w = Int(1760 * secs / dur)
    else
        m.timeLbl.text = Fmt_Time(secs)
        w = 0
    end if
    m.barFill.width = w
    m.knob.translation = [74 + w, 956]
    m.osd.visible = true
end sub

sub hideLater()
    if m.panel
        m.panelTimer.control = "start"
        return
    end if
    m.hideTimer.control = "stop"
    m.hideTimer.control = "start"
end sub

sub onHide()
    if m.panel then return
    if m.seekDir = 0 and m.top.video.state <> "paused" then m.osd.visible = false
end sub

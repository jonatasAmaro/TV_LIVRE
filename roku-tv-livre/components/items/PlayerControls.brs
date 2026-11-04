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
    m.epInfoLbl = m.top.findNode("epInfoLbl")
    m.actionRow = m.top.findNode("actionRow")
    m.actionBg = [m.top.findNode("actionBg0"), m.top.findNode("actionBg1")]
    m.actionLbl = [m.top.findNode("actionLbl0"), m.top.findNode("actionLbl1")]
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
    m.panelRow = 0
    m.actionBtn = 0

    ' Subtitle toast
    m.subToast = m.top.findNode("subToast")
    m.subToastBg = m.top.findNode("subToastBg")
    m.subToastTimer = m.top.findNode("subToastTimer")
    m.subToastTimer.observeField("fire", "onSubToastHide")

    ' Skip intro/outro
    m.skipBtn = m.top.findNode("skipBtn")
    m.skipLbl = m.top.findNode("skipLbl")
    m.skipTarget = 0
    m.skipVisible = false
    m.skipVideoObs = false

    ' Playback speed
    m.speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
    m.speedIdx = 2
    m.speedLbl = m.top.findNode("speedLbl")
end sub

sub onActive()
    if m.top.active
        resetSpeed()
        return
    end if
    m.seekTimer.control = "stop"
    m.hideTimer.control = "stop"
    m.seekDir = 0
    if m.panel then closePanel()
    m.osd.visible = false
    hideSkip()
    resetSpeed()
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
        if press
            if m.skipVisible
                doSkip()
            else
                togglePause()
            end if
        end if
        return true
    end if
    ' * key (options) toggles subtitles
    if key = "options" and press
        toggleSubtitle()
        return true
    end if
    ' replay key cycles playback speed
    if key = "replay" and press
        cycleSpeed()
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

function panelKey(key as String, press as Boolean) as Boolean
    if key = "up"
        if press and m.panelRow = 1
            m.panelRow = 0
            updateActionHighlight()
            updateButtons(m.top.video.state = "paused")
        end if
        return true
    end if
    if key = "back"
        if press then closePanel()
        return true
    end if
    if key = "down"
        if press
            if m.panelRow = 0 and m.top.showEpisodeActions
                m.panelRow = 1
                updateActionHighlight()
                unhighlightButtons()
            else
                closePanel()
            end if
        end if
        return true
    end if
    if key = "left" or key = "right"
        if press and m.seekDir = 0
            if m.panelRow = 0
                if key = "left" and m.btn > 0 then m.btn = m.btn - 1
                if key = "right" and m.btn < 2 then m.btn = m.btn + 1
                updateButtons(m.top.video.state = "paused")
            else
                if key = "left" and m.actionBtn > 0 then m.actionBtn = m.actionBtn - 1
                if key = "right" and m.actionBtn < 1 then m.actionBtn = m.actionBtn + 1
                updateActionHighlight()
            end if
            m.panelTimer.control = "start"
        end if
        return true
    end if
    if key = "OK"
        if m.panelRow = 1
            if press
                if m.actionBtn = 0
                    m.top.onNextEpisode = true
                else
                    m.top.onRestartEpisode = true
                end if
                closePanel()
            end if
        else
            if m.btn = 1
                if press then togglePause()
            else if not m.top.live
                if press
                    startSeek(m.btn - 1)
                else
                    endSeek()
                end if
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
    m.panelRow = 0
    m.actionBtn = 0
    m.hideTimer.control = "stop"
    m.bg.translation = [0, 700]
    m.bg.height = 380
    m.stateLbl.visible = false
    m.hintLbl.visible = false
    m.buttons.visible = true
    m.epInfoLbl.translation = [80, 720]
    if m.top.showEpisodeActions
        m.actionRow.visible = true
        updateActionHighlight()
    end if
    paused = m.top.video.state = "paused"
    updateButtons(paused)
    showOsd(Int(m.top.video.position), "")
    m.panelTimer.control = "start"
end sub

sub closePanel()
    m.panel = false
    m.panelRow = 0
    m.panelTimer.control = "stop"
    m.buttons.visible = false
    m.actionRow.visible = false
    m.bg.translation = [0, 860]
    m.bg.height = 220
    m.stateLbl.visible = true
    m.hintLbl.visible = true
    m.epInfoLbl.translation = [80, 830]
    if m.top.video <> invalid and m.top.video.state = "paused"
        showOsd(Int(m.top.video.position), "Pausado")
    else
        m.osd.visible = false
    end if
end sub

sub onPanelIdle()
    if m.seekDir = 0 and m.top.video.state <> "paused" then closePanel()
end sub

sub updateButtons(paused as Boolean)
    if paused
        m.btnIcon[1].uri = "pkg:/images/media_play.png"
    else
        m.btnIcon[1].uri = "pkg:/images/media_pause.png"
    end if
    for i = 0 to 2
        if i = m.btn and m.panelRow = 0
            m.btnBg[i].opacity = 1
            m.btnIcon[i].blendColor = "0x000000FF"
        else
            m.btnBg[i].opacity = 0.25
            m.btnIcon[i].blendColor = "0xFFFFFFFF"
        end if
    end for
end sub

sub unhighlightButtons()
    for i = 0 to 2
        m.btnBg[i].opacity = 0.25
        m.btnIcon[i].blendColor = "0xFFFFFFFF"
    end for
end sub

sub updateActionHighlight()
    for i = 0 to 1
        if i = m.actionBtn and m.panelRow = 1
            m.actionBg[i].opacity = 1
            m.actionLbl[i].color = "0xFFFFFFFF"
        else
            m.actionBg[i].opacity = 0.3
            m.actionLbl[i].color = "0xC8D0DCFF"
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

sub onSeekTick()
    m.seekTicks = m.seekTicks + 1
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
    info = m.top.episodeInfo
    if info <> "" and info <> invalid
        m.epInfoLbl.text = info
        m.epInfoLbl.visible = true
    else
        m.epInfoLbl.visible = false
    end if
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

' ---------- Subtitles ----------

sub toggleSubtitle()
    tracks = m.top.subtitleTracks
    if tracks = invalid or tracks.Count() = 0
        showSubToast("Legendas indisponíveis")
        return
    end if
    idx = m.top.subtitleIndex + 1
    if idx >= tracks.Count() then idx = -1
    m.top.subtitleIndex = idx
    if idx = -1
        showSubToast("Legenda: Desligada")
    else
        showSubToast("Legenda: " + To_Str(tracks[idx].label))
    end if
end sub

sub showSubToast(msg as String)
    m.subToastBg.visible = true
    m.subToast.text = msg
    m.subToast.visible = true
    m.subToastTimer.control = "stop"
    m.subToastTimer.control = "start"
end sub

sub onSubToastHide()
    m.subToast.visible = false
    m.subToastBg.visible = false
end sub

' ---------- AniSkip ----------

sub onSkipSegments()
    m.skipBtn.visible = false
    m.skipVisible = false
    m.skipTarget = 0
    v = m.top.video
    if v <> invalid and not m.skipVideoObs
        v.observeField("position", "onSkipPosition")
        m.skipVideoObs = true
    end if
end sub

sub onSkipPosition()
    v = m.top.video
    if v = invalid then return
    checkSkip(Int(v.position))
end sub

sub checkSkip(curPos as Integer)
    segs = m.top.skipSegments
    if segs = invalid
        hideSkip()
        return
    end if
    opSeg = segs.op
    if opSeg <> invalid
        if curPos >= opSeg.start and curPos < opSeg.finish
            showSkip("Pular abertura", opSeg.finish)
            return
        end if
    end if
    edSeg = segs.ed
    if edSeg <> invalid
        if curPos >= edSeg.start and curPos < edSeg.finish
            showSkip("Pular encerramento", edSeg.finish)
            return
        end if
    end if
    hideSkip()
end sub

sub showSkip(label as String, target as Integer)
    m.skipLbl.text = label
    m.skipTarget = target
    if not m.skipVisible
        m.skipBtn.visible = true
        m.skipVisible = true
    end if
end sub

sub hideSkip()
    if m.skipVisible
        m.skipBtn.visible = false
        m.skipVisible = false
        m.skipTarget = 0
    end if
end sub

sub doSkip()
    if m.skipTarget > 0
        m.top.video.seek = m.skipTarget
        hideSkip()
        showSubToast("Pulou!")
    end if
end sub

' ---------- Playback speed ----------

sub cycleSpeed()
    m.speedIdx = m.speedIdx + 1
    if m.speedIdx >= m.speeds.Count() then m.speedIdx = 0
    spd = m.speeds[m.speedIdx]
    v = m.top.video
    if v <> invalid then v.playbackSpeed = spd
    if spd = 1.0
        showSubToast("Velocidade: Normal")
        m.speedLbl.visible = false
    else
        label = spd.ToStr() + "x"
        showSubToast("Velocidade: " + label)
        m.speedLbl.text = label
        m.speedLbl.visible = true
    end if
end sub

sub resetSpeed()
    m.speedIdx = 2
    v = m.top.video
    if v <> invalid then v.playbackSpeed = 1.0
    m.speedLbl.visible = false
end sub

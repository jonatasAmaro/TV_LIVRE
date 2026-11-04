sub init()
    m.video = m.top.findNode("video")
    m.status = m.top.findNode("status")
    m.chName = m.top.findNode("chName")
    m.chInfo = m.top.findNode("chInfo")
    m.epgNow = m.top.findNode("epgNow")
    m.osd = m.top.findNode("osd")
    m.osdName = m.top.findNode("osdName")
    m.osdInfo = m.top.findNode("osdInfo")
    m.osdEpg = m.top.findNode("osdEpg")
    m.osdTimer = m.top.findNode("osdTimer")
    m.btnRow = m.top.findNode("btnRow")
    m.btnBg = [m.top.findNode("btnBg0"), m.top.findNode("btnBg1")]
    m.infoStrip = m.top.findNode("infoStrip")

    m.btnIndex = 0
    m.inButtons = false
    m.fullscreen = false
    m.chIndex = -1
    m.epgGuide = {}
    m.qualityIndex = loadQualityPref()
    m.qualities = [
        { label: "Auto", bw: 0 },
        { label: "Alta (1080p)", bw: 5000000 },
        { label: "Media (720p)", bw: 2500000 },
        { label: "Baixa (480p)", bw: 1000000 },
        { label: "Minima (360p)", bw: 500000 }
    ]

    m.video.observeField("state", "onState")
    m.osdTimer.observeField("fire", "hideOsd")
    m.top.observeField("focusedChild", "onFocusChange")
    m.top.observeField("active", "onActive")

    m.epgTimer = m.top.findNode("epgTimer")
    m.epgTimer.observeField("fire", "refreshEpg")
end sub

sub onChannels()
    startEpg()
    idx = To_Int(Store_Get("lastLiveCh", "0"))
    playChannel(idx)
end sub

sub playChannel(idx as Integer)
    chs = m.top.channels
    if chs = invalid or chs.Count() = 0 then return
    if idx < 0 or idx >= chs.Count() then idx = 0
    m.chIndex = idx
    ch = chs[idx]
    m.chName.text = To_Str(ch.title)
    parts = []
    if To_Str(ch.info) <> "" then parts.Push(To_Str(ch.info))
    if To_Str(ch.group) <> "" then parts.Push(To_Str(ch.group))
    m.chInfo.text = parts.Join("  |  ")
    updateEpg(To_Str(ch.title))

    c = CreateObject("roSGNode", "ContentNode")
    c.url = To_Str(ch.url)
    c.title = To_Str(ch.title)
    c.streamFormat = "hls"
    c.live = true
    bw = m.qualities[m.qualityIndex].bw
    if bw > 0 then c.maxBandwidth = bw
    m.video.control = "stop"
    m.video.content = c
    m.video.control = "play"
    showStatus("Carregando " + c.title + "...")
    Store_Set("lastLiveCh", idx.ToStr())
end sub

sub onState()
    s = m.video.state
    if s = "playing"
        m.status.visible = false
    else if s = "buffering"
        showStatus("Carregando...")
    else if s = "error"
        showStatus("Canal indisponivel no momento.")
    end if
end sub

sub showStatus(text as String)
    m.status.text = text
    m.status.visible = true
end sub

sub onActive()
    if m.top.active and m.top.visible
        if m.chIndex >= 0
            m.video.control = "play"
        end if
    else
        m.video.control = "stop"
        if m.fullscreen then exitFullscreen()
    end if
end sub

sub focusButtons()
    m.inButtons = true
    m.btnIndex = 0
    refreshButtons()
    m.btnRow.setFocus(true)
end sub

sub onFocusChange()
    if m.top.hasFocus() and not m.fullscreen
        focusButtons()
    end if
end sub

sub refreshButtons()
    for i = 0 to 1
        if m.inButtons and i = m.btnIndex
            m.btnBg[i].blendColor = "0x9B5DE5FF"
        else
            m.btnBg[i].blendColor = "0x3A3F4BFF"
        end if
    end for
end sub

sub enterFullscreen()
    m.fullscreen = true
    m.video.translation = [0, 0]
    m.video.width = 1920
    m.video.height = 1080
    m.btnRow.visible = false
    m.infoStrip.visible = false
    m.chName.visible = false
    m.chInfo.visible = false
    m.epgNow.visible = false
    showOsd()
end sub

sub exitFullscreen()
    m.fullscreen = false
    m.video.translation = [0, 100]
    m.video.width = 1920
    m.video.height = 980
    m.btnRow.visible = true
    m.infoStrip.visible = true
    m.chName.visible = true
    m.chInfo.visible = true
    refreshButtons()
end sub

sub showOsd()
    if m.chIndex < 0 then return
    chs = m.top.channels
    ch = chs[m.chIndex]
    m.osdName.text = To_Str(ch.title)
    parts = []
    if To_Str(ch.info) <> "" then parts.Push(To_Str(ch.info))
    m.osdInfo.text = parts.Join("  |  ")
    updateOsdEpg(To_Str(ch.title))
    m.osd.visible = true
    m.osdTimer.control = "stop"
    m.osdTimer.control = "start"
end sub

sub hideOsd()
    m.osd.visible = false
end sub

sub zap(delta as Integer)
    chs = m.top.channels
    if chs = invalid or chs.Count() = 0 then return
    idx = m.chIndex + delta
    n = chs.Count()
    idx = (idx + n) mod n
    playChannel(idx)
    if m.fullscreen then showOsd()
end sub

' ---------- EPG ----------

sub startEpg()
    m.epgTask = CreateObject("roSGNode", "EPGTask")
    m.epgTask.epgUrl = m.top.epgUrl
    m.epgTask.observeField("result", "onEpgLoaded")
    m.epgTask.control = "run"
end sub

sub onEpgLoaded()
    res = m.epgTask.result
    if res <> invalid and Is_True(res.ok)
        raw = res.guide
        m.epgGuide = {}
        for each k in raw.Keys()
            nk = EpgNorm(k)
            if nk <> "" then m.epgGuide[nk] = raw[k]
        end for
    end if
    if m.chIndex >= 0
        chs = m.top.channels
        updateEpg(To_Str(chs[m.chIndex].title))
    end if
    m.epgTimer.control = "start"
end sub

sub refreshEpg()
    if m.chIndex >= 0
        chs = m.top.channels
        updateEpg(To_Str(chs[m.chIndex].title))
    end if
end sub

function EpgNorm(s as String) as String
    s = LCase(s.Trim())
    r = CreateObject("roRegex", "\([^)]*\)|\[[^\]]*\]", "")
    s = r.ReplaceAll(s, "")
    r2 = CreateObject("roRegex", "\b(hd|sd)\b", "")
    s = r2.ReplaceAll(s, "")
    s = s.Replace("-", " ").Replace("  ", " ").Trim()
    r3 = CreateObject("roRegex", "\s*\w+_local$", "")
    s = r3.ReplaceAll(s, "")
    return s.Trim()
end function

function EpgForChannel(title as String) as Object
    key = EpgNorm(title)
    progs = m.epgGuide[key]
    if progs <> invalid and progs.Count() > 0
        return EpgFindNowNext(progs)
    end if
    for each gk in m.epgGuide.Keys()
        if Instr(1, key, gk) > 0 or Instr(1, gk, key) > 0
            return EpgFindNowNext(m.epgGuide[gk])
        end if
    end for
    return { now: invalid, next: invalid }
end function

function EpgFindNowNext(progs as Object) as Object
    now = CreateObject("roDateTime").AsSeconds()
    current = invalid
    upcoming = invalid
    for i = 0 to progs.Count() - 1
        p = progs[i]
        if p.start <= now and (p.stop = 0 or p.stop > now)
            current = p
            if i + 1 < progs.Count() then upcoming = progs[i + 1]
            exit for
        else if p.start > now
            upcoming = p
            exit for
        end if
    end for
    return { now: current, next: upcoming }
end function

sub updateEpg(title as String)
    epg = EpgForChannel(title)
    if epg.now <> invalid
        dt = CreateObject("roDateTime")
        dt.FromSeconds(epg.now.start)
        dt.ToLocalTime()
        ts = Pad2(dt.GetHours()) + ":" + Pad2(dt.GetMinutes())
        m.epgNow.text = "Agora: " + epg.now.title + "  (" + ts + ")"
        m.epgNow.visible = true
    else
        m.epgNow.visible = false
    end if
end sub

sub updateOsdEpg(title as String)
    epg = EpgForChannel(title)
    if epg.now <> invalid
        m.osdEpg.text = "Agora: " + epg.now.title
    else
        m.osdEpg.text = ""
    end if
end sub

' ---------- Quality ----------

function loadQualityPref() as Integer
    v = Store_Get("streamQuality", "0")
    if v <> invalid and v <> "" then return To_Int(v)
    return 0
end function

' ---------- Keys ----------

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if m.fullscreen
        if key = "back"
            exitFullscreen()
            return true
        else if key = "right" or key = "channelUp"
            zap(1)
            return true
        else if key = "left" or key = "channelDown"
            zap(-1)
            return true
        else if key = "up" or key = "OK" or key = "info"
            showOsd()
            return true
        end if
        return true
    end if
    if m.inButtons
        if key = "left"
            if m.btnIndex > 0
                m.btnIndex = m.btnIndex - 1
                refreshButtons()
            end if
            return true
        else if key = "right"
            if m.btnIndex < 1
                m.btnIndex = m.btnIndex + 1
                refreshButtons()
            end if
            return true
        else if key = "OK"
            if m.btnIndex = 0
                enterFullscreen()
            else
                m.top.navigate = { to: "liveGrid", startIndex: m.chIndex }
            end if
            return true
        else if key = "up" or key = "back"
            m.inButtons = false
            refreshButtons()
            m.top.navigate = { to: "tabs" }
            return true
        end if
        return false
    end if
    if key = "down"
        focusButtons()
        return true
    end if
    return false
end function

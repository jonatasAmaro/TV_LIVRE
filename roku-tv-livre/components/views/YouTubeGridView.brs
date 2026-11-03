sub init()
    m.grid = m.top.findNode("grid")
    m.video = m.top.findNode("video")
    m.channelArt = m.top.findNode("channelArt")
    m.status = m.top.findNode("status")
    m.ring = m.top.findNode("ring")
    m.liveBadge = m.top.findNode("liveBadge")
    m.chName = m.top.findNode("chName")
    m.chInfo = m.top.findNode("chInfo")
    m.liveTitle = m.top.findNode("liveTitle")
    m.latestLabel = m.top.findNode("latestLabel")
    m.actionHint = m.top.findNode("actionHint")
    m.offlineMsg = m.top.findNode("offlineMsg")
    m.offlineText = m.top.findNode("offlineText")
    m.alert = m.top.findNode("alert")
    m.alertText = m.top.findNode("alertText")
    m.btnRedirBg = m.top.findNode("btnRedirBg")
    m.btnRedir = m.top.findNode("btnRedir")
    m.btnCancelBg = m.top.findNode("btnCancelBg")
    m.btnCancel = m.top.findNode("btnCancel")
    m.osd = m.top.findNode("osd")
    m.osdName = m.top.findNode("osdName")
    m.osdInfo = m.top.findNode("osdInfo")
    m.osdTimer = m.top.findNode("osdTimer")

    m.grid.observeField("itemFocused", "onGridFocus")
    m.osdTimer.observeField("fire", "onOsdTimer")
    m.video.observeField("state", "onVideoState")

    m.alertText.text = "Para assistir à última transmissão ou a outros conteúdos deste canal, teremos que te redirecionar para o app do YouTube." + Chr(10) + Chr(10) + "Deseja redirecionar para o YouTube agora?"

    m.items = []
    m.focusIdx = 0
    m.activeIdx = -1
    m.mode = "cards"
    m.state = ""
    m.alertSel = 0
    m.resolved = {}
end sub

sub onChannels()
    arr = m.top.channels
    if arr = invalid then return
    m.items = []
    content = CreateObject("roSGNode", "ContentNode")
    for each ch in arr
        it = {
            id: To_Str(ch.id),
            title: To_Str(ch.title),
            info: To_Str(ch.info),
            channelId: To_Str(ch.channelId),
            searchTerm: To_Str(ch.searchTerm),
            officialFeed: To_Str(ch.officialFeed),
            poster: To_Str(ch.poster)
        }
        m.items.Push(it)
        row = content.createChild("ContentNode")
        row.hdPosterUrl = it.poster
        row.title = it.title
        row.shortDescriptionLine1 = it.info
    end for
    m.grid.content = content
    if m.items.Count() > 0
        m.grid.jumpToItem = 0
        m.focusIdx = 0
        m.grid.setFocus(true)
        showIdle(0)
    end if
end sub

sub clearInfo()
    m.liveTitle.visible = false
    m.latestLabel.visible = false
    m.actionHint.visible = false
    m.liveBadge.visible = false
    m.offlineMsg.visible = false
    m.status.visible = false
end sub

sub showIdle(idx as Integer)
    if idx < 0 or idx >= m.items.Count() then return
    it = m.items[idx]
    clearInfo()
    m.channelArt.uri = it.poster
    m.channelArt.visible = true
    m.chName.text = it.title
    m.chInfo.text = it.info
    m.actionHint.text = "[OK] Assistir"
    m.actionHint.visible = true
end sub

sub onGridFocus()
    idx = m.grid.itemFocused
    if idx < 0 or idx >= m.items.Count() then return
    m.focusIdx = idx
    if m.activeIdx < 0 then showIdle(idx)
end sub

function nowSeconds() as Integer
    d = CreateObject("roDateTime")
    return d.AsSeconds()
end function

sub activateChannel(idx as Integer)
    if idx < 0 or idx >= m.items.Count() then return
    it = m.items[idx]
    m.activeIdx = idx
    m.state = "loading"
    stopVideo()
    clearInfo()
    m.chName.text = it.title
    m.chInfo.text = it.info
    m.channelArt.uri = it.poster
    m.channelArt.visible = true

    cached = m.resolved[it.id]
    if cached <> invalid and nowSeconds() - cached.ts < 120
        applyResult(idx, cached.res)
        return
    end if

    m.status.text = "Verificando " + it.title + "..."
    m.status.visible = true
    task = CreateObject("roSGNode", "YouTubeTask")
    task.mode = "resolve"
    task.channelId = it.channelId
    task.searchTerm = it.searchTerm
    task.observeField("result", "onResolved")
    task.control = "run"
    m.resolveTask = task
end sub

sub onResolved(evt as Object)
    task = evt.getRoSGNode()
    res = evt.getData()
    if res = invalid then return
    for i = 0 to m.items.Count() - 1
        if m.items[i].channelId = task.channelId
            m.resolved[m.items[i].id] = { res: res, ts: nowSeconds() }
            if i = m.activeIdx and m.state = "loading" then applyResult(i, res)
            exit for
        end if
    end for
end sub

sub applyResult(idx as Integer, res as Object)
    it = m.items[idx]
    m.status.visible = false
    if Is_True(res.live) and To_Str(res.streamUrl) <> ""
        m.state = "live"
        playStream(res.streamUrl, it.title)
        m.liveTitle.text = "AO VIVO"
        m.liveTitle.visible = true
        m.liveBadge.visible = true
        if To_Str(res.videoTitle) <> "" then m.chInfo.text = To_Str(res.videoTitle)
    else if it.officialFeed <> ""
        m.state = "feed"
        playStream(it.officialFeed, it.title)
        m.liveTitle.text = "AO VIVO - FEED OFICIAL"
        m.liveTitle.visible = true
        m.liveBadge.visible = true
    else if Is_True(res.live)
        showOffline("NÃO FOI POSSÍVEL REPRODUZIR AQUI, APERTE OK PARA ASSISTIR NO YOUTUBE")
    else
        showOffline("TRANSMISSÃO AO VIVO ENCERRADA, APERTE OK PARA ASSISTIR NO YOUTUBE")
        if To_Str(res.latestTitle) <> ""
            m.latestLabel.text = "ÚLTIMA TRANSMISSÃO: " + To_Str(res.latestTitle)
            m.latestLabel.visible = true
        end if
    end if
end sub

sub playStream(url as String, title as String)
    m.channelArt.visible = false
    content = CreateObject("roSGNode", "ContentNode")
    content.url = url
    content.title = title
    content.live = true
    content.streamFormat = "hls"
    m.video.content = content
    m.video.control = "play"
    if m.mode <> "full" then m.ring.visible = true
end sub

sub showOffline(msg as String)
    stopVideo()
    m.state = "offline"
    m.channelArt.visible = true
    m.offlineText.text = msg
    m.offlineMsg.visible = true
    m.actionHint.visible = false
end sub

sub stopVideo()
    m.video.control = "stop"
    m.video.content = invalid
    m.ring.visible = false
    m.liveBadge.visible = false
end sub

sub onVideoState()
    state = m.video.state
    if state = "error"
        if m.mode = "full" then exitFullscreen()
        clearInfo()
        showOffline("NÃO FOI POSSÍVEL REPRODUZIR AQUI, APERTE OK PARA ASSISTIR NO YOUTUBE")
    else if state = "playing"
        m.status.visible = false
        m.channelArt.visible = false
    else if state = "buffering"
        m.status.text = "Carregando..."
        m.status.visible = true
    end if
end sub

function isPlaying() as Boolean
    s = m.video.state
    return s = "playing" or s = "buffering"
end function

sub enterFullscreen()
    if not isPlaying() then return
    m.mode = "full"
    m.grid.visible = false
    m.chName.visible = false
    m.chInfo.visible = false
    m.liveTitle.visible = false
    m.latestLabel.visible = false
    m.actionHint.visible = false
    m.ring.visible = false
    m.liveBadge.visible = false
    m.video.translation = [0, 0]
    m.video.width = 1920
    m.video.height = 1080
    showOsd()
end sub

sub exitFullscreen()
    m.mode = "cards"
    m.grid.visible = true
    m.chName.visible = true
    m.chInfo.visible = true
    m.video.translation = [50, 88]
    m.video.width = 1040
    m.video.height = 584
    if isPlaying()
        m.ring.visible = true
        m.liveBadge.visible = true
        m.liveTitle.visible = true
    end if
    m.osd.visible = false
    m.osdTimer.control = "stop"
    m.grid.setFocus(true)
end sub

sub enterPreview()
    m.mode = "preview"
    m.ring.visible = true
end sub

sub exitPreview()
    m.mode = "cards"
    m.ring.visible = isPlaying()
    m.grid.setFocus(true)
end sub

sub showOsd()
    if m.activeIdx >= 0 and m.activeIdx < m.items.Count()
        m.osdName.text = m.items[m.activeIdx].title
        m.osdInfo.text = "AO VIVO"
    end if
    m.osd.visible = true
    m.osdTimer.control = "stop"
    m.osdTimer.control = "start"
end sub

sub onOsdTimer()
    m.osd.visible = false
end sub

sub zapChannel(direction as Integer)
    if m.items.Count() = 0 then return
    newIdx = m.activeIdx + direction
    if newIdx < 0 then newIdx = m.items.Count() - 1
    if newIdx >= m.items.Count() then newIdx = 0
    m.focusIdx = newIdx
    m.grid.jumpToItem = newIdx
    activateChannel(newIdx)
    if m.mode = "full" then showOsd()
end sub

sub showAlert()
    m.prevMode = m.mode
    m.mode = "alert"
    m.alertSel = 0
    updateAlertButtons()
    m.alert.visible = true
    m.top.setFocus(true)
end sub

sub hideAlert()
    m.alert.visible = false
    m.mode = "cards"
    if m.prevMode = "preview" then m.mode = "preview"
    m.grid.setFocus(true)
end sub

sub updateAlertButtons()
    if m.alertSel = 0
        m.btnRedirBg.color = "0xCC0000FF"
        m.btnRedir.color = "0xFFFFFFFF"
        m.btnCancelBg.color = "0xE5E5E5FF"
        m.btnCancel.color = "0x0D0D0DFF"
    else
        m.btnRedirBg.color = "0xE5E5E5FF"
        m.btnRedir.color = "0x0D0D0DFF"
        m.btnCancelBg.color = "0xCC0000FF"
        m.btnCancel.color = "0xFFFFFFFF"
    end if
end sub

' The Roku YouTube app deep-links to videos, not channels, so the channel's
' latest broadcast is opened; without one the app opens on its home screen.
sub redirectToYouTube()
    if m.activeIdx < 0 or m.activeIdx >= m.items.Count() then return
    it = m.items[m.activeIdx]
    videoId = ""
    cached = m.resolved[it.id]
    if cached <> invalid then videoId = To_Str(cached.res.latestId)
    task = CreateObject("roSGNode", "YouTubeTask")
    if videoId <> ""
        task.mode = "launch"
        task.videoId = videoId
        task.mediaType = "video"
    else
        task.mode = "app"
        task.appId = "837"
    end if
    task.control = "run"
    m.launchTask = task
end sub

sub handleOk()
    idx = m.focusIdx
    if idx = m.activeIdx
        if isPlaying()
            enterFullscreen()
            return
        else if m.state = "offline"
            showAlert()
            return
        else if m.state = "loading"
            return
        end if
    end if
    activateChannel(idx)
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if m.mode = "alert"
        if key = "left" or key = "right"
            m.alertSel = 1 - m.alertSel
            updateAlertButtons()
        else if key = "OK"
            redir = (m.alertSel = 0)
            hideAlert()
            if redir then redirectToYouTube()
        else if key = "back"
            hideAlert()
        end if
        return true
    end if

    if m.mode = "full"
        if key = "back" or key = "options"
            exitFullscreen()
            return true
        else if key = "up"
            zapChannel(-1)
            return true
        else if key = "down"
            zapChannel(1)
            return true
        else if key = "OK" or key = "play"
            showOsd()
            return true
        end if
        return false
    end if

    if m.mode = "preview"
        if key = "OK" or key = "play"
            if isPlaying()
                enterFullscreen()
            else if m.state = "offline"
                showAlert()
            end if
            return true
        else if key = "right" or key = "back"
            exitPreview()
            return true
        end if
        return true
    end if

    if key = "OK" or key = "play"
        handleOk()
        return true
    else if key = "left"
        enterPreview()
        return true
    else if key = "back"
        stopVideo()
        m.top.navigate = { to: "back" }
        return true
    end if
    return false
end function

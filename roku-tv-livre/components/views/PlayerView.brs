' Plays live HLS or Archive MP4. Archive items carry several candidate URLs
' (best quality first); on a playback error the next one is tried.
sub init()
    m.video = m.top.findNode("video")
    m.controls = m.top.findNode("controls")
    m.controls.video = m.video
    m.error = m.top.findNode("error")
    m.urls = []
    m.urlIndex = 0
    m.lastSave = 0
    m.finished = false
    m.isLive = false

    m.video.observeField("state", "onState")
    m.video.observeField("position", "onPosition")
    m.top.observeField("closing", "onClosing")
    m.top.observeField("focusedChild", "onFocusChange")

    ' Subtitles
    m.subTask = invalid
    m.subTracks = []
    m.controls.observeField("subtitleIndex", "onSubtitleChanged")
end sub

sub onFocusChange()
    if m.top.hasFocus() then m.controls.setFocus(true)
end sub

sub onParams()
    p = m.top.params
    m.isLive = Is_True(p.live)
    m.controls.live = m.isLive
    m.controls.active = true
    m.urls = p.urls
    m.urlIndex = 0
    m.lastSave = To_Int(p.start)
    startUrl(m.lastSave)

    ' Fetch subtitles if IMDb ID is available
    imdb = To_Str(p.imdb)
    if imdb <> "" and not m.isLive
        fetchSubtitles(imdb, To_Int(p.subSeason), To_Int(p.subEpisode))
    end if
end sub

sub startUrl(startPos as Integer)
    c = CreateObject("roSGNode", "ContentNode")
    c.url = m.urls[m.urlIndex]
    c.title = To_Str(m.top.params.title)
    if m.isLive
        c.streamFormat = "hls"
        c.live = true
    else
        ' Archive files are MP4; configured movie URLs may also be HLS playlists.
        c.streamFormat = "mp4"
        lowUrl = LCase(c.url)
        if Instr(1, lowUrl, ".m3u8") > 0 or Instr(1, lowUrl, "master.txt") > 0 or Instr(1, lowUrl, "/hls/") > 0 then c.streamFormat = "hls"
        if startPos > 0 then c.playStart = startPos
    end if
    m.video.content = c
    m.video.control = "play"
end sub

sub onState()
    s = m.video.state
    if s = "error"
        if m.urlIndex + 1 < m.urls.Count()
            m.urlIndex = m.urlIndex + 1
            startUrl(m.lastSave)
        else
            m.error.text = "Não foi possível reproduzir este vídeo." + Chr(10) + m.video.errorMsg + Chr(10) + Chr(10) + "Pressione Voltar."
            m.error.visible = true
        end if
    else if s = "finished"
        m.finished = true
        saveProgress(0)
        m.top.navigate = { to: "back" }
    end if
end sub

sub onPosition()
    if m.isLive then return
    curPos = Int(m.video.position)
    if Abs(curPos - m.lastSave) >= 15
        m.lastSave = curPos
        saveProgress(curPos)
    end if
end sub

sub saveProgress(curPos as Integer)
    p = m.top.params
    if m.isLive or p.id = invalid then return
    dur = Int(m.video.duration)
    entry = { id: p.id, title: To_Str(p.itemTitle), poster: To_Str(p.poster), file: To_Str(p.file), at: curPos, duration: dur }
    ' Extra fields the caller wants back in "Continuar assistindo" (e.g. a movie's url and summary).
    if type(p.extra) = "roAssociativeArray" then entry.Append(p.extra)
    Recent_Save(entry)
end sub

sub onClosing()
    if not m.finished and not m.isLive
        curPos = Int(m.video.position)
        if curPos > 0 then saveProgress(curPos)
    end if
    m.video.control = "stop"
end sub

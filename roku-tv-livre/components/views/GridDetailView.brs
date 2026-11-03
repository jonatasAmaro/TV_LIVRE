' Series screen. Focus areas: back, preview, combo (season), fav, episodes, pop (open
' combobox). Where the viewer stopped (season, episode, seconds) is kept per card
' (Grid_SaveResume) and the card reopens there.
sub init()
    m.poster = m.top.findNode("poster")
    m.headerTitle = m.top.findNode("headerTitle")
    m.video = m.top.findNode("video")
    m.videoStatus = m.top.findNode("videoStatus")
    m.previewBg = m.top.findNode("previewBg")
    m.previewRing = m.top.findNode("previewRing")
    m.fullscreenHint = m.top.findNode("fullscreenHint")
    m.posterBg = m.top.findNode("posterBg")
    m.row2 = m.top.findNode("row2")
    m.comboRing = m.top.findNode("comboRing")
    m.comboText = m.top.findNode("comboText")
    m.epLabel = m.top.findNode("epLabel")
    m.favRing = m.top.findNode("favRing")
    m.favText = m.top.findNode("favText")
    m.episodes = m.top.findNode("episodes")
    m.seasonPop = m.top.findNode("seasonPop")
    m.popBg = m.top.findNode("popBg")
    m.seasonList = m.top.findNode("seasonList")
    m.backLabel = m.top.findNode("backLabel")
    m.keySink = m.top.findNode("keySink")
    m.controls = m.top.findNode("controls")
    m.controls.video = m.video
    m.nextBox = m.top.findNode("nextBox")
    m.nextTitle = m.top.findNode("nextTitle")
    m.nextCount = m.top.findNode("nextCount")
    m.nextTimer = m.top.findNode("nextTimer")
    m.nextTimer.observeField("fire", "onNextTick")
    m.nextIdx = -1
    m.focusArea = "episodes"
    m.fullscreen = false
    m.seasonData = []
    m.currentSeason = 0
    m.currentEp = -1
    m.key = ""
    m.lastSave = 0

    m.seasonList.observeField("itemSelected", "onSeasonChosen")
    m.episodes.observeField("rowItemSelected", "onEpisodeSelected")
    m.video.observeField("state", "onVideoState")
    m.video.observeField("position", "onPosition")
    m.controls.observeField("onNextEpisode", "onCtrlNextEpisode")
    m.controls.observeField("onRestartEpisode", "onCtrlRestart")
    m.controls.observeField("subtitleIndex", "onSubtitleChanged")
    m.top.observeField("focusedChild", "onFocusChange")
    m.top.observeField("closing", "onClosing")

    ' Subtitles
    m.subTask = invalid
    m.subTracks = []
    m.imdb = ""

    ' AniSkip
    m.skipTask = invalid
    m.malId = 0

    ' Cinemeta
    m.cinemetaTask = invalid
    m.cinemetaEps = {}
    m.metaLbl = m.top.findNode("metaLbl")
    m.shuffleRing = m.top.findNode("shuffleRing")
end sub

sub onFocusChange()
    if m.fullscreen then return
    if not m.top.hasFocus() then return
    setFocusArea(m.focusArea)
end sub

sub setFocusArea(area as String)
    m.focusArea = area
    m.backLabel.color = "0x9AA4B2FF"
    m.previewRing.opacity = 0
    m.comboRing.opacity = 0
    m.shuffleRing.opacity = 0
    m.favRing.opacity = 0
    m.fullscreenHint.visible = false
    if area = "back"
        m.backLabel.color = "0x9B5DE5FF"
        m.keySink.setFocus(true)
    else if area = "preview"
        m.previewRing.opacity = 0.8
        m.fullscreenHint.visible = true
        m.keySink.setFocus(true)
    else if area = "combo"
        m.comboRing.opacity = 1
        m.keySink.setFocus(true)
    else if area = "shuffle"
        m.shuffleRing.opacity = 1
        m.keySink.setFocus(true)
    else if area = "fav"
        m.favRing.opacity = 1
        m.keySink.setFocus(true)
    else if area = "pop"
        m.comboRing.opacity = 1
        m.seasonList.setFocus(true)
    else
        m.episodes.setFocus(true)
    end if
end sub

sub onItem()
    item = m.top.item
    m.key = Grid_Key(item)
    m.headerTitle.text = To_Str(item.title)
    m.poster.uri = To_Str(item.poster)

    m.seasonData = []
    if item.seasons <> invalid
        for each s in item.seasons
            m.seasonData.Push(s)
        end for
    end if
    if m.seasonData.Count() = 0
        m.seasonData.Push({ title: "Temporada 1", episodes: [] })
    end if

    root = CreateObject("roSGNode", "ContentNode")
    for each s in m.seasonData
        n = root.createChild("ContentNode")
        n.title = "  " + To_Str(s.title)
    end for
    m.seasonList.content = root
    rows = m.seasonData.Count()
    if rows > 8 then rows = 8
    m.seasonList.numRows = rows
    h = rows * 56 + 24
    m.popBg.width = 380
    m.popBg.height = h
    m.seasonPop.translation = [80, 866 - 8 - h]

    refreshFav()
    m.imdb = To_Str(item.imdb)
    m.malId = To_Int(item.malId)

    ' Fetch Cinemeta metadata
    if m.imdb <> ""
        fetchCinemeta(m.imdb)
    end if

    ' Reopen where the viewer stopped.
    season = 0
    ep = 0
    at = 0
    m.resumeNote = ""
    rec = Grid_Resume(m.key)
    if rec <> invalid and To_Int(rec.s) < m.seasonData.Count()
        season = To_Int(rec.s)
        ep = To_Int(rec.e)
        at = To_Int(rec.at)
        m.resumeNote = "Você parou no EP " + (ep + 1).ToStr()
        if at > 0 then m.resumeNote = m.resumeNote + " (" + Fmt_Time(at) + ")"
    end if
    loadEpisodes(season, ep, at)
    setFocusArea("episodes")
end sub

' ---------- Season combobox ----------

sub openSeasons()
    m.seasonList.jumpToItem = m.currentSeason
    m.seasonPop.visible = true
    setFocusArea("pop")
end sub

sub closeSeasons()
    m.seasonPop.visible = false
    setFocusArea("combo")
end sub

sub onSeasonChosen()
    idx = m.seasonList.itemSelected
    m.seasonPop.visible = false
    m.resumeNote = ""
    loadEpisodes(idx, 0, 0)
    setFocusArea("episodes")
end sub

sub loadEpisodes(seasonIdx as Integer, epIdx as Integer, startAt as Integer)
    if seasonIdx < 0 or seasonIdx >= m.seasonData.Count() then return
    m.currentSeason = seasonIdx
    m.comboText.text = To_Str(m.seasonData[seasonIdx].title)
    eps = m.seasonData[seasonIdx].episodes
    if eps = invalid then eps = []

    root = CreateObject("roSGNode", "ContentNode")
    row = root.createChild("ContentNode")
    for i = 0 to eps.Count() - 1
        n = row.createChild("ContentNode")
        n.title = (i + 1).ToStr()
        if Watched_Has(m.key, seasonIdx, i) then n.addField("WATCHED", "string", false) : n.WATCHED = "true"
    end for
    m.episodes.content = root

    if eps.Count() = 0
        m.epLabel.text = "Nenhum episódio configurado"
        m.video.control = "stop"
        return
    end if
    total = eps.Count()
    wc = Watched_CountSeason(m.key, m.currentSeason, total)
    epCountTxt = total.ToStr() + " episódio(s)"
    if wc > 0 then epCountTxt = epCountTxt + "   |   ✓ " + wc.ToStr() + " assistido(s)"
    if m.resumeNote <> "" then epCountTxt = epCountTxt + "   |   " + m.resumeNote
    m.epLabel.text = epCountTxt
    if epIdx >= eps.Count() then epIdx = 0
    m.episodes.jumpToRowItem = [0, epIdx]
    playEpisode(epIdx, startAt)
end sub

' ---------- Minha Lista ----------

sub refreshFav()
    if Fav_Has(m.key)
        m.favText.text = "Remover da Minha Lista"
    else
        m.favText.text = "Adicionar à Minha Lista"
    end if
end sub

sub toggleFav()
    it = m.top.item
    Fav_Toggle({ id: m.key, title: To_Str(it.title), poster: To_Str(it.poster), kind: "grid" })
    refreshFav()
end sub

' ---------- Playback ----------

sub onEpisodeSelected()
    idx = m.episodes.rowItemSelected[1]
    if idx = m.currentEp and m.video.state <> "stopped" and m.video.state <> "finished"
        saveResume(Int(m.video.position))
        enterFullscreen()
    else
        playEpisode(idx, 0)
    end if
end sub

sub playEpisode(idx as Integer, startAt as Integer)
    eps = m.seasonData[m.currentSeason].episodes
    if eps = invalid or idx < 0 or idx >= eps.Count() then return
    m.currentEp = idx
    m.lastSave = startAt
    url = To_Str(eps[idx].url)
    if url = ""
        m.video.control = "stop"
        m.videoStatus.text = "Sem URL configurada"
        m.videoStatus.visible = true
        return
    end if
    m.videoStatus.text = "Carregando EP " + (idx + 1).ToStr() + "..."
    m.videoStatus.visible = true
    epInfo = To_Str(m.top.item.title) + "  |  " + To_Str(m.seasonData[m.currentSeason].title) + " - EP " + (idx + 1).ToStr()
    key = (m.currentSeason + 1).ToStr() + ":" + (idx + 1).ToStr()
    epMeta = m.cinemetaEps[key]
    if epMeta <> invalid and epMeta.name <> ""
        epInfo = epInfo + ": " + epMeta.name
    end if
    m.controls.episodeInfo = epInfo
    m.controls.showEpisodeActions = true
    c = CreateObject("roSGNode", "ContentNode")
    c.url = url
    c.title = To_Str(m.top.item.title) + " - EP " + (idx + 1).ToStr()
    ' Plain .mp4 files (no playlist) need "mp4"; ".mp4/index.m3u8" playlists stay HLS.
    c.streamFormat = "mp4"
    if Instr(1, LCase(url), ".m3u8") > 0 then c.streamFormat = "hls"
    if startAt > 0 then c.playStart = startAt
    m.video.control = "stop"
    m.video.content = c
    m.video.control = "play"

    ' Fetch subtitles for this episode
    if m.imdb <> ""
        fetchSubtitles(m.imdb, m.currentSeason + 1, idx + 1)
    end if

    ' Fetch skip times for anime
    if m.malId > 0
        fetchSkipTimes(m.malId, idx + 1)
    else
        m.controls.skipSegments = {}
    end if
end sub

' Progress counts only while watching in full screen; the small preview does not move it.
sub saveResume(at as Integer)
    if m.currentEp < 0 then return
    m.lastSave = at
    Grid_SaveResume(m.key, m.currentSeason, m.currentEp, at)
    ' Also listed in "Continuar assistindo" (Minha Lista).
    it = m.top.item
    info = "T" + (m.currentSeason + 1).ToStr() + " EP " + (m.currentEp + 1).ToStr()
    dur = Int(m.video.duration)
    Recent_Save({ id: m.key, kind: "grid", title: To_Str(it.title), poster: To_Str(it.poster), info: info, at: at, duration: dur })
end sub

sub onPosition()
    if not m.fullscreen then return
    curPos = Int(m.video.position)
    if Abs(curPos - m.lastSave) >= 15 then saveResume(curPos)
end sub

sub onVideoState()
    s = m.video.state
    if s = "playing"
        m.videoStatus.visible = false
    else if s = "error"
        m.videoStatus.text = "Erro ao carregar o vídeo"
        m.videoStatus.visible = true
    else if s = "finished" and m.fullscreen
        Watched_Mark(m.key, m.currentSeason, m.currentEp)
        markEpWatched(m.currentEp)
        updateWatchedCount()
        eps = m.seasonData[m.currentSeason].episodes
        if eps = invalid then eps = []
        nextIdx = m.currentEp + 1
        if nextIdx < eps.Count()
            startNextCountdown(nextIdx)
        else
            m.video.control = "stop"
            exitFullscreen()
        end if
    end if
end sub

' ---------- Watched / Shuffle ----------

sub markEpWatched(idx as Integer)
    row = m.episodes.content.getChild(0)
    if row = invalid then return
    n = row.getChild(idx)
    if n = invalid then return
    if not n.doesExist("WATCHED") then n.addField("WATCHED", "string", false)
    n.WATCHED = "true"
end sub

sub updateWatchedCount()
    eps = m.seasonData[m.currentSeason].episodes
    if eps = invalid then eps = []
    total = eps.Count()
    wc = Watched_CountSeason(m.key, m.currentSeason, total)
    base = total.ToStr() + " episódio(s)"
    if wc > 0 then base = base + "   |   ✓ " + wc.ToStr() + " assistido(s)"
    if m.resumeNote <> "" then base = base + "   |   " + m.resumeNote
    m.epLabel.text = base
end sub

sub shuffleEpisode()
    eps = m.seasonData[m.currentSeason].episodes
    if eps = invalid or eps.Count() = 0 then return
    idx = Rnd(eps.Count()) - 1
    playEpisode(idx, 0)
    m.episodes.jumpToRowItem = [0, idx]
    enterFullscreen()
end sub

' ---------- Cinemeta ----------

sub fetchCinemeta(imdb as String)
    m.cinemetaTask = CreateObject("roSGNode", "CinemetaTask")
    m.cinemetaTask.imdbId = imdb
    m.cinemetaTask.kind = "series"
    m.cinemetaTask.observeField("result", "onCinemetaLoaded")
    m.cinemetaTask.control = "run"
end sub

sub onCinemetaLoaded()
    if m.cinemetaTask = invalid then return
    r = m.cinemetaTask.result
    m.cinemetaTask = invalid
    if r = invalid or r.Count() = 0 then return

    m.cinemetaEps = r.episodes
    if m.cinemetaEps = invalid then m.cinemetaEps = {}

    ' Show metadata line
    parts = []
    if r.rating <> "" then parts.Push("★ " + r.rating)
    if r.genres <> "" then parts.Push(r.genres)
    if r.runtime <> "" then parts.Push(r.runtime)
    if r.year <> "" then parts.Push(r.year)
    if parts.Count() > 0
        m.metaLbl.text = parts.Join("   |   ")
        m.metaLbl.visible = true
    end if

    ' Set background image
    if r.background <> ""
        m.posterBg.uri = r.background
        m.posterBg.opacity = 0.15
    end if

    ' Enrich current episode label
    enrichCurrentEpLabel()
end sub

sub enrichCurrentEpLabel()
    if m.currentEp < 0 or m.cinemetaEps.Count() = 0 then return
    key = (m.currentSeason + 1).ToStr() + ":" + (m.currentEp + 1).ToStr()
    epMeta = m.cinemetaEps[key]
    if epMeta <> invalid and epMeta.name <> ""
        info = m.top.item.title + "  |  " + To_Str(m.seasonData[m.currentSeason].title) + " - EP " + (m.currentEp + 1).ToStr() + ": " + epMeta.name
        m.controls.episodeInfo = info
    end if
end sub

' ---------- AniSkip ----------

sub fetchSkipTimes(mal as Integer, ep as Integer)
    m.skipTask = CreateObject("roSGNode", "AniSkipTask")
    m.skipTask.malId = mal
    m.skipTask.episode = ep
    m.skipTask.observeField("result", "onSkipTimesLoaded")
    m.skipTask.control = "run"
end sub

sub onSkipTimesLoaded()
    if m.skipTask = invalid then return
    m.controls.skipSegments = m.skipTask.result
    m.skipTask = invalid
end sub

sub onClosing()
    m.nextTimer.control = "stop"
    if m.fullscreen and m.video.state <> "finished" then saveResume(Int(m.video.position))
    m.video.control = "stop"
end sub

' ---------- Fullscreen ----------

sub enterFullscreen()
    m.fullscreen = true
    m.video.translation = [0, 0]
    m.video.width = 1920
    m.video.height = 1080
    m.videoStatus.translation = [0, 520]
    m.videoStatus.width = 1920
    hideUI(true)
    m.controls.active = true
    m.controls.setFocus(true)
end sub

sub exitFullscreen()
    ' A finished episode keeps the position saved before (or the next episode's 0).
    if m.video.state <> "finished" then saveResume(Int(m.video.position))
    m.fullscreen = false
    m.controls.active = false
    m.video.translation = [610, 100]
    m.video.width = 1230
    m.video.height = 740
    m.videoStatus.translation = [610, 450]
    m.videoStatus.width = 1230
    hideUI(false)
    setFocusArea("episodes")
end sub

sub hideUI(hide as Boolean)
    vis = not hide
    m.backLabel.visible = vis
    m.headerTitle.visible = vis
    m.poster.visible = vis
    m.posterBg.visible = vis
    m.previewBg.visible = vis
    m.previewRing.visible = vis
    m.fullscreenHint.visible = false
    m.row2.visible = vis
    m.episodes.visible = vis
end sub

' ---------- Next episode ----------

' 10 s countdown over the last frame; OK plays now, Back cancels.
sub startNextCountdown(idx as Integer)
    m.nextIdx = idx
    m.nextLeft = 10
    m.nextTitle.text = "Próximo: EP " + (idx + 1).ToStr()
    drawNextCount()
    m.nextBox.visible = true
    ' The countdown takes the keys; the media bar would only get in the way.
    m.controls.active = false
    m.keySink.setFocus(true)
    m.nextTimer.control = "start"
end sub

sub drawNextCount()
    m.nextCount.text = "Começa em " + m.nextLeft.ToStr() + " s"
end sub

sub onNextTick()
    m.nextLeft--
    if m.nextLeft <= 0
        playNext()
    else
        drawNextCount()
    end if
end sub

sub stopNextCountdown()
    m.nextTimer.control = "stop"
    m.nextBox.visible = false
    m.nextIdx = -1
end sub

sub playNext()
    idx = m.nextIdx
    stopNextCountdown()
    playEpisode(idx, 0)
    saveResume(0)
    m.episodes.jumpToRowItem = [0, idx]
    m.controls.active = true
    m.controls.setFocus(true)
end sub

' Back on the countdown: leave full screen, the next episode is where the series resumes.
sub cancelNext()
    idx = m.nextIdx
    stopNextCountdown()
    m.currentEp = idx
    saveResume(0)
    m.episodes.jumpToRowItem = [0, idx]
    exitFullscreen()
end sub

' ---------- Controls callbacks ----------

sub onCtrlNextEpisode()
    eps = m.seasonData[m.currentSeason].episodes
    if eps = invalid then eps = []
    nextIdx = m.currentEp + 1
    if nextIdx < eps.Count()
        playEpisode(nextIdx, 0)
        saveResume(0)
        m.episodes.jumpToRowItem = [0, nextIdx]
    end if
end sub

sub onCtrlRestart()
    if m.currentEp >= 0
        playEpisode(m.currentEp, 0)
        saveResume(0)
    end if
end sub

' ---------- Keys ----------

sub goBack()
    m.top.navigate = { to: "back" }
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if m.fullscreen
        if m.nextIdx >= 0
            if key = "OK" or key = "play"
                playNext()
            else if key = "back"
                cancelNext()
            end if
            return true
        end if
        if key = "back"
            exitFullscreen()
            return true
        end if
        return false
    end if

    area = m.focusArea
    if area = "pop"
        if key = "back" or key = "left" or key = "right"
            closeSeasons()
        end if
        return true
    end if

    if key = "back"
        goBack()
        return true
    end if

    if area = "back"
        if key = "OK"
            goBack()
        else if key = "down" or key = "right"
            setFocusArea("preview")
        end if
        return true
    else if area = "preview"
        if key = "OK"
            enterFullscreen()
        else if key = "up" or key = "left"
            setFocusArea("back")
        else if key = "down"
            setFocusArea("combo")
        end if
        return true
    else if area = "combo"
        if key = "OK"
            openSeasons()
        else if key = "right"
            setFocusArea("shuffle")
        else if key = "up"
            setFocusArea("preview")
        else if key = "down"
            setFocusArea("episodes")
        end if
        return true
    else if area = "shuffle"
        if key = "OK"
            shuffleEpisode()
        else if key = "left"
            setFocusArea("combo")
        else if key = "right"
            setFocusArea("fav")
        else if key = "up"
            setFocusArea("preview")
        else if key = "down"
            setFocusArea("episodes")
        end if
        return true
    else if area = "fav"
        if key = "OK"
            toggleFav()
        else if key = "left"
            setFocusArea("shuffle")
        else if key = "up"
            setFocusArea("preview")
        else if key = "down"
            setFocusArea("episodes")
        end if
        return true
    else if area = "episodes"
        if key = "up"
            setFocusArea("combo")
            return true
        end if
    end if
    return false
end function

sub init()
    m.backdrop = m.top.findNode("backdrop")
    m.poster = m.top.findNode("poster")
    m.title = m.top.findNode("title")
    m.summary = m.top.findNode("summary")
    m.metaLbl = m.top.findNode("metaLbl")
    m.status = m.top.findNode("status")
    m.hint = m.top.findNode("hint")
    m.btn1 = m.top.findNode("btn1")
    m.lbl0 = m.top.findNode("lbl0")
    m.btn = 0
    m.resumeAt = 0
    m.cinemetaTask = invalid
    m.top.observeField("resumed", "onResumed")
end sub

sub onItem()
    it = m.top.item
    m.title.text = To_Str(it.title)
    m.summary.text = To_Str(it.summary)
    m.poster.uri = To_Str(it.poster)
    m.backdrop.uri = To_Str(it.poster)
    refreshResume()

    imdb = To_Str(it.imdb)
    if imdb <> "" then fetchCinemeta(imdb)
end sub

sub fetchCinemeta(imdb as String)
    m.cinemetaTask = CreateObject("roSGNode", "CinemetaTask")
    m.cinemetaTask.imdbId = imdb
    m.cinemetaTask.kind = "movie"
    m.cinemetaTask.observeField("result", "onCinemetaLoaded")
    m.cinemetaTask.control = "run"
end sub

sub onCinemetaLoaded()
    if m.cinemetaTask = invalid then return
    r = m.cinemetaTask.result
    m.cinemetaTask = invalid
    if r = invalid or r.Count() = 0 then return

    parts = []
    if r.rating <> "" then parts.Push("★ " + r.rating)
    if r.runtime <> "" then parts.Push(r.runtime)
    if r.genres <> "" then parts.Push(r.genres)
    if r.year <> "" then parts.Push(r.year)
    if parts.Count() > 0
        m.metaLbl.text = parts.Join("   |   ")
        m.metaLbl.visible = true
        m.summary.translation = [670, 400]
    end if

    if r.cast <> ""
        castLine = "Elenco: " + r.cast
        if r.director <> "" then castLine = castLine + "   |   Dir: " + r.director
        cur = m.summary.text
        if cur <> "" then m.summary.text = cur + Chr(10) + Chr(10) + castLine
    end if

    if r.background <> ""
        m.backdrop.uri = r.background
        m.backdrop.opacity = 0.25
    end if
end sub

' Back from the player: the saved position changed.
sub onResumed()
    refreshResume()
end sub

function recentId() as String
    return "movie:" + To_Str(m.top.item.id)
end function

sub refreshResume()
    m.resumeAt = 0
    rec = Recent_Find(recentId())
    if rec <> invalid and To_Int(rec.at) > 30 then m.resumeAt = To_Int(rec.at)
    m.btn = 0
    if m.resumeAt > 0
        m.lbl0.text = "Continuar de " + Fmt_Time(m.resumeAt)
        m.btn1.visible = true
        m.hint.text = "OK assiste   |   Esquerda/Direita escolhe   |   Voltar fecha"
    else
        m.lbl0.text = "Assistir"
        m.btn1.visible = false
        m.hint.text = "OK assiste   |   Voltar fecha"
    end if
    drawButtons()
end sub

sub drawButtons()
    for i = 0 to 1
        sel = (i = m.btn)
        m.top.findNode("ring" + i.ToStr()).visible = sel
        bg = m.top.findNode("bg" + i.ToStr())
        lbl = m.top.findNode("lbl" + i.ToStr())
        if sel
            bg.color = "0xFFFFFFFF"
            lbl.color = "0x0B0F1AFF"
        else
            bg.color = "0x2A3245FF"
            lbl.color = "0xFFFFFFFF"
        end if
    end for
    if m.btn = 0
        m.top.findNode("icon0").blendColor = "0x0B0F1AFF"
    else
        m.top.findNode("icon0").blendColor = "0xFFFFFFFF"
    end if
end sub

' Full screen player; PlayerView gives the remote pause / resume and hold-to-seek
' and saves the position under "movie:<id>" for "Continuar assistindo".
sub watch(fromStart as Boolean)
    it = m.top.item
    url = To_Str(it.url)
    saimoId = To_Str(it.saimoId)

    if url = "" and saimoId <> ""
        m.status.text = "Carregando stream..."
        m.watchFromStart = fromStart
        task = CreateObject("roSGNode", "SaimoTask")
        task.seriesId = saimoId
        task.tipo = "filmes"
        task.observeField("result", "onSaimoMovieResult")
        task.control = "run"
        m.saimoTask = task
        return
    end if

    if url = ""
        m.status.text = "Este filme ainda não tem URL configurada."
        return
    end if
    playMovie(url, fromStart)
end sub

sub onSaimoMovieResult()
    res = m.saimoTask.result
    m.saimoTask = invalid
    if res = invalid or not Is_True(res.ok) or To_Str(res.url) = ""
        m.status.text = "Stream indisponível."
        return
    end if
    m.status.text = ""
    playMovie(To_Str(res.url), m.watchFromStart)
end sub

sub playMovie(url as String, fromStart as Boolean)
    it = m.top.item
    start = m.resumeAt
    if fromStart then start = 0
    m.top.navigate = {
        to: "play", urls: [url], title: To_Str(it.title), start: start,
        id: recentId(), itemTitle: To_Str(it.title), poster: To_Str(it.poster),
        imdb: To_Str(it.imdb),
        extra: { kind: "movie", movieId: To_Str(it.id), url: url, summary: To_Str(it.summary), imdb: To_Str(it.imdb) }
    }
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "OK" or key = "play"
        watch(m.btn = 1)
        return true
    end if
    if (key = "left" or key = "right") and m.btn1.visible
        m.btn = 0
        if key = "right" then m.btn = 1
        drawButtons()
        return true
    end if
    ' Back bubbles to MainScene, which closes this screen.
    return key <> "back"
end function

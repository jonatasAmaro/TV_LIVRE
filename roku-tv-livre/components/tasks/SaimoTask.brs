sub init()
    m.top.functionName = "execute"
end sub

sub execute()
    seriesId = m.top.seriesId
    season = m.top.season
    episode = m.top.episode
    tipo = m.top.tipo
    fonte = m.top.fonte

    if seriesId = "" or seriesId = invalid
        m.top.result = { ok: false, url: "", format: "" }
        return
    end if

    workerBase = "https://tv-livre-catalog.jonatas-amaro2.workers.dev"
    url = workerBase + "/saimo?id=" + seriesId + "&tipo=" + tipo
    if tipo <> "filmes"
        url = url + "&season=" + season.ToStr()
        url = url + "&episode=" + episode.ToStr()
    end if
    if fonte <> "" and fonte <> invalid
        url = url + "&fonte=" + fonte
    end if

    data = Http_GetJson(url)
    if data = invalid or not Is_True(data.ok)
        m.top.result = { ok: false, url: "", format: "" }
        return
    end if

    m.top.result = {
        ok: true,
        url: To_Str(data.url),
        format: To_Str(data.format)
    }
end sub

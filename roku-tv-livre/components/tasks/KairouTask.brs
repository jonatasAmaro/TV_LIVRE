sub init()
    m.top.functionName = "execute"
end sub

sub execute()
    tmdb = m.top.tmdbId
    season = m.top.season
    episode = m.top.episode
    title = m.top.title

    if tmdb = "" or tmdb = invalid
        m.top.result = { ok: false, url: "", format: "" }
        return
    end if

    workerBase = "https://tv-livre-catalog.jonatas-amaro2.workers.dev"
    url = workerBase + "/kairou?tmdbId=" + tmdb
    url = url + "&season=" + season.ToStr()
    url = url + "&episode=" + episode.ToStr()
    if title <> ""
        xfer = CreateObject("roUrlTransfer")
        url = url + "&title=" + xfer.Escape(title)
    end if

    data = Http_GetJson(url)
    if data = invalid or not Is_True(data.ok)
        m.top.result = { ok: false, url: "", format: "" }
        return
    end if

    m.top.result = {
        ok: true,
        url: To_Str(data.url),
        format: To_Str(data.format),
        quality: To_Str(data.quality)
    }
end sub

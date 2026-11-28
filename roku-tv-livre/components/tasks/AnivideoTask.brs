sub init()
    m.top.functionName = "execute"
end sub

sub execute()
    slug = m.top.slug
    episode = m.top.episode

    if slug = "" or slug = invalid
        m.top.result = { ok: false, url: "", format: "" }
        return
    end if

    workerBase = "https://tv-livre-catalog.jonatas-amaro2.workers.dev"
    url = workerBase + "/anivideo?slug=" + slug + "&episode=" + episode.ToStr()

    m.top.result = {
        ok: true,
        url: url,
        format: "hls"
    }
end sub

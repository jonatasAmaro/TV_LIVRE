sub init()
    m.top.functionName = "execute"
end sub

sub execute()
    tmdb = m.top.tmdb
    season = m.top.season
    episode = m.top.episode

    if tmdb = "" or tmdb = invalid
        m.top.result = { ok: false, url: "", format: "" }
        return
    end if

    workerBase = "https://tv-livre-catalog.jonatas-amaro2.workers.dev"
    workerUrl = workerBase + "/meusanimes?tmdb=" + tmdb + "&season=" + season.ToStr() + "&episode=" + episode.ToStr()

    xfer = CreateObject("roUrlTransfer")
    xfer.SetUrl(workerUrl)
    xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    xfer.InitClientCertificates()
    body = xfer.GetToString()

    if body = "" or body = invalid
        m.top.result = { ok: false, url: "", format: "" }
        return
    end if

    json = ParseJson(body)
    if json = invalid
        m.top.result = { ok: false, url: "", format: "" }
        return
    end if
    bloggerUrl = json.bloggerUrl
    if bloggerUrl = invalid or bloggerUrl = ""
        m.top.result = { ok: false, url: "", format: "" }
        return
    end if

    blogXfer = CreateObject("roUrlTransfer")
    blogXfer.SetUrl(bloggerUrl)
    blogXfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    blogXfer.InitClientCertificates()
    blogXfer.AddHeader("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
    html = blogXfer.GetToString()

    if html = "" or html = invalid
        m.top.result = { ok: false, url: "", format: "" }
        return
    end if

    videoUrl = ExtractGV(html, "22")
    if videoUrl = ""
        videoUrl = ExtractGV(html, "18")
    end if

    if videoUrl = ""
        m.top.result = { ok: false, url: "", format: "" }
        return
    end if

    m.top.result = { ok: true, url: videoUrl, format: "mp4" }
end sub

function ExtractGV(html as String, itag as String) as String
    bs = Chr(92)
    ' Blogger embeds URLs JSON-escaped twice (\\u003d)
    html = html.Replace(bs + bs, bs)
    uEq = bs + "u003d"
    uAmp = bs + "u0026"

    marker1 = "itag" + uEq + itag
    marker2 = "itag=" + itag

    idx = Instr(1, html, marker1)
    if idx = 0 then idx = Instr(1, html, marker2)
    if idx = 0 then return ""

    urlStart = 0
    limit = idx - 600
    if limit < 1 then limit = 1
    for i = idx - 1 to limit step -1
        if Mid(html, i, 8) = "https://"
            urlStart = i
            exit for
        end if
    end for
    if urlStart = 0 then return ""

    q = Chr(34)
    urlEnd = idx + Len(marker1)
    htmlLen = Len(html)
    found = false
    for i = urlEnd to htmlLen
        c = Mid(html, i, 1)
        if c = q or c = "'" or c = " " or c = "<" or c = ">"
            urlEnd = i
            found = true
            exit for
        end if
        if c = Chr(10) or c = Chr(13)
            urlEnd = i
            found = true
            exit for
        end if
        if c = "&" and i + 5 <= htmlLen
            if Mid(html, i, 6) = "&quot;"
                urlEnd = i
                found = true
                exit for
            end if
        end if
        if c = bs and i + 1 <= htmlLen
            nx = Mid(html, i + 1, 1)
            if nx = q or nx = "&"
                urlEnd = i
                found = true
                exit for
            end if
        end if
    end for
    if not found then urlEnd = htmlLen + 1

    url = Mid(html, urlStart, urlEnd - urlStart)
    url = url.Replace(uEq, "=")
    url = url.Replace(uAmp, "&")
    url = url.Replace(bs + "/", "/")
    return url
end function

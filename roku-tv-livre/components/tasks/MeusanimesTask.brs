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

    json = ParseJSON(body)
    if json = invalid or json.ok <> true or json.bloggerUrl = invalid or json.bloggerUrl = ""
        m.top.result = { ok: false, url: "", format: "" }
        return
    end if

    blogXfer = CreateObject("roUrlTransfer")
    blogXfer.SetUrl(json.bloggerUrl)
    blogXfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    blogXfer.InitClientCertificates()
    blogXfer.AddHeader("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
    html = blogXfer.GetToString()

    if html = "" or html = invalid
        m.top.result = { ok: false, url: "", format: "" }
        return
    end if

    videoUrl = extractGooglevideo(html, "22")
    if videoUrl = ""
        videoUrl = extractGooglevideo(html, "18")
    end if

    if videoUrl = ""
        m.top.result = { ok: false, url: "", format: "" }
        return
    end if

    m.top.result = { ok: true, url: videoUrl, format: "mp4" }
end sub

function extractGooglevideo(html as String, itag as String) as String
    uEq = Chr(92) + "u003d"
    uAmp = Chr(92) + "u0026"
    uSlash = Chr(92) + "/"

    itagMarker = "itag" + uEq + itag
    pos = Instr(1, html, itagMarker)
    if pos = 0
        itagMarker = "itag=" + itag
        pos = Instr(1, html, itagMarker)
    end if
    if pos = 0 then return ""

    urlStart = 0
    s = pos
    while s > 8
        s = s - 1
        if Mid(html, s, 8) = "https://"
            urlStart = s
            exit while
        end if
        if s < pos - 600 then exit while
    end while
    if urlStart = 0 then return ""

    urlEnd = pos + Len(itagMarker)
    htmlLen = Len(html)
    while urlEnd <= htmlLen
        c = Mid(html, urlEnd, 1)
        if c = Chr(34) or c = "'" or c = " " or c = Chr(10) or c = Chr(13) or c = "<" or c = ">"
            exit while
        end if
        if c = "&" and urlEnd + 5 <= htmlLen and Mid(html, urlEnd, 6) = "&quot;"
            exit while
        end if
        if c = Chr(92) and urlEnd + 1 <= htmlLen and Mid(html, urlEnd + 1, 1) = Chr(34)
            exit while
        end if
        urlEnd = urlEnd + 1
    end while

    url = Mid(html, urlStart, urlEnd - urlStart)
    url = url.Replace(uEq, "=")
    url = url.Replace(uAmp, "&")
    url = url.Replace(uSlash, "/")
    return url
end function

' Opens YouTube content in the official YouTube channel (id 837) through the
' device's own External Control Protocol, so playback, ads and login stay in YouTube.
sub init()
    m.top.functionName = "execute"
end sub

sub execute()
    if m.top.mode = "launch"
        m.top.result = { launched: YouTube_Launch(m.top.videoId, m.top.mediaType) }
        return
    end if
    if m.top.mode = "app"
        m.top.result = { launched: Ecp_Launch(m.top.appId, "") }
        return
    end if
    if m.top.mode = "info"
        infos = {}
        for each ch in m.top.channels
            cid = To_Str(ch.channelId)
            liveId = YouTube_LiveVideoId(cid)
            if liveId <> ""
                infos[To_Str(ch.id)] = { videoId: liveId, live: true }
            else
                infos[To_Str(ch.id)] = { videoId: YouTube_LatestVideo(cid).id, live: false }
            end if
        end for
        m.top.result = { infos: infos }
        return
    end if

    res = { live: false, launched: false, latestId: "", latestTitle: "", nextTitle: "" }
    cid = m.top.channelId
    liveId = YouTube_LiveVideoId(cid)
    if liveId <> ""
        res.live = true
        res.launched = YouTube_Launch(liveId, "live")
    else
        latest = YouTube_LatestVideo(cid)
        res.latestId = latest.id
        res.latestTitle = latest.title
        res.nextTitle = latest.nextTitle
    end if
    m.top.result = res
end sub

function YouTube_Fetch(url as String) as String
    xfer = CreateObject("roUrlTransfer")
    xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    xfer.InitClientCertificates()
    xfer.EnableEncodings(true)
    xfer.AddHeader("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36")
    xfer.AddHeader("Accept-Language", "pt-BR,pt;q=0.9")
    xfer.SetUrl(url)
    body = xfer.GetToString()
    if body = invalid then return ""
    return body
end function

' The channel's /live page points its canonical link at the current broadcast.
function YouTube_LiveVideoId(channelId as String) as String
    html = YouTube_Fetch("https://www.youtube.com/channel/" + channelId + "/live")
    if Instr(1, html, """isLiveNow"":true") = 0 then return ""
    m1 = CreateObject("roRegex", "<link rel=""canonical"" href=""https://www\.youtube\.com/watch\?v=([\w-]{11})""", "").Match(html)
    if m1.Count() < 2 then return ""
    return m1[1]
end function

' Most recent watchable broadcast from the channel's "Ao vivo" tab; channels that
' never stream live fall back to the newest upload in the "Vídeos" tab.
function YouTube_LatestVideo(channelId as String) as Object
    base = "https://www.youtube.com/channel/" + channelId
    out = YouTube_FirstEntry(base + "/streams")
    if out.id = ""
        uploads = YouTube_FirstEntry(base + "/videos")
        out.id = uploads.id
        out.title = uploads.title
    end if
    return out
end function

' Tab pages list entries newest first. Scheduled broadcasts come before finished
' ones, so the last scheduled entry is the next to air and the first unscheduled
' entry is the most recent one that can be watched.
function YouTube_FirstEntry(url as String) as Object
    out = { id: "", title: "", nextTitle: "" }
    html = YouTube_Fetch(url)
    idRe = CreateObject("roRegex", """contentId"":""([\w-]{11})""", "")
    titleRe = CreateObject("roRegex", """title"":\{""content"":""([^""]+)""", "")
    parts = html.Split("""lockupViewModel"":{")
    for i = 1 to parts.Count() - 1
        p = parts[i]
        idm = idRe.Match(p)
        tm = titleRe.Match(p)
        title = ""
        if tm.Count() > 1 then title = YouTube_Unescape(tm[1])
        if Instr(1, p, "Programado") > 0 or Instr(1, p, "Scheduled") > 0
            out.nextTitle = title
        else if idm.Count() > 1
            out.id = idm[1]
            out.title = title
            exit for
        end if
    end for
    return out
end function

function YouTube_Unescape(s as String) as String
    s = s.Replace("&", "&").Replace("\" + Chr(34), Chr(34)).Replace("&amp;", "&").Replace("&quot;", Chr(34)).Replace("&#39;", "'")
    return s
end function

function YouTube_Launch(videoId as String, mediaType as String) as Boolean
    if videoId = "" then return false
    return Ecp_Launch("837", "contentId=" + videoId + "&mediaType=" + mediaType)
end function

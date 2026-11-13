sub init()
    m.top.functionName = "execute"
end sub

sub execute()
    pageUrl = m.top.pageUrl
    if pageUrl = "" or pageUrl = invalid
        m.top.result = { ok: false, url: "", format: "" }
        return
    end if

    workerBase = "https://tv-livre-catalog.jonatas-amaro2.workers.dev"
    ut = CreateObject("roUrlTransfer")
    endpoint = workerBase + "/tokyvideo?url=" + ut.Escape(pageUrl)

    data = Http_GetJson(endpoint)
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

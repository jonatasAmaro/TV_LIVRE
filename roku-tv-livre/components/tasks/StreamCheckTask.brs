sub init()
    m.top.functionName = "run"
end sub

sub run()
    channels = m.top.channels
    if channels = invalid or channels.Count() = 0
        m.top.result = { ok: false, total: 0, online: 0, offline: 0, results: [] }
        return
    end if

    total = channels.Count()
    results = []
    online = 0
    offline = 0
    port = CreateObject("roMessagePort")

    for i = 0 to total - 1
        ch = channels[i]
        url = To_Str(ch.url)
        title = To_Str(ch.title)
        id = To_Str(ch.id)

        if url = ""
            results.Push({ id: id, title: title, status: "offline", code: 0 })
            offline = offline + 1
        else
            status = checkUrl(url, port)
            results.Push({ id: id, title: title, status: status.status, code: status.code })
            if status.status = "online"
                online = online + 1
            else
                offline = offline + 1
            end if
        end if

        m.top.progress = { checked: i + 1, total: total, current: title }
    end for

    m.top.result = { ok: true, total: total, online: online, offline: offline, results: results }
end sub

function checkUrl(url as String, port as Object) as Object
    xfer = CreateObject("roUrlTransfer")
    xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    xfer.InitClientCertificates()
    xfer.EnableEncodings(true)
    xfer.AddHeader("User-Agent", "Mozilla/5.0 (Roku; StreamCheck)")
    xfer.SetUrl(url)
    xfer.SetPort(port)
    xfer.EnableFreshConnection(true)

    if not xfer.AsyncHead()
        result = checkUrlFallback(url, port)
        return result
    end if

    msg = wait(15000, port)
    if msg = invalid
        xfer.AsyncCancel()
        result = checkUrlFallback(url, port)
        return result
    end if

    if type(msg) = "roUrlEvent"
        code = msg.GetResponseCode()
        if code >= 200 and code < 400
            return { status: "online", code: code }
        end if
        if code = 405 or code = 403
            result = checkUrlFallback(url, port)
            return result
        end if
        return { status: "offline", code: code }
    end if

    xfer.AsyncCancel()
    return { status: "offline", code: 0 }
end function

function checkUrlFallback(url as String, port as Object) as Object
    xfer = CreateObject("roUrlTransfer")
    xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    xfer.InitClientCertificates()
    xfer.EnableEncodings(true)
    xfer.AddHeader("User-Agent", "Mozilla/5.0 (Roku; StreamCheck)")
    xfer.AddHeader("Range", "bytes=0-1023")
    xfer.SetUrl(url)
    xfer.SetPort(port)
    xfer.EnableFreshConnection(true)

    if not xfer.AsyncGetToString()
        return { status: "offline", code: 0 }
    end if

    msg = wait(15000, port)
    if msg = invalid
        xfer.AsyncCancel()
        return { status: "timeout", code: 0 }
    end if

    if type(msg) = "roUrlEvent"
        code = msg.GetResponseCode()
        if code >= 200 and code < 400
            return { status: "online", code: code }
        else
            return { status: "offline", code: code }
        end if
    end if

    xfer.AsyncCancel()
    return { status: "offline", code: 0 }
end function

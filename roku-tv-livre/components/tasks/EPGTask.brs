sub init()
    m.top.functionName = "execute"
end sub

sub execute()
    url = m.top.epgUrl
    if url = "" then url = "https://raw.githubusercontent.com/limaalef/BrazilTVEPG/main/epg.xml"

    print "[epg] fetching "; url
    xfer = Http_NewTransfer(url)
    body = xfer.GetToString()
    if body = invalid or body = ""
        print "[epg] fetch failed"
        m.top.result = { ok: false, guide: {} }
        return
    end if

    guide = ParseEPG(body)
    print "[epg] parsed "; guide.Count(); " channels"
    m.top.result = { ok: true, guide: guide }
end sub

' Parses XMLTV into { "channel name (lowercase)": [{ start, stop, title, desc }] }.
' Uses channel display-name as key and programme title/desc as values.
function ParseEPG(xml as String) as Object
    guide = {}
    doc = CreateObject("roXMLElement")
    if not doc.Parse(xml)
        print "[epg] XML parse error"
        return guide
    end if

    ' Build channel id -> lowercase display-name map.
    names = {}
    for each ch in doc.GetNamedElements("channel")
        id = ch.GetAttributes().id
        dn = ch.GetNamedElements("display-name")
        if dn.Count() > 0 and id <> invalid
            names[id] = LCase(dn[0].GetText().Trim())
        end if
    end for

    now = CreateObject("roDateTime").AsSeconds()
    window = 86400 ' keep programmes within 24h

    for each p in doc.GetNamedElements("programme")
        attr = p.GetAttributes()
        chId = attr.channel
        startStr = attr.start
        stopStr = attr.stop
        if chId = invalid or startStr = invalid then continue for

        startSec = EpgTimeToSeconds(startStr)
        stopSec = 0
        if stopStr <> invalid then stopSec = EpgTimeToSeconds(stopStr)

        ' Only keep current window.
        if stopSec > 0 and stopSec < now - 3600 then continue for
        if startSec > now + window then continue for

        chName = names[chId]
        if chName = invalid then chName = LCase(chId)

        titleEl = p.GetNamedElements("title")
        descEl = p.GetNamedElements("desc")
        entry = {
            start: startSec,
            stop: stopSec,
            title: "",
            desc: ""
        }
        if titleEl.Count() > 0 then entry.title = titleEl[0].GetText()
        if descEl.Count() > 0 then entry.desc = descEl[0].GetText()

        if guide[chName] = invalid then guide[chName] = []
        guide[chName].Push(entry)
    end for

    ' Sort each channel's programmes by start time.
    for each key in guide.Keys()
        guide[key].SortBy("start")
    end for

    return guide
end function

' Converts XMLTV timestamp "20261027210419 -0300" to epoch seconds.
function EpgTimeToSeconds(ts as String) as Integer
    ' Strip timezone offset for now, parse as UTC then adjust.
    parts = ts.Split(" ")
    s = parts[0]
    if s.Len() < 14 then return 0

    dt = CreateObject("roDateTime")
    year = Left(s, 4).ToInt()
    month = Mid(s, 5, 2).ToInt()
    day = Mid(s, 7, 2).ToInt()
    hour = Mid(s, 9, 2).ToInt()
    minute = Mid(s, 11, 2).ToInt()
    sec = Mid(s, 13, 2).ToInt()

    ' Build ISO string for roDateTime.
    iso = year.ToStr() + "-" + Pad2(month) + "-" + Pad2(day) + "T" + Pad2(hour) + ":" + Pad2(minute) + ":" + Pad2(sec) + "Z"
    dt.FromISO8601String(iso)
    epoch = dt.AsSeconds()

    ' Apply timezone offset.
    if parts.Count() > 1
        tz = parts[1]
        sign = 1
        if Left(tz, 1) = "-" then sign = -1
        if Left(tz, 1) = "+" or Left(tz, 1) = "-" then tz = Mid(tz, 2)
        if tz.Len() >= 4
            tzH = Left(tz, 2).ToInt()
            tzM = Mid(tz, 3, 2).ToInt()
            epoch = epoch - sign * (tzH * 3600 + tzM * 60)
        end if
    end if

    return epoch
end function

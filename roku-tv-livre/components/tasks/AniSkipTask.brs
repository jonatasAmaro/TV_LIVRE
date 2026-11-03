' Fetches skip-times from AniSkip (opening / ending markers).
' Input: malId, episode
' Output: result = { op: { start, end }, ed: { start, end } } (invalid segments omitted)
sub init()
    m.top.functionName = "execute"
end sub

sub execute()
    mal = m.top.malId
    ep = m.top.episode
    if mal = 0 or ep = 0
        m.top.result = {}
        return
    end if

    url = "https://api.aniskip.com/v2/skip-times/" + mal.ToStr() + "/" + ep.ToStr() + "?types[]=op&types[]=ed&episodeLength=0"
    data = Http_GetJson(url)
    out = {}
    if data = invalid or data.results = invalid
        m.top.result = out
        return
    end if

    for each r in data.results
        t = To_Str(r.skipType)
        iv = r.interval
        if iv = invalid then continue for
        seg = { start: Int(iv.startTime), end: Int(iv.endTime) }
        if t = "op" then out.op = seg
        if t = "ed" then out.ed = seg
    end for

    m.top.result = out
end sub

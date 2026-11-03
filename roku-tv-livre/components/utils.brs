' ---------- HTTP ----------

function Http_NewTransfer(url as String) as Object
    xfer = CreateObject("roUrlTransfer")
    xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    xfer.InitClientCertificates()
    xfer.EnableEncodings(true)
    xfer.RetainBodyOnError(true)
    xfer.AddHeader("User-Agent", "TVLivre-Roku/1.0")
    xfer.SetUrl(url)
    return xfer
end function

function Http_GetJson(url as String) as Dynamic
    body = Http_NewTransfer(url).GetToString()
    if body = invalid or body = "" then return invalid
    return ParseJson(body)
end function

function Http_PostJson(url as String, payload as Object) as Dynamic
    port = CreateObject("roMessagePort")
    xfer = Http_NewTransfer(url)
    xfer.SetPort(port)
    xfer.SetRequest("POST")
    xfer.AddHeader("Content-Type", "application/json")
    xfer.AddHeader("Accept", "application/json")
    if not xfer.AsyncPostFromString(FormatJson(payload)) then return invalid
    msg = wait(20000, port)
    if type(msg) = "roUrlEvent"
        if msg.GetResponseCode() = 200 then return ParseJson(msg.GetString())
        return invalid
    end if
    xfer.AsyncCancel()
    return invalid
end function

' ---------- Values ----------

function To_Str(v as Dynamic) as String
    if v = invalid then return ""
    if type(v) = "roArray"
        if v.Count() = 0 then return ""
        return To_Str(v[0])
    end if
    if GetInterface(v, "ifToStr") <> invalid then return v.ToStr()
    return ""
end function

function Is_True(v as Dynamic) as Boolean
    t = type(v)
    if t = "Boolean" or t = "roBoolean" then return v
    return false
end function

function To_Int(v as Dynamic) as Integer
    t = type(v)
    if t = "Integer" or t = "roInt" or t = "LongInteger" or t = "roLongInteger" then return v
    if t = "Float" or t = "roFloat" or t = "Double" or t = "roDouble" then return Int(v)
    if t = "String" or t = "roString" then return v.ToInt()
    return 0
end function

function Strip_Html(v as Dynamic) as String
    if v = invalid then return ""
    s = v
    if type(v) = "roArray" then s = v.Join(" ")
    if GetInterface(s, "ifString") = invalid then return ""
    s = CreateObject("roRegex", "<[^>]+>", "").ReplaceAll(s, " ")
    s = s.Replace("&amp;", "&").Replace("&quot;", Chr(34)).Replace("&#39;", "'").Replace("&nbsp;", " ")
    s = CreateObject("roRegex", "\s+", "").ReplaceAll(s, " ")
    return s.Trim()
end function

function Arr_Reverse(a as Object) as Object
    out = []
    for i = a.Count() - 1 to 0 step -1
        out.Push(a[i])
    end for
    return out
end function

function Version_Compare(a as String, b as String) as Integer
    pa = a.Split(".")
    pb = b.Split(".")
    for i = 0 to 2
        x = 0
        y = 0
        if i < pa.Count() then x = pa[i].ToInt()
        if i < pb.Count() then y = pb[i].ToInt()
        if x > y then return 1
        if x < y then return -1
    end for
    return 0
end function

' ---------- Time ----------

function Now_Seconds() as Integer
    return CreateObject("roDateTime").AsSeconds()
end function

function Pad2(n as Integer) as String
    if n < 10 then return "0" + n.ToStr()
    return n.ToStr()
end function

function Fmt_Time(seconds as Integer) as String
    h = seconds \ 3600
    mm = (seconds mod 3600) \ 60
    s = seconds mod 60
    if h > 0 then return h.ToStr() + ":" + Pad2(mm) + ":" + Pad2(s)
    return mm.ToStr() + ":" + Pad2(s)
end function

function Fmt_LocalDate(secs as Integer) as String
    dt = CreateObject("roDateTime")
    dt.FromSeconds(secs)
    dt.ToLocalTime()
    days = ["dom", "seg", "ter", "qua", "qui", "sex", "sáb"]
    return days[dt.GetDayOfWeek()] + " " + Pad2(dt.GetDayOfMonth()) + "/" + Pad2(dt.GetMonth()) + " " + Pad2(dt.GetHours()) + ":" + Pad2(dt.GetMinutes())
end function

' "Segunda, 27 de outubro" (dt already in local time).
function Fmt_LongDate(dt as Object) as String
    days = ["Domingo", "Segunda", "Terça", "Quarta", "Quinta", "Sexta", "Sábado"]
    months = ["janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto", "setembro", "outubro", "novembro", "dezembro"]
    return days[dt.GetDayOfWeek()] + ", " + dt.GetDayOfMonth().ToStr() + " de " + months[dt.GetMonth() - 1]
end function

' ---------- Config ----------

' With "catalogUrl" set in the packaged catalog, the online copy (saved by CatalogSyncTask
' in cachefs:) wins, so content changes need no deploy. Any problem falls back to the package.
function Cfg_Load() as Object
    pkg = ParseJson(ReadAsciiFile("pkg:/config/catalog.json"))
    if pkg = invalid then pkg = { sections: [] }
    if To_Str(pkg.catalogUrl) = "" then return pkg
    online = Cfg_Parse(ReadAsciiFile(CATALOG_CACHE()))
    if online = invalid then return pkg
    return online
end function

function CATALOG_CACHE() as String
    return "cachefs:/catalog.json"
end function

' A catalog is usable only with a "sections" list.
function Cfg_Parse(text as String) as Dynamic
    if text = "" then return invalid
    cfg = ParseJson(text)
    if type(cfg) <> "roAssociativeArray" or type(cfg.sections) <> "roArray" then return invalid
    return cfg
end function

' Downloads the online catalog; keeps the previous copy when the download or the JSON is bad.
' Returns "updated", "same", "off" (no catalogUrl) or "error".
function Cfg_Sync() as String
    pkg = ParseJson(ReadAsciiFile("pkg:/config/catalog.json"))
    url = ""
    if pkg <> invalid then url = To_Str(pkg.catalogUrl)
    fs = CreateObject("roFileSystem")
    if url = ""
        if fs.Exists(CATALOG_CACHE()) then fs.Delete(CATALOG_CACHE())
        return "off"
    end if
    ' Cache-buster: hosts like GitHub raw keep old copies for minutes.
    sep = "?"
    if Instr(1, url, "?") > 0 then sep = "&"
    xfer = Http_NewTransfer(url + sep + "t=" + Now_Seconds().ToStr())
    body = xfer.GetToString()
    if Cfg_Parse(body) = invalid then return "error"
    if body = ReadAsciiFile(CATALOG_CACHE()) then return "same"
    if not WriteAsciiFile(CATALOG_CACHE(), body) then return "error"
    return "updated"
end function

' ---------- Storage (registry) ----------

function Store_Get(key as String, fallback as Dynamic) as Dynamic
    sec = CreateObject("roRegistrySection", "tvlivre")
    if sec.Exists(key)
        data = ParseJson(sec.Read(key))
        if data <> invalid and data.v <> invalid then return data.v
    end if
    return fallback
end function

sub Store_Set(key as String, value as Dynamic)
    sec = CreateObject("roRegistrySection", "tvlivre")
    sec.Write(key, FormatJson({ v: value }))
    sec.Flush()
end sub

function Fav_List() as Object
    return Store_Get("favorites", [])
end function

function Fav_Has(id as String) as Boolean
    for each f in Fav_List()
        if f.id = id then return true
    end for
    return false
end function

sub Fav_Toggle(item as Object)
    out = []
    found = false
    for each f in Fav_List()
        if f.id = item.id
            found = true
        else
            out.Push(f)
        end if
    end for
    if not found then out.Unshift(item)
    Store_Set("favorites", out)
end sub

' recent = [{ id, title, poster, file, at }] (max 20, newest first)
function Recent_List() as Object
    return Store_Get("recent", [])
end function

function Recent_Find(id as String) as Dynamic
    for each r in Recent_List()
        if r.id = id then return r
    end for
    return invalid
end function

' Movies and series also go into "recent", so Minha Lista and Filmes can show
' "Continuar assistindo": kind "movie" { movieId, url, summary } or "grid" (id = Grid_Key, info).
sub Recent_Save(entry as Object)
    out = [entry]
    for each r in Recent_List()
        if r.id <> entry.id and out.Count() < 20 then out.Push(r)
    end for
    Store_Set("recent", out)
end sub

' ---------- Series cards (sections kind="grid") ----------

' Card ids repeat across sections, so the title is part of the key.
function Grid_Key(item as Object) as String
    return "grid:" + To_Str(item.id) + ":" + To_Str(item.title)
end function

function Grid_FindItem(key as String) as Dynamic
    for each s in Cfg_Load().sections
        if s.kind = "grid"
            if s.items <> invalid
                for each it in s.items
                    if Grid_Key(it) = key then return it
                end for
            end if
            if s.categories <> invalid
                for each cat in s.categories
                    if cat.items <> invalid
                        for each it in cat.items
                            if Grid_Key(it) = key then return it
                        end for
                    end if
                end for
            end if
        end if
    end for
    return invalid
end function

' gridResume = [{ key, s, e, at }] (season index, episode index, seconds), max 30, newest first
function Grid_Resume(key as String) as Dynamic
    for each r in Store_Get("gridResume", [])
        if r.key = key then return r
    end for
    return invalid
end function

sub Grid_SaveResume(key as String, season as Integer, ep as Integer, at as Integer)
    out = [{ key: key, s: season, e: ep, at: at }]
    for each r in Store_Get("gridResume", [])
        if r.key <> key and out.Count() < 30 then out.Push(r)
    end for
    Store_Set("gridResume", out)
end sub

' ---------- Watched episodes ----------

' watched = { "grid:id:title": { "1:3": true, "1:5": true } }
function Watched_Get(key as String) as Object
    all = Store_Get("watched", {})
    if all[key] <> invalid then return all[key]
    return {}
end function

function Watched_Has(key as String, season as Integer, ep as Integer) as Boolean
    w = Watched_Get(key)
    k = season.ToStr() + ":" + ep.ToStr()
    return w[k] = true
end function

sub Watched_Mark(key as String, season as Integer, ep as Integer)
    all = Store_Get("watched", {})
    w = all[key]
    if w = invalid then w = {}
    k = season.ToStr() + ":" + ep.ToStr()
    w[k] = true
    all[key] = w
    Store_Set("watched", all)
end sub

function Watched_CountSeason(key as String, season as Integer, total as Integer) as Integer
    w = Watched_Get(key)
    c = 0
    for i = 0 to total - 1
        k = season.ToStr() + ":" + i.ToStr()
        if w[k] = true then c++
    end for
    return c
end function

function Anime_LastSeen() as Integer
    v = To_Int(Store_Get("animeSeen", 0))
    if v = 0 then v = Now_Seconds() - 86400
    return v
end function

' ---------- Internet Archive ----------

function Archive_LicenseFilter() as String
    return " AND (licenseurl:*publicdomain* OR licenseurl:*creativecommons*)"
end function

function Archive_Search(q as String, sort as String, rows as Integer, page as Integer) as Object
    xfer = CreateObject("roUrlTransfer")
    full = "(" + q + ") AND mediatype:movies" + Archive_LicenseFilter()
    url = "https://archive.org/advancedsearch.php?q=" + xfer.Escape(full)
    url = url + "&fl%5B%5D=identifier&fl%5B%5D=title&fl%5B%5D=year"
    if sort <> "" then url = url + "&sort%5B%5D=" + xfer.Escape(sort)
    url = url + "&rows=" + rows.ToStr() + "&page=" + page.ToStr() + "&output=json"
    data = Http_GetJson(url)
    if data = invalid or data.response = invalid or data.response.docs = invalid then return []
    return data.response.docs
end function

function Archive_ItemNode(d as Object) as Object
    item = CreateObject("roSGNode", "ContentNode")
    id = To_Str(d.identifier)
    item.addFields({ itype: "archive", itemId: id })
    item.title = To_Str(d.title)
    item.shortDescriptionLine1 = To_Str(d.year)
    item.hdPosterUrl = "https://archive.org/services/img/" + id
    return item
end function

function Archive_BuildRow(r as Object, count as Integer) as Object
    sort = "downloads desc"
    if r.sort <> invalid then sort = r.sort
    row = CreateObject("roSGNode", "ContentNode")
    row.title = r.title
    for each d in Archive_Search(r.q, sort, count, 1)
        if d.identifier <> invalid then row.appendChild(Archive_ItemNode(d))
    end for
    return row
end function

function Archive_FileUrl(id as String, name as String) as String
    xfer = CreateObject("roUrlTransfer")
    enc = []
    for each p in name.Split("/")
        enc.Push(xfer.Escape(p))
    end for
    return "https://archive.org/download/" + id + "/" + enc.Join("/")
end function

function Archive_PrettyName(name as String) as String
    parts = name.Split("/")
    n = parts[parts.Count() - 1]
    n = CreateObject("roRegex", "(_512kb|\.ia|_hd)*\.(mp4|m4v)$", "i").Replace(n, "")
    return n.Replace("_", " ")
end function

' Returns { ok, title, year, description, license, files: [{ key, title, length, urls[] }] }
function Archive_Meta(id as String) as Object
    res = { ok: false, title: "", year: "", description: "", license: "", files: [] }
    data = Http_GetJson("https://archive.org/metadata/" + id)
    if data = invalid or data.metadata = invalid then return res
    md = data.metadata
    res.ok = true
    res.title = To_Str(md.title)
    res.year = To_Str(md.year)
    if res.year = "" then res.year = Left(To_Str(md.date), 4)
    res.description = Strip_Html(md.description)
    res.license = To_Str(md.licenseurl)
    if data.files = invalid then return res

    ' Lower rank is better: h.264 derivatives play on every Roku model.
    ranks = { "h.264": 1, "h.264 ia": 1, "h.264 hd": 2, "mpeg4": 3, "512kb mpeg4": 4 }
    baseRe = CreateObject("roRegex", "(_512kb|\.ia|_hd)*\.(mp4|m4v)$", "i")
    groups = {}
    keys = []
    for each f in data.files
        name = To_Str(f.name)
        lname = LCase(name)
        if Right(lname, 4) = ".mp4" or Right(lname, 4) = ".m4v"
            rank = ranks[LCase(To_Str(f.format))]
            if rank = invalid then rank = 5
            key = baseRe.Replace(lname, "")
            g = groups[key]
            if g = invalid
                g = { key: key, title: "", length: "", cands: [] }
                groups[key] = g
                keys.Push(key)
            end if
            if g.title = "" then g.title = To_Str(f.title)
            if g.length = "" then g.length = To_Str(f.length)
            g.cands.Push({ rank: rank, name: name })
        end if
    end for

    keys.Sort()
    for each key in keys
        g = groups[key]
        g.cands.SortBy("rank")
        urls = []
        for each c in g.cands
            urls.Push(Archive_FileUrl(id, c.name))
        end for
        title = g.title
        if title = "" then title = Archive_PrettyName(g.cands[0].name)
        res.files.Push({ key: key, title: title, length: g.length, urls: urls })
    end for
    return res
end function

function License_Label(url as String) as String
    l = LCase(url)
    if Instr(1, l, "publicdomain") > 0 then return "Domínio público"
    if Instr(1, l, "creativecommons") > 0 then return "Creative Commons"
    return ""
end function

' ---------- Other installed apps (External Control Protocol on this device) ----------

' Opens app <appId> (optional deep-link query). Must run in a Task: it waits on HTTP.
function Ecp_Launch(appId as String, query as String) as Boolean
    path = "/launch/" + appId
    if query <> "" then path = path + "?" + query
    return Ecp_Request("POST", path, "").code = 200
end function

' One ECP call ("GET" or "POST"); outFile <> "" saves a GET body to that file.
' Tries localhost and then the device's own IPs, remembering the one that answered.
' Returns { code, body }. Must run in a Task.
function Ecp_Request(method as String, path as String, outFile as String) as Object
    hosts = []
    if m.ecpHost <> invalid then hosts.Push(m.ecpHost)
    hosts.Push("127.0.0.1")
    for each ip in CreateObject("roDeviceInfo").GetIPAddrs().Items()
        hosts.Push(ip.value)
    end for
    last = { code: 0, body: "" }
    for each h in hosts
        port = CreateObject("roMessagePort")
        xfer = CreateObject("roUrlTransfer")
        xfer.SetPort(port)
        xfer.SetUrl("http://" + h + ":8060" + path)
        if method = "POST"
            started = xfer.AsyncPostFromString("")
        else if outFile <> ""
            started = xfer.AsyncGetToFile(outFile)
        else
            started = xfer.AsyncGetToString()
        end if
        if started
            msg = wait(5000, port)
            if type(msg) = "roUrlEvent"
                code = msg.GetResponseCode()
                last = { code: code, body: msg.GetString() }
                ' A refusal (e.g. 403 on localhost) may still work on the LAN address.
                if (code >= 200 and code < 300) or code = 404
                    m.ecpHost = h
                    return last
                end if
            else
                xfer.AsyncCancel()
            end if
        end if
    end for
    return last
end function

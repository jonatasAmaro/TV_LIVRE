' Talks to this TV's External Control Protocol for the launcher screen.
sub init()
    m.top.functionName = "execute"
end sub

sub execute()
    mode = m.top.mode
    if mode = "launch"
        m.top.result = { launched: Ecp_Launch(m.top.appId, "") }
    else if mode = "key"
        m.top.result = { launched: Ecp_Request("POST", "/keypress/" + m.top.key, "").code = 200 }
    else
        m.top.result = { apps: listApps() }
    end if
end sub

function listApps() as Object
    out = []
    res = Ecp_Request("GET", "/query/apps", "")
    xml = CreateObject("roXMLElement")
    if res.code <> 200 or not xml.Parse(res.body) then return out
    dir = "tmp:/launcher"
    CreateObject("roFileSystem").CreateDirectory(dir)
    nbsp = Chr(160)
    for each a in xml.GetNamedElements("app")
        attrs = a.GetAttributes()
        id = To_Str(attrs.id)
        icon = dir + "/" + id.Replace(".", "_")
        if Ecp_Request("GET", "/query/icon/" + id, icon).code <> 200 then icon = ""
        out.Push({ id: id, type: To_Str(attrs.type), name: a.GetText().Replace(nbsp, " ").Trim(), icon: icon })
    end for
    return out
end function

sub init()
    m.top.functionName = "execute"
end sub

sub execute()
    data = Http_GetJson(m.top.url)
    if type(data) <> "roAssociativeArray" then data = {}
    m.top.result = data
end sub

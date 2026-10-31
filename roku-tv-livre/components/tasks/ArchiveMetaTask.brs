sub init()
    m.top.functionName = "execute"
end sub

sub execute()
    m.top.result = Archive_Meta(m.top.identifier)
end sub

sub init()
    m.top.functionName = "execute"
end sub

sub execute()
    for each r in m.top.rows
        node = Archive_BuildRow(r, m.top.rowCount)
        if node.getChildCount() > 0 then m.top.row = node
    end for
    m.top.done = true
end sub

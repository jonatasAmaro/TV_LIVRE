param([string[]]$Steps, [int]$Wait = 8)
# Opens the Roku debug console, runs ECP steps ("deploy", "launch/dev", "keypress/Right", "sleep:3"),
# prints the active app after each and the console lines that matter.
$ip = "192.168.18.20"
# powershell -File passes "a,b,c" as one string.
$Steps = $Steps | ForEach-Object { $_ -split ',' }
$c = New-Object Net.Sockets.TcpClient($ip, 8085); $s = $c.GetStream(); $s.ReadTimeout = 300
$buf = New-Object byte[] 65536; $sb = New-Object Text.StringBuilder
function Drain($sec) { $end = (Get-Date).AddSeconds($sec); while ((Get-Date) -lt $end) { try { $n = $s.Read($buf, 0, $buf.Length); if ($n -gt 0) { [void]$sb.Append([Text.Encoding]::UTF8.GetString($buf, 0, $n)) } } catch {} } }
function Active { ([xml](Invoke-WebRequest -UseBasicParsing "http://${ip}:8060/query/active-app").Content).'active-app'.app.'#text' }
Drain 2; [void]$sb.Clear()
foreach ($st in $Steps) {
    if ($st -eq "deploy") { & powershell -ExecutionPolicy Bypass -File "E:\CODIGO FONTE\TV_LIVRE\deploy.ps1" -RokuIp $ip | Select-Object -Last 1; Drain $Wait }
    elseif ($st -like "sleep:*") { Drain ([int]$st.Substring(6)) }
    else { Invoke-WebRequest -UseBasicParsing -Method Post "http://${ip}:8060/$st" | Out-Null; Drain 0.7 }
    "[$st] ativo: $(Active)"
}
Drain 2; $c.Close()
"--- console:"
$sb.ToString() -split "`n" | Where-Object { $_ -match '^\[|launcher|ERROR|Error|error|crash|BRIGHTSCRIPT|Runtime|Backtrace|line|pkg:/' -and $_ -notmatch 'beacon' } | Select-Object -Last 40

import sys, re, urllib.request
UA={"User-Agent":"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/130.0 Safari/537.36","Accept-Language":"pt-BR"}
for arg in sys.argv[1:]:
    name,cid=arg.split("=",1)
    t=urllib.request.urlopen(urllib.request.Request(f"https://www.youtube.com/channel/{cid}/live",headers=UA),timeout=20).read().decode("utf-8","ignore")
    live='"isLiveNow":true' in t
    can=re.search(r'<link rel="canonical" href="https://www\.youtube\.com/watch\?v=([\w-]{11})"',t)
    ttl=re.search(r'<meta name="title" content="([^"]+)"',t)
    print(f"{name:22} live={live!s:5} {can.group(1) if can else '-':12} {(ttl.group(1)[:70] if ttl and live else '')}")

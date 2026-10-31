import sys, re, urllib.request
UA={"User-Agent":"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/130.0 Safari/537.36","Accept-Language":"pt-BR"}
for h in sys.argv[1:]:
    try:
        t=urllib.request.urlopen(urllib.request.Request(f"https://www.youtube.com/@{h}",headers=UA),timeout=20).read().decode("utf-8","ignore")
        cid=re.search(r'"externalId":"(UC[\w-]{22})"',t) or re.search(r'"channelId":"(UC[\w-]{22})"',t)
        name=re.search(r'<meta property="og:title" content="([^"]+)"',t)
        subs=re.search(r'"subscriberCountText":\{"accessibility":\{"accessibilityData":\{"label":"([^"]+)"',t) or re.search(r'"content":"([\d.,]+\s*(?:mi|mil)?\s*inscritos)"',t)
        verified="BADGE_STYLE_TYPE_VERIFIED" in t or "CHECK_CIRCLE_THICK" in t
        print(f"@{h} | {cid.group(1) if cid else '-'} | {name.group(1) if name else '-'} | {subs.group(1) if subs else '?'} | verificado={verified}")
    except Exception as e:
        print(f"@{h} | erro {e}")

import sys, re, json, urllib.request, urllib.parse
UA={"User-Agent":"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/130.0 Safari/537.36","Accept-Language":"pt-BR"}
for q in sys.argv[1:]:
    url="https://www.youtube.com/results?search_query="+urllib.parse.quote(q)+"&sp=EgIQAg%253D%253D"
    t=urllib.request.urlopen(urllib.request.Request(url,headers=UA),timeout=20).read().decode("utf-8","ignore")
    print("==",q)
    for m in list(re.finditer(r'"channelRenderer":\{"channelId":"(UC[\w-]{22})"',t))[:5]:
        seg=t[m.start():m.start()+4000]
        title=re.search(r'"title":\{"simpleText":"([^"]+)"',seg)
        handle=re.search(r'"canonicalBaseUrl":"(/@[^"]+)"',seg)
        subs=re.search(r'"videoCountText":\{"accessibility":\{"accessibilityData":\{"label":"([^"]+)"',seg) or re.search(r'"subscriberCountText":\{"accessibility":\{"accessibilityData":\{"label":"([^"]+)"',seg)
        ver="BADGE_STYLE_TYPE_VERIFIED" in seg or "OFFICIAL_ARTIST_BADGE" in seg
        print(" ",m.group(1),"|",title and title.group(1),"|",handle and handle.group(1),"|",subs and subs.group(1),"| verif" if ver else "")

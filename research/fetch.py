import sys, re, subprocess, json, html2text
from bs4 import BeautifulSoup
TYPES={1:'npc',2:'object',3:'item',4:'itemset',5:'quest',6:'spell',7:'zone',8:'faction',13:'class',14:'race'}
def wh(html):
    names={}
    for m in re.finditer(r'WH\.Gatherer\.addData\((\d+),\s*\d+,\s*(\{.*?\})\);', html):
        t=int(m.group(1))
        try: d=json.loads(m.group(2))
        except Exception: continue
        for k,v in d.items():
            if isinstance(v,dict) and 'name_enus' in v: names[(TYPES.get(t,str(t)),k)]=v['name_enus']
    out=[]
    for m in re.finditer(r'WH\.markup\.printHtml\(("(?:[^"\\]|\\.)*")', html, re.S):
        try: s=json.loads(m.group(1))
        except Exception: continue
        def rep(mm):
            typ,i=mm.group(1),mm.group(2)
            n=names.get((typ,i))
            return f"{n} [{typ}={i}]" if n else f"[{typ}={i}]"
        s=re.sub(r'\[(item|spell|quest|npc|zone|object|itemset|faction)=(\d+)[^\]]*\]',rep,s)
        out.append(s)
    return '\n\n'.join(out), names
for url in sys.argv[1:]:
    name = re.sub(r'[^A-Za-z0-9]+','_', url.split('://')[1])[:120]
    html = subprocess.run(['curl','-sL','-A','Mozilla/5.0','--max-time','40',url],capture_output=True).stdout.decode('utf-8','replace')
    open('raw/'+name+'.html','w').write(html)
    txt=''
    if 'wowhead.com' in url:
        txt,names=wh(html)
    if len(txt)<500:
        soup = BeautifulSoup(html,'html.parser')
        for t in soup(['script','style','nav','footer','noscript','svg','header','aside']): t.decompose()
        main = soup.find('article') or soup.find('main') or soup.body or soup
        h = html2text.HTML2Text(); h.body_width=0; h.ignore_images=True
        txt = h.handle(str(main))
    open('raw/'+name+'.md','w').write(url+'\n\n'+txt)
    print(len(html), len(txt), name+'.md')

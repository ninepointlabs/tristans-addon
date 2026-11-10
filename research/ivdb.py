import sys,re,subprocess
from bs4 import BeautifulSoup
for path in sys.argv[1:]:
    url='https://db.icy-veins.com/wow-forever/'+path
    h=subprocess.run(['curl','-sL','-A','Mozilla/5.0','--max-time','30',url],capture_output=True).stdout.decode('utf-8','replace')
    open('raw/ivdb_'+path.replace('/','_')+'.html','w').write(h)
    s=BeautifulSoup(h,'html.parser'); [t.decompose() for t in s(['script','style'])]
    t=re.sub(r'\n\s*\n+','\n',s.get_text('\n'))
    i=t.find('Report it to us'); t=t[i:]
    j=t.find('Spotted something wrong or missing'); t=t[:j]
    # skip breadcrumb nav
    k=t.find('\n',t.find('Uncategorized',t.rfind('Uncategorized')-5)) if 'Uncategorized' in t else 0
    print('=====',url); print(t[k:k+1500])

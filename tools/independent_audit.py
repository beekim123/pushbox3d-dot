#!/usr/bin/env python3
"""Independent reachable-state invariants and retained-rule mechanism bypass checks.
Run from any directory: python tools/independent_audit.py
Produces cross-engine fixtures; then run Godot --headless --path . --script res://tests/independent_parity.gd
"""
import json,sys,heapq,collections,random,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from puzzle_solver import Level,VECTORS,add
PATH=ROOT/'assets/levels.json'
levels=json.load(open(PATH))['levels']
def uses(l,s,a,n,push):
 u=set();target=add(s[0],VECTORS[a]);opened=bool(set(s[1])&l.plates)
 def mark(p):
  if p in l.arrows:u.add('arrows')
  if p in l.gates:u.add('gates')
 mark(target)
 if push:
  p=add(target,VECTORS[a]);mark(p)
  while p in l.glide:
   u.add('glide');q=add(p,VECTORS[a])
   if q not in l.floors or q in s[1] or(q in l.gates and not opened)or(q in l.arrows and l.arrows[q]!=a):break
   p=q;mark(p)
  if p in l.portals:u.add('portals');mark(l.portals[p])
 return u
report={'levels_sha256':hashlib.sha256(open(PATH,'rb').read()).hexdigest(),'invariant_states':0,'invariant_transitions':0,'bypass':[]};cases=[];rng=random.Random(1327)
for d in levels:
 l=Level(d);seen={l.initial};q=collections.deque([l.initial])
 while q:
  s=q.popleft()
  for a in VECTORS:
   r=l.step(s,a)
   if not r:continue
   n,p=r;report['invariant_transitions']+=1
   assert n[0] in l.floors and n[0] not in n[1] and len(n[1])==len(l.initial[1])==len(set(n[1])) and set(n[1])<=l.floors
   if not set(n[1])&l.plates:assert n[0] not in l.gates and not set(n[1])&l.gates
   if n not in seen:seen.add(n);q.append(n)
 report['invariant_states']+=len(seen)
 sample=rng.sample(sorted(seen),min(80,len(seen)))
 for s in sample:
  for a in VECTORS:
   r=l.step(s,a);cases.append({'level_id':d['id'],'player':s[0],'crates':s[1],'action':a,'expected':r[0] if r else None})
 if not d['tutorial']:
  for kind in ('glide','portals','arrows','gates'):
   if not d.get(kind):continue
   dist={l.initial:(0,0)};hq=[(0,0,l.initial)];out=None
   while hq:
    p,m,s=heapq.heappop(hq)
    if dist[s]!=(p,m):continue
    if l.won(s):out=[p,m];break
    for a in VECTORS:
     r=l.step(s,a)
     if not r:continue
     n,push=r
     if kind in uses(l,s,a,n,push):continue
     cost=(p+push,m+1)
     if cost<dist.get(n,(999999,999999)):dist[n]=cost;heapq.heappush(hq,(*cost,n))
   report['bypass'].append({'id':d['id'],'mechanic':kind,'optimal_without_use':out})
   if d['id'].startswith('confluence'):assert out is None,(d['id'],kind,out)
(ROOT/'tests/independent_cases.json').write_text(json.dumps(cases,separators=(',',':'))+'\n')
report['parity_cases']=len(cases)
(ROOT/'tests/independent_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print('INDEPENDENT_AUDIT states=%d transitions=%d parity_cases=%d' % (report['invariant_states'],report['invariant_transitions'],report['parity_cases']))

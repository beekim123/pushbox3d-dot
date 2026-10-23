#!/usr/bin/env python3
"""Independent V2 campaign checks. Does not generate or mutate levels.
python tools/audit_campaign_v2.py --levels assets/campaign_preview.json --report tests/campaign_preview_report.json
For final204 add --expect-final. Results include source hashes and are not V1 evidence.
"""
import argparse,hashlib,json,sys,collections,statistics
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from puzzle_solver import Level,solve,solve_macro,replay,VECTORS,add

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
class AvoidMechanic(Level):
    def __init__(self,data,kind):super().__init__(data);self.kind=kind
    def step(self,state,action):
        result=super().step(state,action)
        if result and self.kind in uses(self,state,action,*result):return None
        return result


def canon(data,shape_only=False):
    l=Level(data); reps=[]
    matrices=((1,0,0,1),(0,-1,1,0),(-1,0,0,-1),(0,1,-1,0),(-1,0,0,1),(0,-1,-1,0),(1,0,0,-1),(0,1,1,0))
    for a,b,c,d in matrices:
        def rotate(p):return(a*p[0]+b*p[1],c*p[0]+d*p[1])
        rf=[rotate(p)for p in l.floors];lo=(min(p[0]for p in rf),min(p[1]for p in rf))
        def point(p):q=rotate(p);return(q[0]-lo[0],q[1]-lo[1])
        def points(ps):return sorted(point(p)for p in ps)
        value=[points(l.floors)]
        if not shape_only:
            value.extend([points(l.initial[1]),points(l.goals),points(l.glide),sorted((point(p),rotate(VECTORS[v]))for p,v in l.arrows.items()),sorted(sorted((point(x),point(y)))for x,y in data.get('portals',[])),points(l.plates),points(l.gates)])
        reps.append(json.dumps(value,separators=(',',':')))
    return hashlib.sha256(min(reps).encode()).hexdigest()

def main():
 p=argparse.ArgumentParser();p.add_argument('--levels',default='assets/levels.json');p.add_argument('--report',default='tests/solver_report.json');p.add_argument('--expect-final',action='store_true');args=p.parse_args()
 lp=ROOT/args.levels;rp=ROOT/args.report
 raw=json.loads(lp.read_text());levels=raw['levels'];reports=json.loads(rp.read_text())['levels'];byid={r['id']:r for r in reports}
 errors=[];out={'version':2,'levels_file':args.levels,'levels_sha256':hashlib.sha256(lp.read_bytes()).hexdigest(),'solver_report_sha256':hashlib.sha256(rp.read_bytes()).hexdigest(),'levels':[],'worlds':{},'errors':errors}
 seen={};idset=set();canonical=[]
 counts=collections.Counter(d['world']for d in levels)
 if args.expect_final:
  if dict(counts)!={'heaven':50,'inferno':50,'rainforest':50,'city':50,'confluence':4}:errors.append('Expected exact50x4+4 count, got '+str(counts))
 if len(byid)!=len(reports):errors.append('Duplicate solver-report IDs')
 for d in levels:
  ident=d['id']
  if ident in idset:errors.append('Duplicate level ID '+ident)
  idset.add(ident);l=Level(d);r=byid.get(ident)
  if not r:errors.append('Missing report '+ident);continue
  fp=canon(d);canonical.append(fp)
  if fp in seen:errors.append('Symmetry-equivalent puzzles '+ident+' / '+seen[fp])
  seen[fp]=ident
  actual=solve_macro(l,max_states=200000)
  if actual['status']!='solved':errors.append(ident+' independent resolve '+actual['status']);continue
  if(actual['pushes'],actual['moves'])!=(r['pushes'],r['moves']):errors.append(ident+' report cost mismatch')
  replayed=replay(l,r['solution'])
  if not replayed['won']:errors.append(ident+' replay not won')
  if json.loads(json.dumps(replayed['states']))!=r['states']:errors.append(ident+' report snapshot mismatch')
  bypass={}
  for kind in ('glide','portals','arrows','gates'):
   if not d.get(kind):continue
   avoided=solve_macro(AvoidMechanic(d,kind),max_states=200000)
   bypass[kind]={'status':avoided['status'],'pushes':avoided.get('pushes')}
   if avoided['status'] not in ('solved','unsolvable'):errors.append(ident+' bypass search inconclusive '+kind)
   if avoided['status']=='solved' and avoided['pushes']<actual['pushes']+3:errors.append(ident+' cheap mechanic bypass '+kind)
   if d['world']=='confluence' and avoided['status']!='unsolvable':errors.append(ident+' confluence mechanic not mandatory '+kind)
  full_result=None
  # Exact unpruned stepDijkstra on the firstfive/world and selected laterchapter boundaries.
  if int(d.get('order',1))<=5 or int(d.get('order',1))in(25,50)or d['world']=='confluence':
   full_result=solve(l,max_states=400000,prune_deadlocks=False)
   if full_result['status']=='solved' and (full_result['pushes'],full_result['moves'])!=(actual['pushes'],actual['moves']):errors.append(ident+' macro/fullstep mismatch')
   elif full_result['status']=='unsolvable':errors.append(ident+' fullstep disagrees unsolvable')
  row={'id':ident,'bypass':bypass,'pushes':actual['pushes'],'moves':actual['moves'],'crates':len(l.initial[1]),'macro_expanded':actual['expanded_states'],'shape_fingerprint':canon(d,True),'puzzle_fingerprint':fp,'fullstep_status':full_result['status']if full_result else'not_sampled'}
  out['levels'].append(row)
 if set(byid)!=idset:errors.append('Report and level ID sets differ')
 for world in counts:
  items=[d for d in levels if d['world']==world];costs=[r for r in out['levels']if r['id']in{d['id']for d in items}];chapters=[]
  if world!='confluence':
   for n in sorted(set(d.get('chapter',1)for d in items)):
    group=[d for d in items if d.get('chapter',1)==n];ids={d['id']for d in group};rows=[r for r in costs if r['id']in ids]
    if args.expect_final and(len(group)!=5 or sorted(d.get('stage',0)for d in group)!=[1,2,3,4,5]):errors.append(f'{world} chapter{n} stage structure invalid')
    chapters.append({'chapter':n,'count':len(group),'median_pushes':statistics.median(r['pushes']for r in rows),'range_pushes':[min(r['pushes']for r in rows),max(r['pushes']for r in rows)],'distinct_shapes':len({r['shape_fingerprint']for r in rows})})
  out['worlds'][world]={'count':len(items),'distinct_shapes':len({r['shape_fingerprint']for r in costs}),'chapters':chapters}
 out['passed']=not errors
 (ROOT/'tests/campaign_independent_v2.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
 print('V2_CAMPAIGN_AUDIT levels=%d distinct_puzzles=%d errors=%s'%(len(levels),len(seen),errors));return int(bool(errors))
if __name__=='__main__':sys.exit(main())

#!/usr/bin/env python3
"""Original seeded puzzle search. No imported or published Sokoban layouts."""
import copy
import json
from pathlib import Path
import random
import time
from puzzle_solver import Level, solve, replay, VECTORS, add, from_ascii

ROOT = Path(__file__).resolve().parents[1]


def transition_uses(level, old, action):
    counts=dict(glide=0,portals=0,arrows=0,gates=0)
    result=Level.step(level,old,action)
    if result is None:return counts
    state,pushed=result
    if state[0] in level.arrows: counts['arrows'] += 1
    if state[0] in level.gates: counts['gates'] += 1
    if pushed:
        target = add(old[0], VECTORS[action])
        destination = add(target, VECTORS[action])
        while True:
            if destination in level.arrows: counts['arrows'] += 1
            if destination in level.gates: counts['gates'] += 1
            if destination not in level.glide: break
            nxt = add(destination, VECTORS[action])
            if (nxt not in level.floors or nxt in old[1] or
                nxt in level.arrows and level.arrows[nxt] != action or
                nxt in level.gates and not set(old[1]) & level.plates): break
            counts['glide'] += 1
            destination = nxt
        if destination in level.portals: counts['portals'] += 1
    return counts


def use_counts(level, solution):
    state=level.initial
    counts=dict(glide=0,portals=0,arrows=0,gates=0)
    for action in solution:
        events=transition_uses(level,state,action)
        for k,v in events.items():counts[k]+=v
        state=level.step(state,action)[0]
    return counts


class AvoidLevel(Level):
    def __init__(self,data,forbid):
        self.forbid=forbid
        super().__init__(data)
    def step(self,state,action):
        if transition_uses(self,state,action)[self.forbid]:return None
        return super().step(state,action)


def candidate(rng, kinds, box_count=2):
    n = 7
    cells = [(x,y) for y in range(1,n-1) for x in range(1,n-1)]
    walls = {(x,y) for y in range(n) for x in range(n) if x in (0,n-1) or y in (0,n-1)}
    interior_walls = rng.sample(cells, rng.randint(2,5))
    walls.update(interior_walls)
    floors = sorted(set(cells)-walls)
    # Remove unreachable decorative pockets; all floor belongs to one island.
    connected={floors[0]}; queue=[floors[0]]
    while queue:
        p=queue.pop()
        for delta in VECTORS.values():
            q=add(p,delta)
            if q in floors and q not in connected: connected.add(q);queue.append(q)
    walls.update(set(floors)-connected)
    floors=sorted(connected)
    if len(floors)<18: return candidate(rng,kinds,box_count)
    positions = rng.sample(floors, 1+box_count*2)
    d = dict(width=n,height=n,walls=sorted(walls),player=positions[0],
             crates=positions[1:1+box_count],goals=positions[1+box_count:],mechanic={'type':'terrain'})
    available = sorted(set(floors)-set(positions))
    # Features are distinct from starting entities / goals, except an optional
    # pressure plate goal. Keeping terrain separate makes the visual language clear.
    rng.shuffle(available)
    if 'glide' in kinds:
        d['glide'] = [available.pop() for _ in range(rng.randint(2,4))]
    if 'portals' in kinds:
        d['portals'] = [[available.pop(),available.pop()]]
    if 'arrows' in kinds:
        d['arrows'] = [{'cell':available.pop(),'dir':rng.choice('UDLR')} for _ in range(rng.randint(1,3))]
    if 'gates' in kinds:
        d['gates'] = [available.pop()]
        d['plates'] = [rng.choice(d['goals']) if rng.random()<.65 else available.pop()]
    return d


def remove_kind(data, kind):
    d=copy.deepcopy(data)
    d.pop(kind,None)
    if kind=='gates': d.pop('plates',None)
    return d


def search(seed, kinds, min_pushes, max_pushes, max_candidates=2500, strict_bypass=False):
    rng=random.Random(seed)
    stats={'generated':0,'unsolvable':0,'budget':0,'too_easy_or_long':0,'unused_mechanic':0,'no_constraint_effect':0}
    best=None
    start=time.time()
    for i in range(max_candidates):
        d=candidate(rng,kinds)
        stats['generated']+=1
        try: result=solve(Level(d),max_states=16000)
        except ValueError: continue
        if result['status']!='solved':
            stats['budget' if result['status']=='budget_exhausted' else 'unsolvable']+=1
            continue
        if not min_pushes<=result['pushes']<=max_pushes or result['moves']>95:
            stats['too_easy_or_long']+=1; continue
        usages=use_counts(Level(d),result['solution'])
        if any(not usages[k] for k in kinds):
            stats['unused_mechanic']+=1;continue
        contrasts={}
        meaningful=True
        for kind in kinds:
            contrast=solve(Level(remove_kind(d,kind)),max_states=22000)
            contrasts[kind] = {k:contrast[k] for k in ('status','pushes','moves') if k in contrast}
            # Requiring a change in optimal cost, or unsolvability without the
            # feature, rejects the simplest bypasses. It does not prove there is
            # exactly one human-level strategy.
            if contrast['status']=='solved':
                if (abs(contrast['pushes']-result['pushes']) < 2
                        and abs(contrast['moves']-result['moves']) < 5):
                    meaningful=False
        if not meaningful:
            stats['no_constraint_effect']+=1;continue
        bypass={}
        if strict_bypass:
            for kind in kinds:
                avoid=solve(AvoidLevel(d,kind),max_states=35000)
                bypass[kind]={k:avoid[k] for k in ('status','pushes','moves') if k in avoid}
                if avoid['status']=='budget_exhausted' or (avoid['status']=='solved' and avoid['pushes']<result['pushes']+3):
                    meaningful=False
            if not meaningful:
                stats['no_constraint_effect']+=1;continue
        result['retained_rules_bypass_comparison']=bypass
        quality = min(result['moves'],60) + 2*result['pushes'] - 3*sum(len(d.get(k,[])) for k in kinds)
        if best is None or quality>best[0]: best=(quality,d,result,usages,contrasts)
        if i>40 and best is not None: break
    if best is None:
        raise RuntimeError(f'No puzzle found seed={seed} kinds={kinds} stats={stats}')
    _,d,result,usages,contrasts=best
    result.update(mechanic_uses=usages,disabled_mechanic_comparison=contrasts,search_stats=stats,seed=seed)
    print(f'found {seed} {kinds} {result["pushes"]} pushes {result["moves"]} steps in {stats["generated"]} candidates ({time.time()-start:.1f}s)',flush=True)
    return d,result


def tutorial(kind):
    if kind=='glide':
        d=from_ascii(['#######','#     #','#@$  .#','#     #','#######'])
        d['glide']=[[3,2],[4,2]]
    elif kind=='portals':
        d=from_ascii(['#######','#@ $  #','#     #','#   . #','#######'])
        d['portals']=[[[4,1],[3,3]]]
    elif kind=='arrows':
        d=from_ascii(['#####','# . #','# $ #','#  @#','#   #','#####'])
        d['arrows']=[{'cell':[2,3],'dir':'R'}]
    else:
        d=from_ascii(['########','#   #  #','# $   .#','#   #  #','#@$ .  #','########'])
        d['plates']=[[4,4]];d['gates']=[[4,2]]
    d['mechanic']={'type':'terrain'}
    return d


def polish_features(data, report):
    """Remove redundant arrow/glide clutter without weakening selected solution."""
    d=copy.deepcopy(data)
    removed=0
    for field in ('arrows','glide'):
        for feature in list(d.get(field,[])):
            trial=copy.deepcopy(d)
            trial[field].remove(feature)
            if not trial[field]:continue
            candidate_report=solve(Level(trial),max_states=35000)
            if candidate_report['status']!='solved':continue
            if (candidate_report['pushes'],candidate_report['moves'])!=(report['pushes'],report['moves']):continue
            kinds=[k for k in ('arrows','glide','portals','gates') if trial.get(k)]
            if any(not use_counts(Level(trial),candidate_report['solution'])[k] for k in kinds):continue
            keep=True
            # The final trials retain their no-cheap-bypass property.
            if d.get('world')=='confluence':
                for kind in kinds:
                    a=solve(AvoidLevel(trial,kind),max_states=35000)
                    if a['status']!='unsolvable' and (a['status']!='solved' or a['pushes']<report['pushes']+3):keep=False
            if keep:
                d=trial;removed+=1
    new=solve(Level(d))
    for k in ('search_stats','seed','tutorial'):
        if k in report:new[k]=report[k]
    new['redundant_feature_tiles_removed']=removed
    new['mechanic_uses']=use_counts(Level(d),new['solution'])
    kinds=[k for k in ('arrows','glide','portals','gates') if d.get(k)]
    new['disabled_mechanic_comparison']={}
    if not d.get('tutorial'):
        for kind in kinds:
            a=solve(Level(remove_kind(d,kind)),max_states=35000)
            new['disabled_mechanic_comparison'][kind]={k:a[k] for k in ('status','pushes','moves') if k in a}
    new['retained_rules_bypass_comparison']={}
    for kind in kinds:
        a=solve(AvoidLevel(d,kind),max_states=35000)
        new['retained_rules_bypass_comparison'][kind]={k:a[k] for k in ('status','pushes','moves') if k in a}
    new['states']=replay(Level(d),new['solution'])['states']
    return d,dict(id=d['id'],**new)


def main():
    defs=[('heaven','glide',['初上云阶','回风折径','双鹤归庭']),
          ('inferno','portals',['炉门来客','换位回廊','双焰归槽']),
          ('rainforest','arrows',['顺藤而行','绕根归芽','双果入林']),
          ('city','gates',['点亮山桥','借路上楼','两岸相望'])]
    levels=[];reports=[]
    for wi,(world,kind,names) in enumerate(defs):
        for j,name in enumerate(names):
            if j==0:
                d=tutorial(kind);r=solve(Level(d));r['mechanic_uses']=use_counts(Level(d),r['solution']);r['tutorial']=True
            else:
                d,r=search(20261023+wi*100+j,[kind],5 if j==1 else 10,9 if j==1 else 16,max_candidates=15000)
            d.update(id=f'{world}_{j+1:02}',world=world,name=name,order=j+1,
                     tutorial=j==0,difficulty=['引路','转念','精研'][j])
            levels.append(d);reports.append(dict(id=d['id'],**r))
    mixes=[('heaven',['glide','portals'],'云炉回响'),('inferno',['portals','arrows'],'炉心枝路'),
           ('rainforest',['arrows','gates'],'林桥约定'),('city',['gates','glide'],'山城流云')]
    for i,(visual,kinds,name) in enumerate(mixes):
        d,r=search(20262023+i,kinds,8,17,max_candidates=25000,strict_bypass=True)
        d.update(id=f'confluence_{i+1:02}',world='confluence',visual_world=visual,name=name,order=i+1,
                 tutorial=False,difficulty='交汇',requires=12)
        levels.append(d);reports.append(dict(id=d['id'],**r))
    for i in range(len(levels)):
        levels[i],reports[i]=polish_features(levels[i],reports[i])
    (ROOT/'assets/levels.json').write_text(json.dumps({'version':1,'levels':levels},ensure_ascii=False,indent=2)+'\n')
    # Full snapshots allow exact headless GDScript/Python parity tests, not merely
    # a check that both agree on the final won flag.
    for d,r in zip(levels,reports):
        r['states']=replay(Level(d),r['solution'])['states']
    (ROOT/'tests/solver_report.json').write_text(json.dumps({'all_solved':True,'levels':reports},ensure_ascii=False,indent=2)+'\n')


if __name__=='__main__':
    raise SystemExit('V1 generator retained as analysis utilities only. V2: python3 tools/generate_campaign.py --limit 50 --workers 2, then python3 tools/finalize_campaign.py. This command will not overwrite the 204-level campaign.')

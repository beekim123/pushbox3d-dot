"""Independent V2 macro-search differential regression; no campaign regeneration."""
import sys,random,json,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from puzzle_solver import Level,solve,solve_macro,replay

class MacroDifferentialV2(unittest.TestCase):
 def compare(self,data):
  level=Level(data)
  a=solve(level,max_states=200000,prune_deadlocks=False)
  b=solve_macro(level,max_states=200000)
  self.assertNotEqual(a['status'],'budget_exhausted')
  self.assertNotEqual(b['status'],'budget_exhausted')
  self.assertEqual(a['status'],b['status'],data)
  if a['status']=='solved':
   self.assertEqual((a['pushes'],a['moves']),(b['pushes'],b['moves']),data)
   self.assertTrue(replay(level,b['solution'])['won'])
  return a
 def test_seeded_mixed_mechanics(self):
  rng=random.Random(47020071)
  for seed in range(320):
   w=h=5;inner=[(x,y) for y in range(1,4) for x in range(1,4)]
   floors=set(inner)-set(rng.sample(inner,rng.randrange(2)))
   slots=rng.sample(sorted(floors),5)
   boxes=1 if seed%2 else 2
   d={'width':w,'height':h,'walls':sorted({(x,y) for y in range(h) for x in range(w)}-floors),'player':slots[0],'crates':slots[1:1+boxes],'goals':slots[3:3+boxes],'mechanic':{'type':'terrain'}}
   cells=rng.sample(sorted(floors),len(floors)); features=seed%16
   if features&1:d['glide']=[cells.pop()]
   if features&2:d['portals']=[[cells.pop(),cells.pop()]]
   if features&4:d['arrows']=[{'cell':cells.pop(),'dir':rng.choice('UDLR')}]
   if features&8:
    d['plates']=[cells.pop()]
    eligible=[p for p in cells if p!=d['player'] and p not in d['crates']]
    if eligible:d['gates']=[eligible[0]]
   with self.subTest(seed=seed):self.compare(d)
 def test_campaign_first_twenty(self):
  path=ROOT/'assets/levels.json'
  if not path.exists():self.skipTest('V2 levels not generated yet')
  levels=json.loads(path.read_text())['levels']
  sample=[]
  for world in ('heaven','inferno','rainforest','city'):
   sample.extend([l for l in levels if l['world']==world][:5])
  self.assertEqual(len(sample),20)
  for data in sample:
   with self.subTest(level=data['id']):self.compare(data)

if __name__=='__main__':unittest.main()

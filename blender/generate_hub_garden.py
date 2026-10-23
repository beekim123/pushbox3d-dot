"""V2 original four-lobed loom garden; uses our own Blender modelling helpers."""
import bpy,sys,os,math
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)));sys.path.insert(0,ROOT+'/blender')
from model_helpers import *
from generate_orchard import P,export_merged,terrace,rock,shrub,branch,leaf,blossom
OUT=ROOT+'/assets/models'
def asset(kind):
 before=set(bpy.data.objects)
 if kind=='landscape':
  outline=[]
  for i in range(96):
   a=i*math.tau/96;r=5.35+1.0*math.cos(4*a);outline.append((math.cos(a)*r,math.sin(a)*r))
  terrace('Four lobed stone garden',outline,-.15,.75,P['rock']);terrace('Warm stone middle stratum',[(x*.985,y*.985) for x,y in outline],-.10,.25,P['stone']);terrace('Fourfold moss garden',[(x*.97,y*.97) for x,y in outline],-.03,.13,P['grass'])
  for a in [math.pi/4,3*math.pi/4,5*math.pi/4,7*math.pi/4]:
   x,y=math.cos(a)*4.5,math.sin(a)*4.5;rock((x,y,.1),.9,int(a*11));shrub((x*.86,y*.86,.1),1)
 elif kind=='tile':
  for i,(x,y) in enumerate([(-.47,-.47),(.47,-.47),(-.47,.47),(.47,.47)]):box('Quiet limestone paving',(x,y,-.005),(.92,.92,.065),P['stone_light'] if i%3 else P['stone'],.08)
 elif kind=='center':
  cylinder('Worn central loom stone',(0,0,.13),1.50,.26,P['stone'],64,.09)
  cylinder('Moss recessed loom bed',(0,0,.28),1.28,.10,P['grass'],64,.06)
  cylinder('Wooden loom spindle',(0,0,1.02),.42,1.16,P['wood']);cylinder('Wood spool lower lip',(0,0,.48),.64,.17,P['bark_light']);cylinder('Wood spool upper lip',(0,0,1.57),.64,.17,P['bark_light'])
  colors=[P['pink'],P['water'],P['leaf_light'],P['gold']]
  for i,z in enumerate([.65,.79,.93,1.07,1.21,1.35]):torus('Four worlds woven cord',(0,0,z),.43,.035,colors[i%4])
  for i in range(4):
   a=i*math.pi/2;x,y=math.cos(a)*1.05,math.sin(a)*1.05
   branch('Carved garden loom arm',[(x,y,.28),(x*.94,y*.94,1.8),(x*.55,y*.55,2.35),(0,0,2.5)],[.095,.085,.06,.025],P['wood'])
   branch('Fine brass weaving strand',[(x*.80,y*.80,.56),(x*.45,y*.45,1.5),(0,0,2.45)],[.014,.014,.01],P['brass'])
   shrub((x*.9,y*.9,.3),.45,False)
  sphere('Fourfold loom crown',(0,0,2.5),(.17,.17,.20),P['gold']);blossom((0,0,2.68),.17,0,3)
 elif kind=='decor_a':
  rock((-.20,.12,.22),.8,5);shrub((.3,-.1,.18),.9)
  for a in [-.6,.4]:
   x=math.sin(a)*.4;branch('Garden weaving post',[(x,0,.05),(x,.05,1.35)],[.05,.045],P['wood'])
  branch('Garden string bunting',[(-.23,0,1.27),(0,-.02,1.10),(.15,.03,1.27)],[.012,.012,.012],P['brass'])
  blossom((0,-.03,1.10),.15,0,1)
 elif kind=='decor_b':
  rock((.2,.1,.20),.7,2);shrub((-.18,-.05,.14),.7)
  cylinder('Garden lantern foot',(0,0,.30),.2,.25,P['wood']);sphere('Warm garden lamp',(0,0,.67),(.22,.22,.28),P['gold']);cone('Weathered lamp cap',(0,0,.96),.28,.12,.12,P['rock'])
 objs=list(set(bpy.data.objects)-before);root=parent_all(objs,'hub_'+kind);objs.append(root);export_merged(OUT+'/hub_'+kind+'.glb',objs);return root
clear()
for i,k in enumerate(['landscape','tile','center','decor_a','decor_b']):asset(k).location=(i*18,0,0)
bpy.ops.wm.save_as_mainfile(filepath=ROOT+'/blender/hub_garden_v2.blend')

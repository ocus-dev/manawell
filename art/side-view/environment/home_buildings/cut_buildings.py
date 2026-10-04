"""Cut the Home base buildings out of their screenshots (2026-10-03).

Needs: pip install rembg opencv-python numpy pillow (uses the isnet-general-use
model). Run from this folder: first an ISNet pass writes <name>_isnet-general-use.png,
then this script refines it with GrabCut, removes sky (open and enclosed pockets),
cuts the platform off at each image's base line and writes <name>_cut.png,
centred on the image so the building stays centred when placed in-game.
Copy the results to prototype/assets/side-view/environment/home_*.png.
"""
import sys
from rembg import remove, new_session
import numpy as np, cv2
from PIL import Image

if not all(__import__('os').path.exists(f + '_isnet-general-use.png') for f in ['1_comms','2_core','3_hangar','4_turret']):
    s = new_session('isnet-general-use')
    for f in ['1_comms','2_core','3_hangar','4_turret']:
        remove(Image.open(f + '_source.png').convert('RGB'), session=s).save(f + '_isnet-general-use.png')
ys={'1_comms':712,'2_core':656,'3_hangar':651,'4_turret':650}
for f,base in ys.items():
    rgb=np.asarray(Image.open(f+'_source.png').convert('RGB'))[:base].copy()
    al=np.asarray(Image.open(f+'_isnet-general-use.png'))[:base,:,3]
    h,w=al.shape
    m=np.full((h,w),cv2.GC_PR_BGD,np.uint8)
    m[al>15]=cv2.GC_PR_FGD
    m[al>160]=cv2.GC_FGD
    hsv=cv2.cvtColor(rgb,cv2.COLOR_RGB2HSV)
    r,g,b=[rgb[...,i].astype(int) for i in range(3)]
    sky=(b>r+25)&(b>g)&(hsv[...,1]>40)&(hsv[...,2]>120)
    m[sky & (al<160)]=cv2.GC_BGD
    m[:, :3]=np.where(m[:, :3]==cv2.GC_FGD, m[:, :3], cv2.GC_BGD)
    m[:, -3:]=np.where(m[:, -3:]==cv2.GC_FGD, m[:, -3:], cv2.GC_BGD)
    bg=np.zeros((1,65)); fg=np.zeros((1,65))
    cv2.grabCut(cv2.cvtColor(rgb,cv2.COLOR_RGB2BGR),m,None,bg,fg,6,cv2.GC_INIT_WITH_MASK)
    fgm=((m==cv2.GC_FGD)|(m==cv2.GC_PR_FGD)).astype(np.uint8)
    # keep largest component, fill holes
    n,lab,st,_=cv2.connectedComponentsWithStats(fgm,8)
    keep=np.zeros_like(fgm)
    for i in range(1,n):
        if st[i,4]>800: keep[lab==i]=1
    fg=keep>0
    if f=='3_hangar':
        gate=cv2.dilate((al>15).astype(np.uint8),np.ones((25,25),np.uint8))>0
        fg&=gate; fg[:540,:140]=False; fg[:,:15]=False
    if f=='4_turret':
        fg[:,1195:]=False
    hsvf=hsv.astype(float)
    sat=hsvf[...,1]/255.0; val=hsvf[...,2]
    loosesky=(b>g+15)&(b>r+40)&(val>110)&(val<253)&(sat<0.62)&(g<0.9*b)
    open_=(~fg)|loosesky
    open_[:2,:]=True; open_[:, :2]=True; open_[:, -2:]=True
    n3,l3=cv2.connectedComponents(open_.astype(np.uint8),connectivity=4)
    border=set(np.unique(np.concatenate([l3[0,:],l3[:,0],l3[:,-1]]))) - {0}
    outside=np.isin(l3,list(border))
    full=~outside
    enc=(~fg)&full
    n4,l4,st4,_=cv2.connectedComponentsWithStats(enc.astype(np.uint8),4)
    for i in range(1,n4):
        reg=l4==i
        if st4[i,4]>150 and loosesky[reg].mean()>0.5:
            full[reg]=False
    # sky pixels inside enclosed pockets that grabcut kept
    pocket=loosesky&full
    pocket[h-40:,:]=False
    n5,l5,st5,_=cv2.connectedComponentsWithStats(pocket.astype(np.uint8),4)
    for i in range(1,n5):
        if st5[i,4]>300: full[l5==i]=False
    # keep only the main body
    n2,lab2,st2,_=cv2.connectedComponentsWithStats(full.astype(np.uint8),8)
    big=1+np.argmax(st2[1:,4]); full=lab2==big
    a=cv2.GaussianBlur(full.astype(np.float32),(3,3),0)
    out=np.dstack([rgb,(a*255).astype(np.uint8)])
    img=Image.fromarray(out)
    l,t,r,btm=img.getbbox()
    half=max(w/2-l, r-w/2)
    cx=w/2
    img=img.crop((int(cx-half),t,int(np.ceil(cx+half)),h))
    img.save(f+'_cut.png')
    print(f, Image.fromarray(out).getbbox())

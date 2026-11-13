from PIL import Image, ImageDraw, ImageFilter
import math, random
S=4; N=256*S
random.seed(7)
def P(v): return int(v*S)
img=Image.new("RGBA",(N,N),(0,0,0,0)); d=ImageDraw.Draw(img)
C=128
INK=(20,12,8,255)
def circ(r,fill,outline=None,w=0,cx=C,cy=C):
    d.ellipse([P(cx-r),P(cy-r),P(cx+r),P(cy+r)],fill=fill,outline=outline,width=P(w))
circ(120,(104,66,34,255),INK,5)
circ(108,(138,92,48,255))
for i in range(40):
    a=random.uniform(0,6.283); r=random.uniform(100,114)
    x=C+r*math.cos(a); y=C+r*math.sin(a)
    d.arc([P(x-6),P(y-6),P(x+6),P(y+6)],a*57,a*57+70,fill=(86,52,26,255),width=P(1.2))
circ(98,(40,28,22,255),INK,5)
inner=Image.new("RGBA",(N,N),(0,0,0,0)); di=ImageDraw.Draw(inner)
for i in range(60):
    t=i/59; r=94*(1-t)
    col=(int(32+50*t),int(28+40*t),int(44+30*t),255)
    di.ellipse([P(C-r),P(C-r),P(C+r),P(C+r)],fill=col)
img.alpha_composite(inner)
gl=Image.new("RGBA",(N,N),(0,0,0,0)); dg=ImageDraw.Draw(gl)
dg.ellipse([P(C-62),P(C-70),P(C+62),P(C+56)],fill=(214,190,140,70))
gl=gl.filter(ImageFilter.GaussianBlur(P(10))); img.alpha_composite(gl); d=ImageDraw.Draw(img)
SIL=(22,20,30,255); RIM=(70,62,90,255)
def blob(pts,fill=SIL):
    d.polygon([(P(x),P(y)) for x,y in pts],fill=fill,outline=INK,width=P(2.5))
d.ellipse([P(70),P(158),P(186),P(192)],fill=SIL,outline=INK,width=P(3))
d.ellipse([P(88),P(166),P(168),P(196)],fill=(30,27,40,255),outline=INK,width=P(2.5))
blob([(100,112),(156,112),(166,160),(90,160)])
d.ellipse([P(104),P(124),P(152),P(168)],fill=SIL,outline=INK,width=P(3))
d.ellipse([P(113),P(130),P(143),P(160)],fill=(10,8,14,255),outline=INK,width=P(2))
d.ellipse([P(98),P(100),P(158),P(126)],fill=SIL,outline=INK,width=P(2.5))
d.ellipse([P(112),P(68),P(144),P(104)],fill=SIL,outline=INK,width=P(3))
d.ellipse([P(121),P(54),P(135),P(70)],fill=SIL,outline=INK,width=P(2.5))
d.line([P(116),P(80),P(140),P(80)],fill=(170,40,40,255),width=P(3))
d.arc([P(112),P(68),P(144),P(104)],200,290,fill=RIM,width=P(2))
d.arc([P(98),P(100),P(158),P(126)],200,280,fill=RIM,width=P(2))
# crescent moon (Co Nguyet) on the ring top
def crescent(box_out,box_cut,fill):
    m=Image.new("L",(N,N),0); dm=ImageDraw.Draw(m)
    dm.ellipse([P(v) for v in box_out],fill=255); dm.ellipse([P(v) for v in box_cut],fill=0)
    l=Image.new("RGBA",(N,N),fill); l.putalpha(m); return l
img.alpha_composite(crescent((104,2,148,46),(118,-2,160,42),INK))
img.alpha_composite(crescent((108,6,145,43),(121,2,157,39),(160,220,255,255)))
d=ImageDraw.Draw(img)
def gu(cx,cy,ang,col):
    for k in (-1,0,1):
        for s in (-1,1):
            x1=cx+k*4*math.cos(ang); y1=cy+k*4*math.sin(ang)
            x2=x1+s*7*math.cos(ang+1.57)+k*2; y2=y1+s*7*math.sin(ang+1.57)
            d.line([P(x1),P(y1),P(x2),P(y2)],fill=INK,width=P(1.6))
    d.ellipse([P(cx-9),P(cy-5),P(cx+9),P(cy+5)],fill=col,outline=INK,width=P(1.8))
    d.ellipse([P(cx+6),P(cy-3),P(cx+12),P(cy+3)],fill=col,outline=INK,width=P(1.4))
gu(74,128,0.3,(88,190,150,255)); gu(182,122,-0.3,(88,190,150,255))
SEA=(120,170,190,255)
for sx in (-1,1):
    cx=C+sx*34
    d.arc([P(cx-24),P(196),P(cx+24),P(224)],0,300,fill=SEA,width=P(3))
    d.arc([P(cx-14),P(202),P(cx+14),P(218)],0,300,fill=SEA,width=P(2.2))
d.arc([P(70),P(204),P(186),P(240)],25,155,fill=SEA,width=P(3))
img=img.resize((256,256),Image.LANCZOS)
img.save("images/cosu_badge.png")
g=Image.new("RGBA",(64,64),(0,0,0,0)); px=g.load()
for y in range(64):
    for x in range(64):
        r=math.hypot(x-31.5,y-31.5)/32
        px[x,y]=(255,255,255,int(255*max(0,1-r)**1.6))
g.save("images/cosu_glow.png")
bg=Image.new("RGBA",(256,256),(60,60,60,255)); bg.alpha_composite(img)
og=g.resize((48,48)); tint=Image.new("RGBA",(48,48),(155,93,229,255)); tint.putalpha(og.split()[3])
bg.alpha_composite(tint,(104,118))
bg.resize((512,512),Image.LANCZOS).save("art_src/preview.png")

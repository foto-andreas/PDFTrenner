#!/usr/bin/env python3
import svgwrite

dwg = svgwrite.Drawing('workflow.svg', size=('560px', '1520px'), viewBox='0 0 560 1520')
dwg.add_stylesheet('''\
    text { font-family: -apple-system, "Helvetica Neue", Helvetica, Arial, sans-serif; }
    .box rect { rx: 8; ry: 8; }
    .diamond { fill: #fff3cd; stroke: #856404; stroke-width: 1.5; }
    .start rect { fill: #4a9eff; stroke: #2d7dd2; }
    .start text { fill: white; }
    .ocr rect { fill: #ff9f43; stroke: #e08630; }
    .ocr text { fill: white; }
    .title rect { fill: #ff6b6b; stroke: #e05555; }
    .title text { fill: white; }
    .output rect { fill: #2ed573; stroke: '#20c05a'; }
    .output text { fill: white; }
    .end rect { fill: #ffa502; stroke: #e09002; }
    .end text { fill: white; }
''', 'styles')

arrow_props = {'stroke': '#555', 'stroke-width': '2', 'fill': 'none', 'marker-end': dwg.defs.add(dwg.marker(insert=('10','10'), size=('10','10'), refX='10', refY='10', orient='auto')).add(dwg.path('M 0 0 L 10 5 L 0 10 z', fill='#555')))}

def arrow(x1, y1, x2, y2, label=None):
    line = dwg.line(start=(x1, y1), end=(x2, y2), **arrow_props)
    dwg.add(line)
    if label:
        mx, my = (x1+x2)//2, (y1+y2)//2
        if x1 != x2:
            mx += 0
            my -= 10
        t = dwg.text(label, insert=(mx, my), font_size='11px', fill='#555', text_anchor='middle', dominant_baseline='auto')
        dwg.add(t)

def box(x, y, w, h, lines, cls=''):
    g = dwg.g(class_=f'box {cls}'.strip())
    rect = dwg.rect(insert=(x, y), size=(w, h), **{'class': f'box {cls}'.strip().replace('.','')})
    # Apply fill via style
    style_map = {
        'start': {'fill': '#4a9eff', 'stroke': '#2d7dd2'},
        'ocr': {'fill': '#ff9f43', 'stroke': '#e08630'},
        'title': {'fill': '#ff6b6b', 'stroke': '#e05555'},
        'output': {'fill': '#2ed573', 'stroke': '#20c05a'},
        'end': {'fill': '#ffa502', 'stroke': '#e09002'},
        'normal': {'fill': '#f8f9fa', 'stroke': '#adb5bd'},
    }
    s = style_map.get(cls, style_map['normal'])
    rect = dwg.rect(insert=(x, y), size=(w, h), rx=8, ry=8, fill=s['fill'], stroke=s['stroke'], stroke_width=1.5)
    g.add(rect)
    text_color = 'white' if cls in ('start','ocr','title','output','end') else '#222'
    line_height = 18
    start_y_text = y + h//2 - (len(lines)-1) * line_height // 2
    for i, line in enumerate(lines):
        t = dwg.text(line, insert=(x + w//2, start_y_text + i * line_height + 5),
                      font_size='13px' if len(line) > 20 else '14px',
                      fill=text_color, text_anchor='middle', font_weight='bold' if cls else 'normal')
        g.add(t)
    dwg.add(g)
    return y + h  # bottom y

def diamond(cx, cy, w, h, lines, label_top=None):
    pts = [(cx, cy - h//2), (cx + w//2, cy), (cx, cy + h//2), (cx - w//2, cy)]
    poly = dwg.polygon(pts, fill='#fff3cd', stroke='#856404', stroke_width=1.5)
    dwg.add(poly)
    line_height = 17
    start_y_text = cy - (len(lines)-1) * line_height // 2
    for i, line in enumerate(lines):
        t = dwg.text(line, insert=(cx, start_y_text + i * line_height + 5),
                      font_size='12px', fill='#664d03', text_anchor='middle')
        dwg.add(t)

CX = 260
cur_y = 30

# A: PDF öffnen
bot_a = 90
box(CX-120, 30, 240, 60, ['PDF öffnen'], 'start')
arrow(CX, 90, CX, 120)

# B: PDF laden und anzeigen
box(CX-120, 120, 240, 50, ['PDF laden & anzeigen'], 'normal')
arrow(CX, 170, CX, 200)

# C: Blättern
box(CX-120, 200, 240, 50, ['Blättern ◀ / ▶'], 'normal')
arrow(CX, 250, CX, 285)

# D: Taste oder Button (diamond)
diamond(CX, 335, 180, 90, ['Taste /', 'Button'])
# back arrow to C
arrow(CX-90, 335, CX-130, 225, '◀ / ▶')
# forward arrow
arrow(CX+90, 335, CX+140, 380, 'F')

# E: Startseite festlegen
box(CX-120, 380, 240, 50, ['Startseite festlegen'], 'normal')
arrow(CX, 430, CX, 460)

# F: Titeleingabe
box(CX-120, 460, 240, 60, ['Titeleingabe', '(OCR-Vorschlag)'], 'title')
# Abbrechen arrow back to Blättern
arrow(CX+120, 490, CX+160, 225, '')
dwg.add(dwg.text('Abbrechen', insert=(CX+165, 350), font_size='11px', fill='#555', text_anchor='start'))
# OK arrow
arrow(CX, 520, CX, 555)
dwg.add(dwg.text('OK', insert=(CX+10, 545), font_size='11px', fill='#555', text_anchor='start'))

# G: Zur Endseite blättern
box(CX-120, 555, 240, 50, ['Zur Endseite blättern'], 'normal')
arrow(CX, 605, CX, 640)
dwg.add(dwg.text('L', insert=(CX+10, 630), font_size='11px', fill='#555', text_anchor='start'))

# H: Endseite festlegen
box(CX-120, 640, 240, 50, ['Endseite festlegen'], 'normal')
arrow(CX, 690, CX, 720)

# I: Abschnitt speichern
box(CX-120, 720, 240, 50, ['Abschnitt speichern'], 'normal')

# Branches from I
arrow(CX-60, 770, 110, 810)  # left
arrow(CX, 770, CX, 810)      # center
arrow(CX+60, 770, CX+160, 810) # right

# J: PDF-Datei
box(10, 810, 200, 60, ['PDF-Datei im', 'Ordner Manual_Splits'], 'output')
# K: Fortschritt merken
box(CX-100, 810, 200, 50, ['Fortschritt merken'], 'normal')
# L: Noch Seiten? (diamond)
diamond(CX+160, 850, 160, 80, ['Noch Seiten', 'übrig?'])

# Branch from diamond
arrow(CX+240, 850, CX+300, 850, 'Ja')  
# Arrow from "Ja" back up to Startseite
# Draw a long right-side curve back up
dwg.add(dwg.line(start=(CX+300, 850), end=(CX+300, 405), **{'stroke': '#555', 'stroke-width': '2', 'stroke_dasharray': '5,3'}))
dwg.add(dwg.line(start=(CX+300, 405), end=(CX+120, 405), **{'stroke': '#555', 'stroke-width': '2', 'stroke_dasharray': '5,3'}))
# arrowhead on dashed line
dwg.add(dwg.polygon([(CX+120, 405), (CX+130, 400), (CX+130, 410)], fill='#555'))

# Nein arrow down
arrow(CX+160, 890, CX+160, 940, 'Nein')

# M: Fertig
box(CX+60, 940, 200, 50, ['Fertig'], 'end')

dwg.save()
print('Created workflow.svg')
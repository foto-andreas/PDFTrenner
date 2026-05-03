#!/usr/bin/env python3
import base64
import os

import cairosvg
import markdown

SVG_PATH = '/Users/andreas/Workspace/PDFTrenner/PDFTrennerSwift/workflow.svg'
with open(SVG_PATH, 'r', encoding='utf-8') as f:
    SVG_CONTENT = f.read()

PNG_CONTENT = cairosvg.svg2png(bytestring=SVG_CONTENT.encode('utf-8'))
PNG_B64 = base64.b64encode(PNG_CONTENT).decode('ascii')

HTML_TEMPLATE = '''<!DOCTYPE html>
<html lang="de"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{title}</title>
<style>
body {{ font-family: -apple-system,"Helvetica Neue",Helvetica,Arial,sans-serif; font-size: 15px; line-height: 1.6; color: #222; max-width: 820px; margin: 0 auto; padding: 24px 16px; background: #fff; }}
h1 {{ font-size: 28px; border-bottom: 2px solid #4a9eff; padding-bottom: 8px; margin-top: 0; color: #1a1a1a; }}
h2 {{ font-size: 20px; color: #333; margin-top: 28px; margin-bottom: 8px; border-bottom: 1px solid #ddd; padding-bottom: 4px; }}
h3 {{ font-size: 17px; color: #444; margin-top: 20px; }}
table {{ border-collapse: collapse; width: 100%; margin: 12px 0; font-size: 14px; }}
th, td {{ border: 1px solid #ccc; padding: 6px 10px; text-align: left; vertical-align: top; }}
th {{ background-color: #f0f4f8; font-weight: bold; }}
tr:nth-child(even) {{ background-color: #fafafa; }}
code {{ background-color: #f4f4f4; padding: 2px 5px; border-radius: 3px; font-family: "SF Mono","Menlo","Monaco",monospace; font-size: 13px; }}
pre {{ background-color: #f4f4f4; padding: 12px; border-radius: 4px; overflow-x: auto; font-size: 13px; line-height: 1.5; }}
pre code {{ background: none; padding: 0; }}
strong, b {{ color: #1a1a1a; }}
p {{ margin: 6px 0; }}
ul, ol {{ margin: 4px 0; padding-left: 20px; }}
li {{ margin: 3px 0; }}
</style></head><body>{body}</body></html>'''

WORKFLOW_INLINE = f'<img src="data:image/png;base64,{PNG_B64}" alt="Workflow-Diagramm" style="max-width:100%;height:auto;display:block;margin:16px auto;border:1px solid #e0e0e0;border-radius:4px;">'

def convert(md_path, title):
    with open(md_path, 'r', encoding='utf-8') as f:
        md_content = f.read()
    md_content_with_svg = md_content.replace('![Workflow-Diagramm](workflow.svg)', WORKFLOW_INLINE).replace('![Datenfluss-Diagramm](workflow.svg)', WORKFLOW_INLINE)
    html_body = markdown.markdown(md_content_with_svg, extensions=['tables','fenced_code','codehilite'],
        extension_configs={'codehilite':{'guess_lang':False}})
    full_html = HTML_TEMPLATE.format(title=title, body=html_body)
    stem = os.path.splitext(md_path)[0]
    with open(stem + '.html', 'w', encoding='utf-8') as f:
        f.write(full_html)
    print(f'Created: {stem}.html')

base = '/Users/andreas/Workspace/PDFTrenner/PDFTrennerSwift'
convert(os.path.join(base, 'BENUTZERDOKU.md'), 'PDFTrenner — Benutzerdokumentation')
convert(os.path.join(base, 'SYSTEMDOKU.md'), 'PDFTrenner — Systemdokumentation')

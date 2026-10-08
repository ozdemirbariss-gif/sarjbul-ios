#!/usr/bin/env python3
"""Render the reviewed Markdown documents as a dependency-free public website."""
import argparse
import html
import re
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]
SITE_URL = "https://ozdemirbariss-gif.github.io/sarjbul-ios"
BASE_PATH = urlsplit(SITE_URL).path.rstrip("/")
PAGES = {
    "PRIVACY_POLICY.md": ("privacy", "Gizlilik politikası"),
    "TERMS_OF_USE.md": ("terms", "Kullanım koşulları"),
    "SUPPORT.md": ("support", "Destek / Support"),
}
CSS = """
:root{color-scheme:light;--ink:#172b29;--muted:#526662;--green:#126657;--line:#dbe5e1}
*{box-sizing:border-box}html{scroll-behavior:smooth}body{margin:0;color:var(--ink);background:#f6f8f5;font:17px/1.75 system-ui,-apple-system,sans-serif}
a{color:var(--green);text-underline-offset:4px;overflow-wrap:anywhere}a:focus-visible{outline:3px solid #dca426;outline-offset:5px}
header{border-bottom:1px solid var(--line);background:#fff}header>div,main,footer{max-width:900px;margin:auto;padding:24px 28px}
header>div{display:flex;gap:24px;align-items:center;justify-content:space-between;flex-wrap:wrap}.brand{font-size:25px;font-weight:750;text-decoration:none;letter-spacing:-1px}
nav{display:flex;gap:22px;flex-wrap:wrap;font-size:15px}nav a[aria-current=page]{font-weight:750}main{padding-top:48px;padding-bottom:60px;min-height:65vh}
article{padding:40px;background:white;border:1px solid var(--line);border-radius:18px}h1{font-size:clamp(28px,5vw,39px);line-height:1.2;letter-spacing:-1px;margin:0 0 24px}h2{font-size:23px;line-height:1.3;margin:38px 0 15px}
p{margin:0 0 20px}li{margin-bottom:12px}ul{padding-left:25px}code{font-size:.9em}footer{border-top:1px solid var(--line);font-size:14px;color:var(--muted)}
.eyebrow{font-size:13px;letter-spacing:2px;font-weight:700;color:var(--green);margin-bottom:12px}.skip{position:absolute;left:-10000px}.skip:focus{left:16px;top:16px;background:white;padding:12px;z-index:2}
@media(max-width:600px){header>div,main,footer{padding-left:18px;padding-right:18px}main{padding-top:24px}article{padding:24px 20px}nav{gap:12px;font-size:14px}}
"""


def site_path(path=""):
    return BASE_PATH + "/" + path.lstrip("/")


def inline(text):
    value = html.escape(text)
    def link(match):
        label, target = match.groups()
        if target in PAGES:
            target = site_path(PAGES[target][0] + "/")
        elif target.endswith(".md") and not target.startswith("https://"):
            target = "https://github.com/ozdemirbariss-gif/sarjbul-ios/blob/main/Docs/" + target
        if not target.startswith(("https://", "mailto:", "/")):
            raise ValueError("Unsupported link target")
        return f'<a href="{target}">{label}</a>'
    value = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", link, value)
    value = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", value)
    return re.sub(r"`([^`]+)`", r"<code>\1</code>", value)


def markdown(text):
    blocks = []
    for block in re.split(r"\n\s*\n", text.strip()):
        lines = block.splitlines()
        if len(lines) == 1 and (match := re.fullmatch(r"(#{1,2}) (.+)", lines[0])):
            level = len(match[1])
            blocks.append(f"<h{level}>{inline(match[2])}</h{level}>")
        elif all(line.startswith("- ") for line in lines):
            blocks.append("<ul>" + "".join(f"<li>{inline(line[2:])}</li>" for line in lines) + "</ul>")
        else:
            blocks.append("<p>" + inline(" ".join(lines)) + "</p>")
    return "\n".join(blocks)


def page(slug, title, body):
    nav = "".join(f'<a href="{site_path(path + "/")}"' + (' aria-current="page"' if path == slug else '') + f'>{label}</a>' for path, label in PAGES.values())
    return f'''<!doctype html>
<html lang="tr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{html.escape(title)} — ŞarjBul</title><meta name="description" content="ŞarjBul gizlilik politikası, kullanım koşulları ve destek iletişim bilgileri.">
<link rel="canonical" href="{SITE_URL}/{slug + '/' if slug else ''}"><link rel="stylesheet" href="{site_path('style.css')}"></head>
<body><a class="skip" href="#content">İçeriğe geç</a><header><div><a class="brand" href="{site_path()}">ŞarjBul<span aria-hidden="true"> ↗</span></a><nav aria-label="Belgeler">{nav}</nav></div></header>
<main id="content"><p class="eyebrow">ŞARJBUL · YARDIM VE BİLGİLENDİRME</p><article>{body}</article></main>
<footer>ŞarjBul · İletişim: <a href="mailto:sarjbul@icloud.com">sarjbul@icloud.com</a><br>Destek ve gizlilik talepleriniz için bize e-posta gönderebilirsiniz.</footer></body></html>'''


def build(output):
    output.mkdir(parents=True, exist_ok=True)
    (output / "style.css").write_text(CSS, encoding="utf-8")
    for filename, (slug, title) in PAGES.items():
        directory = output / slug
        directory.mkdir(exist_ok=True)
        content = markdown((ROOT / "Docs" / filename).read_text(encoding="utf-8"))
        (directory / "index.html").write_text(page(slug, title, content), encoding="utf-8")
    intro = '<h1>ŞarjBul yardım ve belgeler</h1><p>Uygulama desteği, istasyon verisi düzeltmeleri ve gizlilik talepleri için <a href="mailto:sarjbul@icloud.com">sarjbul@icloud.com</a> adresine yazabilirsiniz.</p><ul>'
    intro += "".join(f'<li><a href="{site_path(slug + "/")}">{title}</a></li>' for slug, title in PAGES.values()) + '</ul><p>Bu sayfalara hesap oluşturmadan erişebilirsiniz.</p>'
    (output / "index.html").write_text(page("", "Yardım ve belgeler", intro), encoding="utf-8")
    (output / "404.html").write_text(page("", "Sayfa bulunamadı", f'<h1>Sayfa bulunamadı</h1><p><a href="{site_path()}">Yardım ve belgelere dön</a></p>'), encoding="utf-8")
    (output / "robots.txt").write_text("User-agent: *\nAllow: /\n", encoding="utf-8")
    print(f"Built {len(PAGES)} public documents in {output}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    build(parser.parse_args().output)

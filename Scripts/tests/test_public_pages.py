import sys
import tempfile
import unittest
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlsplit

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from build_public_pages import BASE_PATH, SITE_URL, build


class Links(HTMLParser):
    def __init__(self):
        super().__init__()
        self.targets = []
        self.canonical = None

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag in ("a", "link") and "href" in attrs:
            self.targets.append(attrs["href"])
        if tag == "link" and attrs.get("rel") == "canonical":
            self.canonical = attrs["href"]


class PublicPagesTests(unittest.TestCase):
    def test_project_site_links_resolve_and_do_not_expose_old_hosting(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            build(output)
            for page in output.rglob("*.html"):
                content = page.read_text()
                self.assertNotRegex(content.lower(), r"chatgpt|codex|openai")
                self.assertIn("sarjbul@icloud.com", content)
                links = Links()
                links.feed(content)
                self.assertTrue(links.canonical.startswith(SITE_URL + "/"))
                for target in links.targets:
                    if not target.startswith("/"):
                        continue
                    self.assertTrue(target.startswith(BASE_PATH + "/"), target)
                    relative = urlsplit(target).path.removeprefix(BASE_PATH + "/")
                    local = output / relative
                    if local.is_dir():
                        local /= "index.html"
                    self.assertTrue(local.is_file(), f"{page}: {target}")
            self.assertIn("GitHub Pages", (output / "privacy/index.html").read_text())


if __name__ == "__main__":
    unittest.main()

"""Check rendered documentation links, anchors and headings without network access."""

from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit
import sys


class Page(HTMLParser):
    def __init__(self, path):
        super().__init__()
        self.ids = set()
        self.links = []
        self.headings = 0
        self.feed(path.read_text())

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if "id" in attrs:
            self.ids.add(attrs["id"])
        if tag == "h1":
            self.headings += 1
        if tag == "a" and "href" in attrs:
            self.links.append(attrs["href"])


def check(root):
    pages = {path.resolve(): Page(path) for path in root.rglob("*.html")}
    errors = []
    for path, page in pages.items():
        if page.headings != 1:
            errors.append(f"{path.relative_to(root)}: expected one page heading, got {page.headings}")
        for href in page.links:
            url = urlsplit(href)
            if url.scheme or url.netloc:
                continue
            target = unquote(url.path)
            # The site is built for GitHub Pages' repository subpath.
            if target.startswith("/Pi-Bolt.nix/"):
                target = target.removeprefix("/Pi-Bolt.nix/")
                dest = root / target
            elif target == "/Pi-Bolt.nix":
                dest = root
            elif target.startswith("/"):
                errors.append(f"{path.relative_to(root)}: link escapes site base: {href}")
                continue
            else:
                dest = path.parent / target if target else path
            if dest.is_dir():
                dest /= "index.html"
            dest = dest.resolve()
            if not dest.is_file():
                errors.append(f"{path.relative_to(root)}: missing target: {href}")
            elif url.fragment and dest in pages and unquote(url.fragment) not in pages[dest].ids:
                errors.append(f"{path.relative_to(root)}: missing anchor: {href}")
    if not pages or not (root / "pagefind/pagefind.js").is_file():
        errors.append("The built site or its local search index is missing")
    if errors:
        raise SystemExit("\n".join(errors))
    print(f"Checked links, anchors and headings in {len(pages)} pages; local search is present")


if __name__ == "__main__":
    check(Path(sys.argv[1]).resolve())

"""Bing Images HTML scraper. No API key. Different result distribution
than DDG."""
from __future__ import annotations

import html as html_lib
import re
import urllib.parse

import requests

from sources import Candidate, is_clean_url

NAME = "bing"
PRIOR = 0.6
USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"


def _query(item: dict) -> str:
    parts = [item.get("brand"), item.get("model"), item.get("itemName")]
    return " ".join([p for p in parts if p]) + " medical equipment product photo"


class _BingProvider:
    name = NAME
    prior = PRIOR

    def search(self, item: dict, k: int = 8) -> list[Candidate]:
        q = _query(item)
        brand = (item.get("brand") or "").lower()
        # Bing image search HTML page — `&form=HDRSC2` biases results to
        # higher-resolution photos.
        url = "https://www.bing.com/images/search?" + urllib.parse.urlencode({
            "q": q,
            "form": "HDRSC2",
            "first": "1",
        })
        try:
            r = requests.get(
                url,
                headers={"User-Agent": USER_AGENT, "Accept-Language": "en-US,en;q=0.9"},
                timeout=10,
            )
            if r.status_code != 200:
                return []
            html = r.text
        except Exception:
            return []

        # Bing now embeds candidate JSON payloads inside HTML-entity-encoded
        # blobs ("&quot;murl&quot;:..."). Decode entities then look for both
        # variants — the raw form may still appear in some response shapes.
        decoded = html_lib.unescape(html)
        out: list[Candidate] = []
        seen = set()
        for m in re.finditer(r'"murl":"(https?:[^"]+)"', decoded):
            raw = m.group(1).replace("\\/", "/")
            if raw in seen or not is_clean_url(raw):
                continue
            seen.add(raw)
            out.append(Candidate(
                url=raw, provider=NAME, prior=PRIOR,
                hint_brand=brand and brand.split()[0] in raw.lower(),
            ))
            if len(out) >= k:
                break
        return out


provider = _BingProvider()

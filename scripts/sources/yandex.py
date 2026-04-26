"""Yandex Images scraper. Often surfaces clean industrial-equipment renders
that DDG and Bing miss, especially for European brands (Siemens, Drager,
Aesculap)."""
from __future__ import annotations

import re
import urllib.parse

import requests

from sources import Candidate, is_clean_url

NAME = "yandex"
PRIOR = 0.5
USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"


def _query(item: dict) -> str:
    parts = [item.get("brand"), item.get("model"), item.get("itemName")]
    return " ".join([p for p in parts if p])


class _YandexProvider:
    name = NAME
    prior = PRIOR

    def search(self, item: dict, k: int = 8) -> list[Candidate]:
        q = _query(item)
        brand = (item.get("brand") or "").lower()
        url = "https://yandex.com/images/search?" + urllib.parse.urlencode({
            "text": q,
            "isize": "large",
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

        out: list[Candidate] = []
        seen = set()
        # Yandex packs original image URLs into JSON-encoded data-bem attrs
        # like "img_href":"https://example.com/foo.jpg".
        for m in re.finditer(r'"img_href":"(https?:[^"]+)"', html):
            raw = m.group(1).replace("\\/", "/").replace("\\u0026", "&")
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


provider = _YandexProvider()

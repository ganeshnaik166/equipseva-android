"""Wikimedia Commons API — free CC-licensed photos.

High signal for category-level photos (MRI scanner, defibrillator,
ventilator); low signal for specific brand/model. Used as a fallback +
attribution-friendly source.
"""
from __future__ import annotations

import urllib.parse

import requests

from sources import Candidate, is_clean_url

NAME = "wikimedia"
PRIOR = 0.7
USER_AGENT = "EquipSevaCatalogBot/1.0 (https://equipseva.com; contact@equipseva.com)"


def _query(item: dict) -> str:
    return " ".join(filter(None, [
        item.get("brand"),
        item.get("model"),
        item.get("itemName"),
    ]))


class _WikimediaProvider:
    name = NAME
    prior = PRIOR

    def search(self, item: dict, k: int = 8) -> list[Candidate]:
        q = _query(item)
        brand = (item.get("brand") or "").lower()
        # 1) Search Commons for matching files.
        params = {
            "action": "query",
            "format": "json",
            "list": "search",
            "srsearch": f"{q} filetype:bitmap",
            "srlimit": str(k),
            "srnamespace": "6",  # File namespace
        }
        try:
            r = requests.get(
                "https://commons.wikimedia.org/w/api.php",
                params=params,
                headers={"User-Agent": USER_AGENT},
                timeout=10,
            )
            if r.status_code != 200:
                return []
            results = r.json().get("query", {}).get("search", [])
        except Exception:
            return []

        if not results:
            return []

        # 2) Resolve titles → original-resolution URLs in one batched call.
        titles = "|".join(r["title"] for r in results)
        try:
            ri = requests.get(
                "https://commons.wikimedia.org/w/api.php",
                params={
                    "action": "query",
                    "format": "json",
                    "prop": "imageinfo",
                    "iiprop": "url|size",
                    "titles": titles,
                },
                headers={"User-Agent": USER_AGENT},
                timeout=10,
            )
            pages = ri.json().get("query", {}).get("pages", {})
        except Exception:
            return []

        out: list[Candidate] = []
        for page in pages.values():
            ii = (page.get("imageinfo") or [{}])[0]
            url = ii.get("url")
            if not url or not is_clean_url(url):
                continue
            out.append(Candidate(
                url=url, provider=NAME, prior=PRIOR,
                hint_brand=brand and brand.split()[0] in url.lower(),
            ))
            if len(out) >= k:
                break
        return out


provider = _WikimediaProvider()

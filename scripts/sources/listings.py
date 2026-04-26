"""Used / refurbished medical-equipment marketplaces — DotMed, MedWrench,
EquipNet, GovDeals. All accessed via DDG site:domain image search.

Purpose: thousands of real-world product photos of older/refurbished
units that the manufacturer's marketing CDN won't surface. Especially
useful for end-of-life and refurbished SKUs in our catalogue.
"""
from __future__ import annotations

import time

from sources import Candidate, is_clean_url, ddg_throttle, ddg_release

NAME = "listings"
PRIOR = 0.65

_DOMAINS = (
    "dotmed.com",
    "medwrench.com",
    "equipnet.com",
    "govdeals.com",
)


def _query(item: dict, domain: str) -> str:
    parts = [item.get("brand"), item.get("model"), item.get("itemName")]
    return " ".join([p for p in parts if p]) + f" site:{domain}"


class _ListingsProvider:
    name = NAME
    prior = PRIOR

    def search(self, item: dict, k: int = 8) -> list[Candidate]:
        from duckduckgo_search import DDGS
        brand = (item.get("brand") or "").lower()
        out: list[Candidate] = []
        for domain in _DOMAINS:
            ddg_throttle()
            try:
                with DDGS() as ddgs:
                    results = list(ddgs.images(_query(item, domain), max_results=4, safesearch="off"))
            except Exception:
                ddg_release()
                time.sleep(2)
                continue
            ddg_release()
            for r in results:
                url = r.get("image")
                if not url or not is_clean_url(url):
                    continue
                out.append(Candidate(
                    url=url, provider=NAME, prior=PRIOR,
                    hint_brand=brand and brand.split()[0] in url.lower(),
                ))
                if len(out) >= k:
                    return out
        return out


provider = _ListingsProvider()

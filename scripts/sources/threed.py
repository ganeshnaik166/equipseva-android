"""3D model render galleries (CGTrader, TurboSquid, Sketchfab).

Last-resort fallback because rendered models ≠ photos and could mislead
buyers. We weight this source low (prior=0.4) so CLIP picks an actual
photo whenever one exists; the 3D render only wins when nothing else
clears the threshold AND the render's CLIP score is strong.
"""
from __future__ import annotations

import time

from sources import Candidate, is_clean_url, ddg_throttle, ddg_release

NAME = "threed"
PRIOR = 0.4

_DOMAINS = (
    "cgtrader.com",
    "turbosquid.com",
    "sketchfab.com",
    "free3d.com",
)


def _query(item: dict, domain: str) -> str:
    parts = [item.get("brand"), item.get("model"), item.get("itemName")]
    return " ".join([p for p in parts if p]) + f" 3d model site:{domain}"


class _ThreedProvider:
    name = NAME
    prior = PRIOR

    def search(self, item: dict, k: int = 6) -> list[Candidate]:
        from duckduckgo_search import DDGS
        brand = (item.get("brand") or "").lower()
        out: list[Candidate] = []
        for domain in _DOMAINS:
            ddg_throttle()
            try:
                with DDGS() as ddgs:
                    results = list(ddgs.images(_query(item, domain), max_results=3, safesearch="off"))
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


provider = _ThreedProvider()

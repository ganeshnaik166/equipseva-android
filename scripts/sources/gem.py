"""GeM (Government e-Marketplace) — public JSON catalog API.

Recon already done: every category page has a sibling `<slug>/search.json`
endpoint that returns up to ~9 catalog rows per query, each with a clean
`img_url` on `assets-mkpbg.gem.gov.in/img/...`. No auth required.

Strategy: do a category-search by brand+model. If we find a row whose
`brand` field matches our item's brand (case-insensitive), use its image.
"""
from __future__ import annotations

import urllib.parse

import requests

from sources import Candidate, is_clean_url

NAME = "gem"
PRIOR = 0.9
USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"


# Map our 6 catalog categories → the deepest GeM category slug we know to
# work for that bucket. Got these by manually probing gem.gov.in. Falls
# back to the global keyword-search endpoint if no mapping exists.
_CATEGORY_TO_GEM_SLUG = {
    "Imaging": "medical-equipments-and-accessories-supplies-medical-diagnostic-imaging-and-nuclear-medicine-products",
    "ICU & Critical Care": "medical-equipment-and-supplies",
    "Surgical & OR": "medical-equipment-and-supplies",
    "Laboratory": "laboratory-equipment-and-supplies",
    "Ward & Allied": "medical-equipment-and-supplies",
    "Spare Parts & Consumables": "medical-equipment-and-supplies",
}


def _build_url(item: dict) -> str:
    slug = _CATEGORY_TO_GEM_SLUG.get(item.get("category", ""), "medical-equipment-and-supplies")
    q = " ".join(filter(None, [item.get("brand"), item.get("model")])) \
        or item.get("itemName", "")
    return f"https://mkp.gem.gov.in/{slug}/search.json?" + urllib.parse.urlencode({"q": q})


class _GemProvider:
    name = NAME
    prior = PRIOR

    def search(self, item: dict, k: int = 8) -> list[Candidate]:
        url = _build_url(item)
        try:
            r = requests.get(url, headers={
                "User-Agent": USER_AGENT,
                "X-Requested-With": "XMLHttpRequest",
                "Accept": "application/json",
            }, timeout=10)
            if r.status_code != 200:
                return []
            data = r.json()
        except Exception:
            return []

        catalogs = data.get("catalogs") or []
        brand = (item.get("brand") or "").lower()
        out: list[Candidate] = []
        for c in catalogs[:k * 2]:
            img = c.get("img_url")
            if not img or not is_clean_url(img):
                continue
            row_brand = (c.get("brand") or "").lower()
            # Strong signal: GeM row's brand contains our brand prefix.
            brand_match = bool(brand) and (
                brand.split()[0] in row_brand or row_brand.split()[0] in brand
            )
            out.append(Candidate(
                url=img,
                provider=NAME,
                prior=PRIOR if brand_match else PRIOR * 0.6,
                hint_brand=brand_match,
            ))
            if len(out) >= k:
                break
        return out


provider = _GemProvider()

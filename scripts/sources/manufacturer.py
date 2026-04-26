"""Manufacturer asset CDN direct hit.

For each known brand we restrict a DDG image search with `site:<domain>`
so the result is guaranteed manufacturer-official. Highest trust source
when the brand is one we recognize.
"""
from __future__ import annotations

import time

from sources import Candidate, is_clean_url, ddg_throttle, ddg_release

NAME = "manufacturer"
PRIOR = 1.0


# brand-name (lower, prefix-match) → list of trusted asset domains
_BRAND_DOMAINS: dict[str, list[str]] = {
    "ge healthcare":          ["gehealthcare.com"],
    "ge":                     ["gehealthcare.com"],
    "siemens":                ["siemens-healthineers.com", "marketing.webassets.siemens-healthineers.com"],
    "philips":                ["images.philips.com", "philips.com"],
    "mindray":                ["mindray.com"],
    "bpl":                    ["bpltechnologies.com", "bplmedicaltechnologies.com"],
    "drager":                 ["draeger.com"],
    "drager (perseus)":       ["draeger.com"],
    "hamilton medical":       ["hamilton-medical.com"],
    "hamilton":               ["hamilton-medical.com"],
    "fresenius":              ["fmcna.com", "freseniusmedicalcare.com"],
    "nipro":                  ["nipro.com", "nipro-group.com"],
    "olympus":                ["olympus-global.com", "olympusamerica.com"],
    "stryker":                ["stryker.com"],
    "zoll":                   ["zoll.com"],
    "medtronic":              ["medtronic.com"],
    "ambu":                   ["ambu.com"],
    "ethicon":                ["ethicon.com"],
    "karl storz":             ["karlstorz.com"],
    "leica":                  ["leica-microsystems.com"],
    "zeiss":                  ["zeiss.com"],
    "alcon":                  ["alcon.com"],
    "fisher & paykel":        ["fphcare.com"],
    "fisher and paykel":      ["fphcare.com"],
    "hill-rom":               ["hill-rom.com", "hillrom.com"],
    "intuitive surgical":     ["intuitive.com", "intuitivesurgical.com"],
    "boston scientific":      ["bostonscientific.com"],
    "bayer":                  ["bayer.com"],
    "bbraun":                 ["bbraun.com"],
    "transasia":              ["transasia.co.in"],
    "carestream":             ["carestream.com"],
    "allengers":              ["allengers.com"],
    "godrej":                 ["godrej.com"],
    "atom":                   ["atomedusa.com"],
    "remi":                   ["remilabworld.com"],
    "thermo":                 ["thermofisher.com"],
    "thermo fisher":          ["thermofisher.com"],
    "bio-rad":                ["bio-rad.com"],
    "abbott":                 ["abbott.com"],
    "roche":                  ["roche.com"],
    "beckman coulter":        ["beckman.com", "beckmancoulter.com"],
    "agilent":                ["agilent.com"],
    "sysmex":                 ["sysmex.com"],
    "biomerieux":             ["biomerieux.com"],
    "biomérieux":             ["biomerieux.com"],
    "shimadzu":               ["shimadzu.com"],
    "thermo":                 ["thermofisher.com"],
    "eppendorf":              ["eppendorf.com"],
    "topcon":                 ["topconmedical.com"],
    "welch allyn":            ["welchallyn.com", "hillrom.com"],
    "omron":                  ["omronhealthcare.com"],
    "masimo":                 ["masimo.com"],
    "edwards lifesciences":   ["edwards.com"],
    "edwards":                ["edwards.com"],
    "intersurgical":          ["intersurgical.com"],
    "varex":                  ["vareximaging.com"],
    "canon":                  ["medical.canon"],
    "canon medical":          ["medical.canon"],
    "fujifilm":               ["fujifilm.com"],
    "samsung medison":        ["samsungmedison.com", "samsunghealthcare.com"],
    "verathon":               ["verathon.com"],
    "alifax":                 ["alifax.com"],
    "stago":                  ["stago.com"],
    "mediso":                 ["mediso.com"],
    "heidelberg":             ["heidelbergengineering.com"],
    "diversey":               ["diversey.com"],
    "aesculap":               ["aesculapusa.com", "bbraun.com"],
    "memmert":                ["memmert.com"],
    "schiller":               ["schiller.ch"],
    "vitalograph":            ["vitalograph.com"],
    "bionet":                 ["bionetus.com"],
    "interacoustics":         ["interacoustics.com"],
    "cepheid":                ["cepheid.com"],
    "qiagen":                 ["qiagen.com"],
    "biotek":                 ["biotek.com"],
    "ika":                    ["ikausa.com", "ika.com"],
    "tarsons":                ["tarsons.com"],
    "polymed":                ["polymedicure.com"],
    "romsons":                ["romsons.com"],
    "datt mediproducts":      ["dattmedi.com"],
    "vissco":                 ["vissco.com"],
    "karma":                  ["karma-medical.com"],
}


def _resolve_domains(brand: str) -> list[str]:
    if not brand:
        return []
    b = brand.lower()
    # Try exact match first, then longest prefix.
    if b in _BRAND_DOMAINS:
        return _BRAND_DOMAINS[b]
    for key, doms in _BRAND_DOMAINS.items():
        if b.startswith(key) or key.startswith(b):
            return doms
    return []


def _query(item: dict, domain: str) -> str:
    parts = [item.get("brand"), item.get("model"), item.get("itemName")]
    base = " ".join([p for p in parts if p])
    return f"{base} site:{domain}"


class _ManufacturerProvider:
    name = NAME
    prior = PRIOR

    def search(self, item: dict, k: int = 8) -> list[Candidate]:
        from duckduckgo_search import DDGS
        domains = _resolve_domains(item.get("brand", ""))
        if not domains:
            return []
        out: list[Candidate] = []
        for domain in domains:
            q = _query(item, domain)
            ddg_throttle()
            try:
                with DDGS() as ddgs:
                    results = list(ddgs.images(q, max_results=k, safesearch="off"))
            except Exception:
                ddg_release()
                time.sleep(2)
                continue
            ddg_release()
            for r in results:
                url = r.get("image")
                if not url or not is_clean_url(url):
                    continue
                # Confirm the URL really is on the manufacturer domain.
                if domain not in url:
                    continue
                out.append(Candidate(
                    url=url, provider=NAME, prior=PRIOR, hint_brand=True,
                ))
                if len(out) >= k:
                    return out
        return out


provider = _ManufacturerProvider()

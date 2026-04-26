"""Generate a tiny GUDID-shaped sample so we can test build_sqlite.py
without downloading the real 25 GB dump."""
from pathlib import Path
import csv

OUT = Path("./gudid_raw_sample")
OUT.mkdir(exist_ok=True)

device_rows = [
    # PRIMARY_DI, BRAND_NAME, COMPANY_NAME, VERSION_MODEL_NUMBER, CATALOG_NUMBER,
    # DEVICE_DESCRIPTION, DEVICE_PUBLISH_DATE, DEVICE_RECORD_STATUS, RX, OTC,
    # MRI_SAFETY, DEVICE_COUNT_IN_BASE_PACKAGE
    ("00643169527386", "IntelliVue", "Philips", "MX450", "865066", "Patient monitor multi-parameter", "2018-05-01", "Published", "true", "false", "MR Conditional", "1"),
    ("00840102100015", "Hamilton-G5", "Hamilton Medical", "G5", "159000",  "Critical care ventilator", "2017-09-01", "Published", "true", "false", "Labelling Does Not Contain MRI Safety Information", "1"),
    ("00382902340051", "BeneVision N17", "Mindray", "N17", "BV-N17", "Patient monitor 17-inch ICU", "2020-03-15", "Published", "true", "false", "", "1"),
    ("00382902340052", "BeneHeart D6",   "Mindray", "D6",  "BH-D6",  "Defibrillator biphasic with AED", "2019-11-12", "Published", "true", "false", "", "1"),
    ("00611919000115", "MAGNETOM Aera",  "Siemens Healthineers", "Aera 1.5T", "MA-15",  "Magnetic resonance imaging system 1.5T", "2016-04-22", "Published", "true", "false", "", "1"),
    ("00643169999991", "Stat-Padz II",   "ZOLL", "Stat-Padz II", "8900-0801",  "Defibrillation electrode pad, single-use, adult", "2015-01-01", "Published", "true", "false", "", "1"),
    ("00811223030001", "Aquasonic 100",  "Parker Laboratories", "100", "01-08", "Ultrasound transmission gel, single-use", "2014-06-10", "Published", "false", "true", "", "1"),
    ("00382902341111", "BeneFusion SP3", "Mindray", "SP3", "BF-SP3",   "Syringe infusion pump", "2021-02-01", "Published", "true", "false", "", "1"),
    ("00611919000222", "ARTIS icono",    "Siemens Healthineers", "icono biplane", "AR-IB", "Angiography system biplane cath lab", "2019-08-01", "Published", "true", "false", "", "1"),
    ("00811223040002", "LNCS DCI",       "Masimo", "DCI", "1863",  "Pulse oximeter sensor reusable adult finger", "2013-03-12", "Published", "true", "false", "", "1"),
    ("00811223040003", "LNCS Adt",       "Masimo", "Adt", "1859",  "Pulse oximeter sensor disposable single-use adult", "2014-04-12", "Published", "true", "false", "", "20"),
    ("00643169111111", "HeartStart MRx", "Philips", "MRx", "M3535A", "Defibrillator monitor with pacing", "2010-01-01", "Published", "true", "false", "", "1"),
]

device_headers = [
    "PRIMARY_DI", "BRAND_NAME", "COMPANY_NAME", "VERSION_MODEL_NUMBER", "CATALOG_NUMBER",
    "DEVICE_DESCRIPTION", "DEVICE_PUBLISH_DATE", "DEVICE_RECORD_STATUS", "RX", "OTC",
    "MRI_SAFETY", "DEVICE_COUNT_IN_BASE_PACKAGE",
]

with open(OUT / "device.txt", "w", encoding="utf-8", newline="") as f:
    w = csv.writer(f, delimiter="|")
    w.writerow(device_headers)
    w.writerows(device_rows)

gmdn_rows = [
    ("00643169527386", "Multi-parameter patient monitor"),
    ("00840102100015", "Ventilator, critical care"),
    ("00382902340051", "Multi-parameter patient monitor"),
    ("00382902340052", "Defibrillator, external, automated/semi-automated"),
    ("00611919000115", "Magnetic resonance imaging system"),
    ("00643169999991", "Defibrillator electrode pad, single-use"),
    ("00811223030001", "Ultrasound transmission gel"),
    ("00382902341111", "Syringe infusion pump"),
    ("00611919000222", "Angiographic X-ray system, biplane"),
    ("00811223040002", "Pulse oximeter sensor, reusable"),
    ("00811223040003", "Pulse oximeter sensor, single-use"),
    ("00643169111111", "Defibrillator/monitor, manual + AED"),
]

with open(OUT / "gmdnTerms.txt", "w", encoding="utf-8", newline="") as f:
    w = csv.writer(f, delimiter="|")
    w.writerow(["PRIMARY_DI", "GMDN_PT_NAME"])
    w.writerows(gmdn_rows)

print(f"Sample written to {OUT}/  ({len(device_rows)} device rows)")

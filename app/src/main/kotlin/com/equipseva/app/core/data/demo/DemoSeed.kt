package com.equipseva.app.core.data.demo

import com.equipseva.app.core.data.chat.ChatConversation
import com.equipseva.app.core.data.chat.ChatMessage
import com.equipseva.app.core.data.engineers.Engineer
import com.equipseva.app.core.data.engineers.VerificationStatus
import com.equipseva.app.core.data.logistics.LogisticsJob
import com.equipseva.app.core.data.orders.Order
import com.equipseva.app.core.data.orders.OrderLineItem
import com.equipseva.app.core.data.orders.OrderStatus
import com.equipseva.app.core.data.parts.PartCategory
import com.equipseva.app.core.data.parts.SparePart
import com.equipseva.app.core.data.repair.RepairBid
import com.equipseva.app.core.data.repair.RepairBidStatus
import com.equipseva.app.core.data.repair.RepairEquipmentCategory
import com.equipseva.app.core.data.repair.RepairJob
import com.equipseva.app.core.data.repair.RepairJobStatus
import com.equipseva.app.core.data.repair.RepairJobUrgency
import java.time.Instant

/**
 * Static dummy data used when [com.equipseva.app.BuildConfig.DEMO_MODE] is true.
 * Lets the app render populated lists for screenshots / friend demos without
 * touching Supabase. Replace with live data by flipping the build flag.
 */
object DemoSeed {

    val supplierOrgIdMedTech: String = "demo-org-medtech"
    val supplierOrgIdAxisHealth: String = "demo-org-axishealth"
    val supplierOrgIdNovaBio: String = "demo-org-novabio"

    /** Stand-in user ids used as the buyer / engineer across seeded jobs, bids, orders, chats. */
    const val DEMO_HOSPITAL_USER: String = "demo-hospital-user"
    const val DEMO_HOSPITAL_ORG: String = "demo-hospital-org"
    const val DEMO_ENGINEER_USER: String = "demo-engineer-user"
    const val DEMO_LOGISTICS_PARTNER: String = "demo-logistics-partner"

    val spareParts: List<SparePart> = listOf(
        // ─── Patient Monitoring ───
        sp(
            id = "sp-pm-001",
            name = "Philips IntelliVue MX450 Patient Monitor — Battery Pack",
            partNumber = "989803196521",
            description = "OEM Lithium-ion battery for IntelliVue MX400/450/500 series. 8-hour runtime, includes calibration certificate.",
            category = PartCategory.PatientMonitoring,
            brands = listOf("Philips"),
            models = listOf("IntelliVue MX450", "IntelliVue MX500"),
            equipCategories = listOf("patient_monitoring"),
            price = 8499.0,
            mrp = 11200.0,
            stock = 14,
            sku = "PHIL-MX-BAT-01",
            warranty = 12,
            isOem = true,
        ),
        sp(
            id = "sp-pm-002",
            name = "Mindray ePM 12M SpO2 Cable — 8 Pin",
            partNumber = "0010-30-43117",
            description = "Genuine Mindray reusable SpO2 sensor cable for ePM 10M / 12M / 15M monitors.",
            category = PartCategory.PatientMonitoring,
            brands = listOf("Mindray"),
            models = listOf("ePM 12M", "ePM 15M"),
            equipCategories = listOf("patient_monitoring"),
            price = 3299.0,
            mrp = 4500.0,
            stock = 28,
            sku = "MIND-EPM-SPO2",
            warranty = 6,
        ),
        sp(
            id = "sp-pm-003",
            name = "GE CARESCAPE B450 NIBP Cuff (Adult, Reusable)",
            partNumber = "M1573B",
            description = "Reusable adult NIBP cuff, single-tube, fits arm circumference 25–35 cm.",
            category = PartCategory.PatientMonitoring,
            brands = listOf("GE Healthcare"),
            models = listOf("CARESCAPE B450"),
            equipCategories = listOf("patient_monitoring"),
            price = 1899.0,
            mrp = 2400.0,
            stock = 42,
            sku = "GE-B450-NIBP-A",
            warranty = 6,
        ),

        // ─── Cardiology ───
        sp(
            id = "sp-cd-001",
            name = "Schiller AT-2 Plus ECG Electrodes — Disposable (Pack of 50)",
            partNumber = "2.155013",
            description = "Pre-gelled foam disposable electrodes, suitable for resting and stress ECG. Latex-free.",
            category = PartCategory.Cardiology,
            brands = listOf("Schiller", "BPL", "Nihon Kohden"),
            models = listOf("AT-2 Plus", "Cardiart 6108T"),
            equipCategories = listOf("cardiology"),
            price = 549.0,
            mrp = 750.0,
            stock = 120,
            sku = "SCH-ECG-50PK",
            unit = "pack",
            warranty = 0,
        ),
        sp(
            id = "sp-cd-002",
            name = "Defibrillator Paddle Set — Adult/Pediatric Combo",
            partNumber = "M3508A",
            description = "External paddle pair compatible with Philips HeartStart MRx & XL+. Includes pediatric overlay.",
            category = PartCategory.Cardiology,
            brands = listOf("Philips"),
            models = listOf("HeartStart MRx", "HeartStart XL+"),
            equipCategories = listOf("cardiology", "life_support"),
            price = 14999.0,
            mrp = 18500.0,
            stock = 6,
            sku = "PHIL-DEF-PAD",
            warranty = 12,
            isOem = true,
        ),
        sp(
            id = "sp-cd-003",
            name = "12-Lead ECG Cable Set — Banana Jack (IEC)",
            partNumber = "ECG-12L-IEC",
            description = "Universal 10-lead trunk cable + lead-wire set, IEC color-coded, banana jack termination.",
            category = PartCategory.Cardiology,
            brands = listOf("Universal"),
            models = listOf("Multiple"),
            equipCategories = listOf("cardiology"),
            price = 2499.0,
            mrp = 3200.0,
            stock = 35,
            sku = "UNI-ECG-12L",
            warranty = 6,
            isOem = false,
        ),

        // ─── Imaging & Radiology ───
        sp(
            id = "sp-ir-001",
            name = "Wipro GE Brivo XR 285 X-Ray Tube — Replacement",
            partNumber = "5391376",
            description = "Re-conditioned X-ray tube assembly, 100 kHU heat capacity. Tested for 30,000+ exposures.",
            category = PartCategory.ImagingRadiology,
            brands = listOf("Wipro GE"),
            models = listOf("Brivo XR 285", "Brivo XR 385"),
            equipCategories = listOf("imaging_radiology"),
            price = 189000.0,
            mrp = 245000.0,
            stock = 2,
            sku = "WGE-BRV-TUBE",
            warranty = 6,
        ),
        sp(
            id = "sp-ir-002",
            name = "Mindray DC-N3 Ultrasound — Convex Probe (3.5 MHz)",
            partNumber = "65C15EA",
            description = "Convex array transducer, 3.5 MHz, for abdominal & OB-GYN imaging. Compatible with DC series.",
            category = PartCategory.ImagingRadiology,
            brands = listOf("Mindray"),
            models = listOf("DC-N3", "DC-70"),
            equipCategories = listOf("imaging_radiology"),
            price = 84500.0,
            mrp = 105000.0,
            stock = 3,
            sku = "MIND-DCN3-PRB",
            warranty = 12,
            isOem = true,
        ),
        sp(
            id = "sp-ir-003",
            name = "C-Arm Image Intensifier — Replacement (9-inch)",
            partNumber = "GE-9IN-II",
            description = "Refurbished 9-inch image intensifier for mobile C-arm fluoroscopy units. 18-month warranty.",
            category = PartCategory.ImagingRadiology,
            brands = listOf("GE Healthcare", "Siemens"),
            models = listOf("OEC 9800", "Arcadis Avantic"),
            equipCategories = listOf("imaging_radiology"),
            price = 245000.0,
            mrp = 310000.0,
            stock = 1,
            sku = "GEN-CARM-II9",
            warranty = 18,
        ),

        // ─── Life Support ───
        sp(
            id = "sp-ls-001",
            name = "Drager Evita V300 Ventilator — Inspiratory Valve",
            partNumber = "8418933",
            description = "Replacement inspiratory valve assembly for Drager Evita V300/V500/V800 ventilators.",
            category = PartCategory.LifeSupport,
            brands = listOf("Drager"),
            models = listOf("Evita V300", "Evita V500"),
            equipCategories = listOf("life_support"),
            price = 22500.0,
            mrp = 28000.0,
            stock = 4,
            sku = "DRG-EVT-INSV",
            warranty = 12,
            isOem = true,
        ),
        sp(
            id = "sp-ls-002",
            name = "Hamilton C3 Ventilator — Flow Sensor (Adult)",
            partNumber = "281637",
            description = "Disposable proximal flow sensor for adult patients. Pack of 10.",
            category = PartCategory.LifeSupport,
            brands = listOf("Hamilton Medical"),
            models = listOf("Hamilton C3", "Hamilton C6"),
            equipCategories = listOf("life_support"),
            price = 4499.0,
            mrp = 5800.0,
            stock = 18,
            sku = "HAM-C3-FLW10",
            unit = "pack",
            warranty = 0,
        ),
        sp(
            id = "sp-ls-003",
            name = "Oxygen Concentrator HEPA Filter — Pack of 4",
            partNumber = "OC-HEPA-04",
            description = "Replacement HEPA + intake filter set for 5L/10L oxygen concentrators. Universal fit.",
            category = PartCategory.LifeSupport,
            brands = listOf("Philips Respironics", "Invacare", "BPL"),
            models = listOf("EverFlo", "Platinum 10", "OXY 5N"),
            equipCategories = listOf("life_support"),
            price = 899.0,
            mrp = 1200.0,
            stock = 76,
            sku = "GEN-OXY-HEPA",
            unit = "pack",
            warranty = 0,
        ),
        sp(
            id = "sp-ls-004",
            name = "Anesthesia Machine CO2 Absorber — Soda Lime (5kg)",
            partNumber = "AM-CO2-5KG",
            description = "Medical-grade soda lime absorber for anesthesia circle systems. Color-changing indicator.",
            category = PartCategory.LifeSupport,
            brands = listOf("Universal"),
            models = listOf("Multiple"),
            equipCategories = listOf("life_support"),
            price = 1299.0,
            mrp = 1650.0,
            stock = 52,
            sku = "GEN-CO2-5KG",
            unit = "kg",
            warranty = 0,
        ),

        // ─── Sterilization ───
        sp(
            id = "sp-st-001",
            name = "Autoclave Door Gasket — 24L (Compatible with Indo-Surgicals)",
            partNumber = "AUT-GSK-24L",
            description = "High-temperature silicone door gasket for vertical autoclaves. Operating range -40°C to 230°C.",
            category = PartCategory.Sterilization,
            brands = listOf("Indo-Surgicals", "Equitron"),
            models = listOf("24L Vertical", "20L Vertical"),
            equipCategories = listOf("sterilization"),
            price = 749.0,
            mrp = 950.0,
            stock = 38,
            sku = "GEN-AUT-GSK",
            warranty = 3,
        ),
        sp(
            id = "sp-st-002",
            name = "ETO Sterilizer Cartridge — 100g (Pack of 6)",
            partNumber = "ETO-100G-06",
            description = "Single-use ethylene oxide cartridges for tabletop ETO sterilizers. ICMR-approved.",
            category = PartCategory.Sterilization,
            brands = listOf("Anvayaa", "MediTech"),
            models = listOf("Tabletop ETO"),
            equipCategories = listOf("sterilization"),
            price = 2199.0,
            mrp = 2750.0,
            stock = 22,
            sku = "ANV-ETO-6PK",
            unit = "pack",
            warranty = 0,
        ),

        // ─── Other ───
        sp(
            id = "sp-ot-001",
            name = "Hospital Bed Caster Wheel — 5\" Twin Lock (Set of 4)",
            partNumber = "HB-CSTR-5TL",
            description = "Twin-lock caster wheels for ICU & general ward beds. Anti-static, supports up to 250 kg.",
            category = PartCategory.Other,
            brands = listOf("Universal"),
            models = listOf("Multiple"),
            equipCategories = listOf("other"),
            price = 1899.0,
            mrp = 2400.0,
            stock = 64,
            sku = "GEN-CSTR-04",
            unit = "set",
            warranty = 12,
        ),
        sp(
            id = "sp-ot-002",
            name = "Infusion Pump Battery — BPL IP-30 (NiMH)",
            partNumber = "BPL-IP30-BAT",
            description = "Replacement NiMH battery pack for BPL IP-30 single-channel infusion pump. 6 hours backup.",
            category = PartCategory.Other,
            brands = listOf("BPL"),
            models = listOf("IP-30", "IP-30 Plus"),
            equipCategories = listOf("other"),
            price = 1599.0,
            mrp = 2100.0,
            stock = 19,
            sku = "BPL-IP30-BAT",
            warranty = 6,
            isOem = true,
        ),
        sp(
            id = "sp-ot-003",
            name = "Suction Machine Tubing + Jar Lid Set",
            partNumber = "SUC-TJL-SET",
            description = "Universal silicone suction tubing (2m) with bacterial filter and replacement jar lid.",
            category = PartCategory.Other,
            brands = listOf("Universal"),
            models = listOf("Multiple"),
            equipCategories = listOf("other"),
            price = 449.0,
            mrp = 600.0,
            stock = 88,
            sku = "GEN-SUC-SET",
            unit = "set",
            warranty = 3,
        ),
        sp(
            id = "sp-ot-004",
            name = "Centrifuge Rotor — 12-Tube Swing-Out",
            partNumber = "REM-R8C-12",
            description = "12-tube swing-out rotor for REMI R-8C centrifuge. Maximum speed 4000 RPM.",
            category = PartCategory.Other,
            brands = listOf("REMI"),
            models = listOf("R-8C", "R-8 Plus"),
            equipCategories = listOf("other"),
            price = 6499.0,
            mrp = 8200.0,
            stock = 7,
            sku = "REM-R8C-RTR",
            warranty = 12,
            isOem = true,
        ),
        sp(
            id = "sp-ot-005",
            name = "Dental X-Ray Sensor — Size 2 (Universal)",
            partNumber = "DX-SNS-S2",
            description = "Digital intraoral dental X-ray sensor, size 2, 25.4×36mm active area. USB connection.",
            category = PartCategory.Other,
            brands = listOf("Universal"),
            models = listOf("Multiple"),
            equipCategories = listOf("other"),
            price = 49500.0,
            mrp = 62000.0,
            stock = 4,
            sku = "GEN-DXR-S2",
            warranty = 24,
        ),
        sp(
            id = "sp-ot-006",
            name = "Surgical OT Light LED Bulb — 25W (Pack of 3)",
            partNumber = "OT-LED-25-3",
            description = "Replacement LED bulbs for shadowless OT lights, 5500K color temperature, 70,000 hr life.",
            category = PartCategory.Other,
            brands = listOf("Universal"),
            models = listOf("Multiple"),
            equipCategories = listOf("other"),
            price = 1299.0,
            mrp = 1650.0,
            stock = 41,
            sku = "GEN-OTL-3PK",
            unit = "pack",
            warranty = 12,
        ),
    )

    // ─── Engineers (20) ───
    /** Pool of engineer userIds used as bid authors / chat counterparts. */
    val engineerUserIds: List<String> = listOf(
        DEMO_ENGINEER_USER,
        "demo-eng-002", "demo-eng-003", "demo-eng-004", "demo-eng-005", "demo-eng-006",
        "demo-eng-007", "demo-eng-008", "demo-eng-009", "demo-eng-010", "demo-eng-011",
        "demo-eng-012", "demo-eng-013", "demo-eng-014", "demo-eng-015", "demo-eng-016",
        "demo-eng-017", "demo-eng-018", "demo-eng-019", "demo-eng-020",
    )

    val engineers: List<Engineer> = listOf(
        eng("demo-eng-001", DEMO_ENGINEER_USER, "Ravi Krishnan", "Bengaluru", "Karnataka",
            VerificationStatus.Verified, 1450.0, 12,
            listOf(RepairEquipmentCategory.ImagingRadiology, RepairEquipmentCategory.PatientMonitoring),
            "XXXX-XXXX-1234"),
        eng("demo-eng-002", "demo-eng-002", "Arjun Menon", "Chennai", "Tamil Nadu",
            VerificationStatus.Verified, 1200.0, 9,
            listOf(RepairEquipmentCategory.LifeSupport, RepairEquipmentCategory.Surgical),
            "XXXX-XXXX-5678"),
        eng("demo-eng-003", "demo-eng-003", "Deepa Ramachandran", "Mumbai", "Maharashtra",
            VerificationStatus.Verified, 1650.0, 15,
            listOf(RepairEquipmentCategory.Cardiology, RepairEquipmentCategory.PatientMonitoring),
            "XXXX-XXXX-9012"),
        eng("demo-eng-004", "demo-eng-004", "Sandeep Verma", "Pune", "Maharashtra",
            VerificationStatus.Verified, 950.0, 6,
            listOf(RepairEquipmentCategory.Sterilization),
            null),
        eng("demo-eng-005", "demo-eng-005", "Anita Patel", "Hyderabad", "Telangana",
            VerificationStatus.Verified, 1800.0, 18,
            listOf(RepairEquipmentCategory.ImagingRadiology, RepairEquipmentCategory.Oncology, RepairEquipmentCategory.LifeSupport),
            "XXXX-XXXX-3456"),
        eng("demo-eng-006", "demo-eng-006", "Karthik Iyer", "Bengaluru", "Karnataka",
            VerificationStatus.Verified, 1100.0, 8,
            listOf(RepairEquipmentCategory.Dental, RepairEquipmentCategory.Ophthalmology),
            "XXXX-XXXX-7890"),
        eng("demo-eng-007", "demo-eng-007", "Priya Nair", "Cochin", "Kerala",
            VerificationStatus.Verified, 1300.0, 11,
            listOf(RepairEquipmentCategory.Neonatal, RepairEquipmentCategory.PatientMonitoring),
            null),
        eng("demo-eng-008", "demo-eng-008", "Vikram Singh", "Delhi", "Delhi",
            VerificationStatus.Verified, 1550.0, 13,
            listOf(RepairEquipmentCategory.Surgical, RepairEquipmentCategory.LifeSupport),
            "XXXX-XXXX-2345"),
        eng("demo-eng-009", "demo-eng-009", "Meera Reddy", "Hyderabad", "Telangana",
            VerificationStatus.Pending, 800.0, 4,
            listOf(RepairEquipmentCategory.Laboratory),
            "XXXX-XXXX-6789"),
        eng("demo-eng-010", "demo-eng-010", "Amit Kulkarni", "Pune", "Maharashtra",
            VerificationStatus.Verified, 1400.0, 10,
            listOf(RepairEquipmentCategory.Dialysis, RepairEquipmentCategory.Cardiology),
            "XXXX-XXXX-1357"),
        eng("demo-eng-011", "demo-eng-011", "Rohan Das", "Kolkata", "West Bengal",
            VerificationStatus.Verified, 1050.0, 7,
            listOf(RepairEquipmentCategory.Physiotherapy, RepairEquipmentCategory.HospitalFurniture),
            null),
        eng("demo-eng-012", "demo-eng-012", "Suresh Pillai", "Chennai", "Tamil Nadu",
            VerificationStatus.Pending, 700.0, 3,
            listOf(RepairEquipmentCategory.Ent),
            "XXXX-XXXX-2468"),
        eng("demo-eng-013", "demo-eng-013", "Nisha Sharma", "Delhi", "Delhi",
            VerificationStatus.Verified, 1700.0, 16,
            listOf(RepairEquipmentCategory.ImagingRadiology, RepairEquipmentCategory.Cardiology, RepairEquipmentCategory.PatientMonitoring),
            "XXXX-XXXX-9753"),
        eng("demo-eng-014", "demo-eng-014", "Manoj Bhat", "Bengaluru", "Karnataka",
            VerificationStatus.Verified, 900.0, 5,
            listOf(RepairEquipmentCategory.Sterilization, RepairEquipmentCategory.HospitalFurniture),
            null),
        eng("demo-eng-015", "demo-eng-015", "Lakshmi Subramanian", "Chennai", "Tamil Nadu",
            VerificationStatus.Verified, 1250.0, 9,
            listOf(RepairEquipmentCategory.Neonatal, RepairEquipmentCategory.LifeSupport),
            "XXXX-XXXX-8642"),
        eng("demo-eng-016", "demo-eng-016", "Imran Khan", "Mumbai", "Maharashtra",
            VerificationStatus.Rejected, 600.0, 2,
            listOf(RepairEquipmentCategory.Other),
            "XXXX-XXXX-3691"),
        eng("demo-eng-017", "demo-eng-017", "Varun Joshi", "Pune", "Maharashtra",
            VerificationStatus.Verified, 1350.0, 11,
            listOf(RepairEquipmentCategory.Dialysis, RepairEquipmentCategory.LifeSupport),
            "XXXX-XXXX-4827"),
        eng("demo-eng-018", "demo-eng-018", "Sneha Gupta", "Hyderabad", "Telangana",
            VerificationStatus.Pending, 750.0, 3,
            listOf(RepairEquipmentCategory.Ophthalmology),
            null),
        eng("demo-eng-019", "demo-eng-019", "Pradeep Naidu", "Vizag", "Andhra Pradesh",
            VerificationStatus.Verified, 1150.0, 22,
            listOf(RepairEquipmentCategory.Surgical, RepairEquipmentCategory.Sterilization),
            "XXXX-XXXX-5938"),
        eng("demo-eng-020", "demo-eng-020", "Asha Thomas", "Cochin", "Kerala",
            VerificationStatus.Rejected, 500.0, 2,
            listOf(RepairEquipmentCategory.Laboratory, RepairEquipmentCategory.Other),
            "XXXX-XXXX-6049"),
    )

    // ─── Repair Jobs (20) ───
    val repairJobs: List<RepairJob> = listOf(
        // Requested × 8 (4 Emergency, 2 SameDay, 2 Scheduled)
        rj("rj-001", "ES-RJ-24001", RepairJobStatus.Requested, RepairJobUrgency.Emergency,
            RepairEquipmentCategory.LifeSupport, "Drager", "Evita V300",
            "Ventilator alarm — high pressure, patient on support, urgent",
            DEMO_HOSPITAL_USER, null, 6500.0, "2026-04-22T08:15:00Z"),
        rj("rj-002", "ES-RJ-24002", RepairJobStatus.Requested, RepairJobUrgency.Emergency,
            RepairEquipmentCategory.Cardiology, "Zoll", "R Series Defibrillator",
            "Defibrillator not charging — code blue ward 3",
            DEMO_HOSPITAL_USER, null, 8000.0, "2026-04-22T09:02:00Z"),
        rj("rj-003", "ES-RJ-24003", RepairJobStatus.Requested, RepairJobUrgency.Emergency,
            RepairEquipmentCategory.PatientMonitoring, "Philips", "IntelliVue MX450",
            "Monitor screen flickering, ECG trace dropping intermittently",
            null, null, 3500.0, "2026-04-22T10:20:00Z"),
        rj("rj-004", "ES-RJ-24004", RepairJobStatus.Requested, RepairJobUrgency.Emergency,
            RepairEquipmentCategory.Neonatal, "GE", "Giraffe OmniBed",
            "NICU incubator temperature sensor reading stuck at 37C",
            DEMO_HOSPITAL_USER, null, 4500.0, "2026-04-22T11:00:00Z"),
        rj("rj-005", "ES-RJ-24005", RepairJobStatus.Requested, RepairJobUrgency.SameDay,
            RepairEquipmentCategory.ImagingRadiology, "Siemens", "SOMATOM go.Up CT Scanner",
            "CT image artifacts on lower-right quadrant, calibration suspected",
            null, null, 12000.0, "2026-04-22T12:30:00Z"),
        rj("rj-006", "ES-RJ-24006", RepairJobStatus.Requested, RepairJobUrgency.SameDay,
            RepairEquipmentCategory.Dialysis, "Fresenius", "4008S Dialysis Machine",
            "Dialysis machine pressure alarm during priming cycle",
            DEMO_HOSPITAL_USER, null, 5500.0, "2026-04-22T13:10:00Z"),
        rj("rj-007", "ES-RJ-24007", RepairJobStatus.Requested, RepairJobUrgency.Scheduled,
            RepairEquipmentCategory.Sterilization, "Indo-Surgicals", "Vertical Autoclave 24L",
            "Autoclave door seal leak, scheduled service",
            DEMO_HOSPITAL_USER, null, 1800.0, "2026-04-22T14:00:00Z"),
        rj("rj-008", "ES-RJ-24008", RepairJobStatus.Requested, RepairJobUrgency.Scheduled,
            RepairEquipmentCategory.Cardiology, "Philips", "PageWriter TC70 ECG",
            "Quarterly preventive maintenance and calibration",
            null, null, 2200.0, "2026-04-22T14:45:00Z"),

        // Assigned × 3
        rj("rj-009", "ES-RJ-24009", RepairJobStatus.Assigned, RepairJobUrgency.SameDay,
            RepairEquipmentCategory.ImagingRadiology, "GE", "Signa Explorer MRI 1.5T",
            "MRI helium boil-off rate above threshold, needs investigation",
            DEMO_HOSPITAL_USER, DEMO_ENGINEER_USER, 15000.0, "2026-04-22T15:20:00Z"),
        rj("rj-010", "ES-RJ-24010", RepairJobStatus.Assigned, RepairJobUrgency.SameDay,
            RepairEquipmentCategory.LifeSupport, "Hamilton Medical", "Hamilton C3 Ventilator",
            "Ventilator flow sensor reading inconsistent with set values",
            DEMO_HOSPITAL_USER, DEMO_ENGINEER_USER, 4800.0, "2026-04-22T16:00:00Z"),
        rj("rj-011", "ES-RJ-24011", RepairJobStatus.Assigned, RepairJobUrgency.Scheduled,
            RepairEquipmentCategory.Dental, "A-dec", "500 Dental Chair",
            "Dental chair hydraulic lift slow on descent",
            DEMO_HOSPITAL_USER, "demo-eng-006", 2500.0, "2026-04-22T16:40:00Z"),

        // EnRoute × 2
        rj("rj-012", "ES-RJ-24012", RepairJobStatus.EnRoute, RepairJobUrgency.Emergency,
            RepairEquipmentCategory.Surgical, "Stryker", "1688 4K Surgical Camera",
            "OT camera no signal, surgery scheduled in 90 min",
            DEMO_HOSPITAL_USER, DEMO_ENGINEER_USER, 6000.0, "2026-04-22T17:15:00Z"),
        rj("rj-013", "ES-RJ-24013", RepairJobStatus.EnRoute, RepairJobUrgency.SameDay,
            RepairEquipmentCategory.PatientMonitoring, "Mindray", "ePM 12M Monitor",
            "Monitor SpO2 reading drift after sensor swap",
            DEMO_HOSPITAL_USER, "demo-eng-003", 2800.0, "2026-04-22T17:55:00Z"),

        // InProgress × 3
        rj("rj-014", "ES-RJ-24014", RepairJobStatus.InProgress, RepairJobUrgency.SameDay,
            RepairEquipmentCategory.ImagingRadiology, "Mindray", "DC-N3 Ultrasound",
            "Ultrasound convex probe image quality degraded",
            DEMO_HOSPITAL_USER, DEMO_ENGINEER_USER, 7500.0, "2026-04-22T18:30:00Z"),
        rj("rj-015", "ES-RJ-24015", RepairJobStatus.InProgress, RepairJobUrgency.Scheduled,
            RepairEquipmentCategory.Sterilization, "Equitron", "ETO Sterilizer Tabletop",
            "ETO cartridge not seating properly, possible gasket issue",
            DEMO_HOSPITAL_USER, "demo-eng-004", 3200.0, "2026-04-22T19:05:00Z"),
        rj("rj-016", "ES-RJ-24016", RepairJobStatus.InProgress, RepairJobUrgency.Scheduled,
            RepairEquipmentCategory.Cardiology, "BPL", "Cardiart 6108T ECG",
            "12-lead ECG cable continuity check needed across all leads",
            DEMO_HOSPITAL_USER, "demo-eng-010", 1500.0, "2026-04-22T19:40:00Z"),

        // Completed × 3
        rj("rj-017", "ES-RJ-24017", RepairJobStatus.Completed, RepairJobUrgency.Scheduled,
            RepairEquipmentCategory.PatientMonitoring, "GE", "CARESCAPE B450",
            "NIBP cuff replacement and calibration — done",
            DEMO_HOSPITAL_USER, DEMO_ENGINEER_USER, 1900.0, "2026-04-21T10:00:00Z",
            startedAt = "2026-04-21T11:30:00Z", completedAt = "2026-04-21T13:15:00Z",
            hospitalRating = 5, hospitalReview = "Quick and professional"),
        rj("rj-018", "ES-RJ-24018", RepairJobStatus.Completed, RepairJobUrgency.SameDay,
            RepairEquipmentCategory.LifeSupport, "Philips Respironics", "EverFlo Oxygen Concentrator",
            "Oxygen concentrator HEPA filter swapped and unit cleaned",
            DEMO_HOSPITAL_USER, "demo-eng-005", 1100.0, "2026-04-20T09:00:00Z",
            startedAt = "2026-04-20T11:00:00Z", completedAt = "2026-04-20T12:30:00Z",
            hospitalRating = 4, hospitalReview = "Good service, slight delay"),
        rj("rj-019", "ES-RJ-24019", RepairJobStatus.Completed, RepairJobUrgency.Emergency,
            RepairEquipmentCategory.Cardiology, "Philips", "HeartStart MRx",
            "Defibrillator paddle replacement on emergency call",
            DEMO_HOSPITAL_USER, "demo-eng-008", 16500.0, "2026-04-19T14:00:00Z",
            startedAt = "2026-04-19T14:45:00Z", completedAt = "2026-04-19T16:30:00Z",
            hospitalRating = 5, hospitalReview = "Lifesaver, on-site fast"),

        // Cancelled × 1
        rj("rj-020", "ES-RJ-24020", RepairJobStatus.Cancelled, RepairJobUrgency.Scheduled,
            RepairEquipmentCategory.HospitalFurniture, "Universal", "ICU Bed Caster",
            "Bed caster wheel replacement — cancelled, in-house team handled",
            DEMO_HOSPITAL_USER, null, 800.0, "2026-04-18T10:00:00Z"),
    )

    // ─── Repair Bids (~30 across the 20 jobs) ───
    val repairBids: List<RepairBid> = listOf(
        // rj-001 (Requested, Emergency) — 3 pending bids
        rb("rb-001", "rj-001", DEMO_ENGINEER_USER, 6200.0, 1, RepairBidStatus.Pending,
            "Can be on-site in 60 min, full diagnostic", "2026-04-22T08:30:00Z"),
        rb("rb-002", "rj-001", "demo-eng-005", 6800.0, 2, RepairBidStatus.Pending,
            "Have spare valve kit ready", "2026-04-22T08:45:00Z"),
        rb("rb-003", "rj-001", "demo-eng-008", 5900.0, 3, RepairBidStatus.Pending,
            null, "2026-04-22T09:00:00Z"),

        // rj-002 (Requested, Emergency) — 2 pending bids
        rb("rb-004", "rj-002", DEMO_ENGINEER_USER, 7500.0, 1, RepairBidStatus.Pending,
            "Coming with replacement battery + paddles", "2026-04-22T09:15:00Z"),
        rb("rb-005", "rj-002", "demo-eng-003", 8200.0, 2, RepairBidStatus.Pending,
            "OEM parts in stock", "2026-04-22T09:30:00Z"),

        // rj-003 (Requested, Emergency, hospital null) — 1 pending bid
        rb("rb-006", "rj-003", "demo-eng-013", 3300.0, 2, RepairBidStatus.Pending,
            "Standard MX450 swap, 2 hour turnaround", "2026-04-22T10:35:00Z"),

        // rj-004 (Requested, Emergency) — 0 bids

        // rj-005 (Requested, SameDay, hospital null) — 4 pending bids
        rb("rb-007", "rj-005", DEMO_ENGINEER_USER, 11500.0, 4, RepairBidStatus.Pending,
            "Siemens factory-trained, 6 month warranty", "2026-04-22T12:45:00Z"),
        rb("rb-008", "rj-005", "demo-eng-005", 12500.0, 5, RepairBidStatus.Pending,
            null, "2026-04-22T13:00:00Z"),
        rb("rb-009", "rj-005", "demo-eng-008", 11000.0, 6, RepairBidStatus.Pending,
            "Discount on first call", "2026-04-22T13:15:00Z"),
        rb("rb-010", "rj-005", "demo-eng-013", 10800.0, 8, RepairBidStatus.Pending,
            "Will bring calibration phantom", "2026-04-22T13:30:00Z"),

        // rj-006 (Requested, SameDay) — 2 pending bids
        rb("rb-011", "rj-006", "demo-eng-010", 5400.0, 3, RepairBidStatus.Pending,
            "Fresenius certified", "2026-04-22T13:25:00Z"),
        rb("rb-012", "rj-006", "demo-eng-017", 5800.0, 4, RepairBidStatus.Pending,
            null, "2026-04-22T13:45:00Z"),

        // rj-007 (Requested, Scheduled) — 1 pending bid
        rb("rb-013", "rj-007", "demo-eng-004", 1700.0, 6, RepairBidStatus.Pending,
            "Same-day silicone gasket replacement", "2026-04-22T14:15:00Z"),

        // rj-008 (Requested, Scheduled, hospital null) — 0 bids

        // rj-009 (Assigned to demo eng, SameDay) — 1 accepted + 1 rejected
        rb("rb-014", "rj-009", DEMO_ENGINEER_USER, 14500.0, 6, RepairBidStatus.Accepted,
            "Helium top-up + leak diagnostic", "2026-04-22T15:30:00Z"),
        rb("rb-015", "rj-009", "demo-eng-005", 15800.0, 8, RepairBidStatus.Rejected,
            "GE certified", "2026-04-22T15:35:00Z"),

        // rj-010 (Assigned to demo eng, SameDay) — 1 accepted + 2 rejected
        rb("rb-016", "rj-010", DEMO_ENGINEER_USER, 4500.0, 2, RepairBidStatus.Accepted,
            "Have flow sensor in stock", "2026-04-22T16:10:00Z"),
        rb("rb-017", "rj-010", "demo-eng-007", 4800.0, 3, RepairBidStatus.Rejected,
            null, "2026-04-22T16:15:00Z"),
        rb("rb-018", "rj-010", "demo-eng-015", 5200.0, 4, RepairBidStatus.Rejected,
            "Hamilton certified", "2026-04-22T16:20:00Z"),

        // rj-011 (Assigned to eng-006) — 1 accepted
        rb("rb-019", "rj-011", "demo-eng-006", 2400.0, 5, RepairBidStatus.Accepted,
            "Hydraulic seal replacement", "2026-04-22T16:50:00Z"),

        // rj-012 (EnRoute, demo eng) — accepted bid
        rb("rb-020", "rj-012", DEMO_ENGINEER_USER, 5800.0, 1, RepairBidStatus.Accepted,
            "On the way, 30 min ETA", "2026-04-22T17:20:00Z"),

        // rj-013 (EnRoute) — accepted + 1 withdrawn
        rb("rb-021", "rj-013", "demo-eng-003", 2700.0, 2, RepairBidStatus.Accepted,
            null, "2026-04-22T18:00:00Z"),
        rb("rb-022", "rj-013", "demo-eng-013", 2900.0, 3, RepairBidStatus.Withdrawn,
            "Booked elsewhere", "2026-04-22T18:05:00Z"),

        // rj-014 (InProgress, demo eng) — withdrawn bid
        rb("rb-023", "rj-014", "demo-eng-005", 7800.0, 6, RepairBidStatus.Withdrawn,
            "Conflict in schedule", "2026-04-22T18:40:00Z"),
        rb("rb-024", "rj-014", DEMO_ENGINEER_USER, 7200.0, 5, RepairBidStatus.Pending,
            "Probe replacement, OEM stock", "2026-04-22T18:45:00Z"),

        // rj-015 (InProgress) — extra pending
        rb("rb-025", "rj-015", "demo-eng-014", 3000.0, 4, RepairBidStatus.Pending,
            null, "2026-04-22T19:15:00Z"),

        // rj-016 (InProgress) — extra pending + rejected
        rb("rb-026", "rj-016", "demo-eng-002", 1400.0, 3, RepairBidStatus.Pending,
            "Quick continuity test", "2026-04-22T19:50:00Z"),
        rb("rb-027", "rj-016", "demo-eng-011", 1700.0, 4, RepairBidStatus.Rejected,
            null, "2026-04-22T19:55:00Z"),

        // rj-017 (Completed) — historic withdrawn
        rb("rb-028", "rj-017", "demo-eng-019", 2100.0, 6, RepairBidStatus.Withdrawn,
            "Past schedule", "2026-04-21T10:30:00Z"),

        // rj-018 (Completed) — pending leftover
        rb("rb-029", "rj-018", "demo-eng-007", 1200.0, 4, RepairBidStatus.Pending,
            null, "2026-04-20T09:30:00Z"),

        // rj-020 (Cancelled) — pending
        rb("rb-030", "rj-020", "demo-eng-014", 850.0, 8, RepairBidStatus.Pending,
            "Caster wheel set", "2026-04-18T10:30:00Z"),
    )

    // ─── Logistics Jobs (20) ───
    val logisticsJobs: List<LogisticsJob> = listOf(
        // pending × 8
        lg("lg-001", "ES-LG-24001", "delivery", "Ventilator transfer — Drager Evita V300",
            "Bengaluru", "Karnataka", "Mysuru", "Karnataka", 2200.0, "pending", null),
        lg("lg-002", "ES-LG-24002", "delivery", "MRI coil delivery — GE Signa 1.5T",
            "Mumbai", "Maharashtra", "Pune", "Maharashtra", 1800.0, "pending", null),
        lg("lg-003", "ES-LG-24003", "pickup", "Spare parts package — Philips IntelliVue batteries",
            "Chennai", "Tamil Nadu", "Bengaluru", "Karnataka", 1450.0, "pending", null),
        lg("lg-004", "ES-LG-24004", "return", "Used CT tube return — Siemens SOMATOM",
            "Hyderabad", "Telangana", "Delhi", "Delhi", 4500.0, "pending", null),
        lg("lg-005", "ES-LG-24005", "delivery", "Defibrillator delivery — Zoll R Series",
            "Pune", "Maharashtra", "Nashik", "Maharashtra", 1200.0, "pending", null),
        lg("lg-006", "ES-LG-24006", "delivery", "Patient monitor — Mindray ePM 12M (3 units)",
            "Delhi", "Delhi", "Gurugram", "Haryana", 2800.0, "pending", null),
        lg("lg-007", "ES-LG-24007", "pickup", "Autoclave gasket pickup — Indo-Surgicals 24L",
            "Cochin", "Kerala", "Bengaluru", "Karnataka", 950.0, "pending", null),
        lg("lg-008", "ES-LG-24008", "delivery", "Anesthesia trolley delivery",
            "Vizag", "Andhra Pradesh", "Hyderabad", "Telangana", 2600.0, "pending", null),

        // assigned × 4
        lg("lg-009", "ES-LG-24009", "delivery", "Ultrasound probe — Mindray DC-N3 convex",
            "Bengaluru", "Karnataka", "Mangaluru", "Karnataka", 1700.0, "assigned",
            DEMO_LOGISTICS_PARTNER),
        lg("lg-010", "ES-LG-24010", "delivery", "ECG cable set — Schiller AT-2 Plus (10 sets)",
            "Mumbai", "Maharashtra", "Aurangabad", "Maharashtra", 1350.0, "assigned",
            DEMO_LOGISTICS_PARTNER),
        lg("lg-011", "ES-LG-24011", "return", "Faulty oxygen concentrator return",
            "Chennai", "Tamil Nadu", "Coimbatore", "Tamil Nadu", 1100.0, "assigned",
            DEMO_LOGISTICS_PARTNER),
        lg("lg-012", "ES-LG-24012", "pickup", "Sterilizer ETO cartridges — pickup from supplier",
            "Pune", "Maharashtra", "Mumbai", "Maharashtra", 850.0, "assigned",
            DEMO_LOGISTICS_PARTNER),

        // in_transit × 5
        lg("lg-013", "ES-LG-24013", "delivery", "C-Arm image intensifier — refurbished",
            "Hyderabad", "Telangana", "Bengaluru", "Karnataka", 4200.0, "in_transit",
            DEMO_LOGISTICS_PARTNER),
        lg("lg-014", "ES-LG-24014", "delivery", "X-Ray tube assembly — Wipro GE Brivo",
            "Delhi", "Delhi", "Jaipur", "Rajasthan", 3800.0, "in_transit",
            DEMO_LOGISTICS_PARTNER),
        lg("lg-015", "ES-LG-24015", "delivery", "Hospital bed casters — set of 16",
            "Bengaluru", "Karnataka", "Hubballi", "Karnataka", 1600.0, "in_transit",
            DEMO_LOGISTICS_PARTNER),
        lg("lg-016", "ES-LG-24016", "delivery", "OT light LED bulb pack — 3 cartons",
            "Cochin", "Kerala", "Thiruvananthapuram", "Kerala", 900.0, "in_transit",
            DEMO_LOGISTICS_PARTNER),
        lg("lg-017", "ES-LG-24017", "pickup", "Centrifuge rotor — REMI R-8C",
            "Pune", "Maharashtra", "Bengaluru", "Karnataka", 2400.0, "in_transit",
            DEMO_LOGISTICS_PARTNER),

        // delivered × 3
        lg("lg-018", "ES-LG-24018", "delivery", "Dental X-Ray sensor — universal size 2",
            "Mumbai", "Maharashtra", "Surat", "Gujarat", 1500.0, "delivered",
            DEMO_LOGISTICS_PARTNER, deliveredAt = "2026-04-21T16:30:00Z"),
        lg("lg-019", "ES-LG-24019", "delivery", "Infusion pump batteries — BPL IP-30 (12 packs)",
            "Chennai", "Tamil Nadu", "Madurai", "Tamil Nadu", 1250.0, "delivered",
            DEMO_LOGISTICS_PARTNER, deliveredAt = "2026-04-20T14:00:00Z"),
        lg("lg-020", "ES-LG-24020", "return", "ETO cartridge expired stock — return to MediTech",
            "Kolkata", "West Bengal", "Mumbai", "Maharashtra", 3100.0, "delivered",
            DEMO_LOGISTICS_PARTNER, deliveredAt = "2026-04-19T10:45:00Z"),
    )

    // ─── Orders (12) ───
    val orders: List<Order> = listOf(
        ord("ord-001", "ES-24001", OrderStatus.PLACED, "pending",
            supplier = supplierOrgIdMedTech,
            items = listOf(li("sp-pm-001", 2), li("sp-pm-002", 1)),
            "Bengaluru", "Karnataka", "560078", "2026-04-22T09:30:00Z"),
        ord("ord-002", "ES-24002", OrderStatus.PLACED, "pending",
            supplier = supplierOrgIdAxisHealth,
            items = listOf(li("sp-cd-001", 4)),
            "Chennai", "Tamil Nadu", "600040", "2026-04-22T10:15:00Z"),
        ord("ord-003", "ES-24003", OrderStatus.PLACED, "pending",
            supplier = supplierOrgIdNovaBio,
            items = listOf(li("sp-ls-003", 6), li("sp-ls-004", 2), li("sp-ot-006", 3)),
            "Mumbai", "Maharashtra", "400050", "2026-04-22T11:00:00Z"),
        ord("ord-004", "ES-24004", OrderStatus.CONFIRMED, "completed",
            supplier = supplierOrgIdMedTech,
            items = listOf(li("sp-pm-003", 8)),
            "Pune", "Maharashtra", "411014", "2026-04-21T15:00:00Z"),
        ord("ord-005", "ES-24005", OrderStatus.CONFIRMED, "completed",
            supplier = supplierOrgIdAxisHealth,
            items = listOf(li("sp-cd-002", 1), li("sp-cd-003", 2)),
            "Hyderabad", "Telangana", "500032", "2026-04-21T13:30:00Z"),
        ord("ord-006", "ES-24006", OrderStatus.SHIPPED, "completed",
            supplier = supplierOrgIdMedTech,
            items = listOf(li("sp-ir-002", 1)),
            "Delhi", "Delhi", "110034", "2026-04-20T11:00:00Z",
            tracking = "BLR238771142", estDelivery = "2026-04-24"),
        ord("ord-007", "ES-24007", OrderStatus.SHIPPED, "completed",
            supplier = supplierOrgIdNovaBio,
            items = listOf(li("sp-st-001", 5), li("sp-st-002", 3)),
            "Cochin", "Kerala", "682025", "2026-04-20T14:30:00Z",
            tracking = "DTDC11982331", estDelivery = "2026-04-25"),
        ord("ord-008", "ES-24018", OrderStatus.PLACED, "pending",
            supplier = supplierOrgIdMedTech,
            items = listOf(li("sp-ir-001", 1)),
            "Bengaluru", "Karnataka", "560001", "2026-04-22T07:30:00Z"),
        ord("ord-009", "ES-24015", OrderStatus.CONFIRMED, "completed",
            supplier = supplierOrgIdAxisHealth,
            items = listOf(li("sp-ot-001", 4), li("sp-ot-003", 6)),
            "Pune", "Maharashtra", "411001", "2026-04-19T16:00:00Z",
            tracking = null, estDelivery = "2026-04-26"),
        ord("ord-010", "ES-24011", OrderStatus.DELIVERED, "completed",
            supplier = supplierOrgIdNovaBio,
            items = listOf(li("sp-ls-001", 1), li("sp-ls-002", 2)),
            "Mumbai", "Maharashtra", "400010", "2026-04-15T09:45:00Z",
            tracking = "BLUEDART9981273", estDelivery = "2026-04-19",
            deliveredAt = "2026-04-19T11:20:00Z"),
        ord("ord-011", "ES-24009", OrderStatus.DELIVERED, "completed",
            supplier = supplierOrgIdMedTech,
            items = listOf(li("sp-pm-001", 1), li("sp-pm-003", 3), li("sp-ot-002", 2)),
            "Hyderabad", "Telangana", "500001", "2026-04-12T10:30:00Z",
            tracking = "DELHIVERY882711", estDelivery = "2026-04-16",
            deliveredAt = "2026-04-16T14:15:00Z"),
        ord("ord-012", "ES-24007X", OrderStatus.CANCELLED, "cancelled",
            supplier = supplierOrgIdAxisHealth,
            items = listOf(li("sp-cd-002", 2)),
            "Delhi", "Delhi", "110001", "2026-04-18T08:30:00Z"),
    )

    // ─── Chat Conversations (6) + Messages (~30) ───
    /** Tagged unread counts so the inbox renders the badge dot. */
    val chatConversations: List<ChatConversation> = listOf(
        ChatConversation(
            id = "conv-001",
            participantUserIds = listOf(DEMO_HOSPITAL_USER, DEMO_ENGINEER_USER),
            relatedEntityType = "repair_job",
            relatedEntityId = "rj-012",
            lastMessage = "On my way, ETA 20 min",
            lastMessageAtIso = "2026-04-22T17:35:00Z",
            createdAtIso = "2026-04-22T17:20:00Z",
            unreadCount = 2,
        ),
        ChatConversation(
            id = "conv-002",
            participantUserIds = listOf(DEMO_HOSPITAL_USER, "demo-eng-003"),
            relatedEntityType = "repair_job",
            relatedEntityId = "rj-013",
            lastMessage = "Bid accepted, let's coordinate",
            lastMessageAtIso = "2026-04-22T18:10:00Z",
            createdAtIso = "2026-04-22T18:00:00Z",
            unreadCount = 1,
        ),
        ChatConversation(
            id = "conv-003",
            participantUserIds = listOf(DEMO_HOSPITAL_USER, "demo-eng-005"),
            relatedEntityType = "repair_job",
            relatedEntityId = "rj-005",
            lastMessage = "Will the part arrive today?",
            lastMessageAtIso = "2026-04-22T13:25:00Z",
            createdAtIso = "2026-04-22T13:00:00Z",
            unreadCount = 3,
        ),
        ChatConversation(
            id = "conv-004",
            participantUserIds = listOf(DEMO_HOSPITAL_USER, "demo-eng-006"),
            relatedEntityType = "repair_job",
            relatedEntityId = "rj-011",
            lastMessage = "Done. Hydraulic seal replaced.",
            lastMessageAtIso = "2026-04-22T20:15:00Z",
            createdAtIso = "2026-04-22T17:00:00Z",
            unreadCount = 0,
        ),
        ChatConversation(
            id = "conv-005",
            participantUserIds = listOf(DEMO_HOSPITAL_USER, supplierOrgIdMedTech),
            relatedEntityType = "rfq_bid",
            relatedEntityId = "rfq-bid-101",
            lastMessage = "Invoice attached. Please confirm address.",
            lastMessageAtIso = "2026-04-21T16:50:00Z",
            createdAtIso = "2026-04-21T15:00:00Z",
            unreadCount = 0,
        ),
        ChatConversation(
            id = "conv-006",
            participantUserIds = listOf(DEMO_HOSPITAL_USER, supplierOrgIdNovaBio),
            relatedEntityType = "rfq_bid",
            relatedEntityId = "rfq-bid-102",
            lastMessage = "Discount applied on bulk order",
            lastMessageAtIso = "2026-04-20T14:00:00Z",
            createdAtIso = "2026-04-20T11:00:00Z",
            unreadCount = 0,
        ),
    )

    val chatMessages: List<ChatMessage> = listOf(
        // conv-001 — repair_job rj-012, demo eng on the way
        msg("msg-001-1", "conv-001", DEMO_HOSPITAL_USER, "Camera no signal in OT-2, urgent please", "2026-04-22T17:20:00Z", true),
        msg("msg-001-2", "conv-001", DEMO_ENGINEER_USER, "Got it, picking up cable now", "2026-04-22T17:23:00Z", true),
        msg("msg-001-3", "conv-001", DEMO_HOSPITAL_USER, "Surgery in 90 min", "2026-04-22T17:25:00Z", true),
        msg("msg-001-4", "conv-001", DEMO_ENGINEER_USER, "Leaving now", "2026-04-22T17:30:00Z", false),
        msg("msg-001-5", "conv-001", DEMO_ENGINEER_USER, "On my way, ETA 20 min", "2026-04-22T17:35:00Z", false),

        // conv-002 — repair_job rj-013, eng-003
        msg("msg-002-1", "conv-002", "demo-eng-003", "Hi, accepting your bid on the SpO2 sensor drift", "2026-04-22T18:00:00Z", true),
        msg("msg-002-2", "conv-002", DEMO_HOSPITAL_USER, "Great, when can you come?", "2026-04-22T18:03:00Z", true),
        msg("msg-002-3", "conv-002", "demo-eng-003", "Tomorrow 10 AM works?", "2026-04-22T18:05:00Z", true),
        msg("msg-002-4", "conv-002", DEMO_HOSPITAL_USER, "Yes please, ICU bed 4", "2026-04-22T18:08:00Z", true),
        msg("msg-002-5", "conv-002", "demo-eng-003", "Bid accepted, let's coordinate", "2026-04-22T18:10:00Z", false),

        // conv-003 — repair_job rj-005, eng-005, hospital is asking
        msg("msg-003-1", "conv-003", "demo-eng-005", "I can do the CT calibration today", "2026-04-22T13:00:00Z", true),
        msg("msg-003-2", "conv-003", DEMO_HOSPITAL_USER, "Bid is competitive, going ahead", "2026-04-22T13:10:00Z", true),
        msg("msg-003-3", "conv-003", "demo-eng-005", "Bringing calibration phantom", "2026-04-22T13:15:00Z", false),
        msg("msg-003-4", "conv-003", "demo-eng-005", "Already at site in 2 hours", "2026-04-22T13:20:00Z", false),
        msg("msg-003-5", "conv-003", "demo-eng-005", "Will the part arrive today?", "2026-04-22T13:25:00Z", false),

        // conv-004 — repair_job rj-011, eng-006, completed
        msg("msg-004-1", "conv-004", "demo-eng-006", "Reaching the dental clinic in 30", "2026-04-22T17:00:00Z", true),
        msg("msg-004-2", "conv-004", DEMO_HOSPITAL_USER, "OK, chair is in cabin 3", "2026-04-22T17:15:00Z", true),
        msg("msg-004-3", "conv-004", "demo-eng-006", "Diagnosed — hydraulic seal worn", "2026-04-22T18:30:00Z", true),
        msg("msg-004-4", "conv-004", "demo-eng-006", "Replacing now, 1 hour", "2026-04-22T19:00:00Z", true),
        msg("msg-004-5", "conv-004", "demo-eng-006", "Done. Hydraulic seal replaced.", "2026-04-22T20:15:00Z", true),

        // conv-005 — supplier MedTech (rfq bid)
        msg("msg-005-1", "conv-005", DEMO_HOSPITAL_USER, "Need 6 IntelliVue battery packs", "2026-04-21T15:00:00Z", true),
        msg("msg-005-2", "conv-005", supplierOrgIdMedTech, "We can fulfil at Rs 8200 each, 5 day lead time", "2026-04-21T15:30:00Z", true),
        msg("msg-005-3", "conv-005", DEMO_HOSPITAL_USER, "Confirmed, raising PO", "2026-04-21T16:00:00Z", true),
        msg("msg-005-4", "conv-005", supplierOrgIdMedTech, "Thanks. Shipping to which address?", "2026-04-21T16:30:00Z", true),
        msg("msg-005-5", "conv-005", supplierOrgIdMedTech, "Invoice attached. Please confirm address.", "2026-04-21T16:50:00Z", true),

        // conv-006 — supplier NovaBio (rfq bid)
        msg("msg-006-1", "conv-006", DEMO_HOSPITAL_USER, "Bulk autoclave gaskets — 50 units", "2026-04-20T11:00:00Z", true),
        msg("msg-006-2", "conv-006", supplierOrgIdNovaBio, "Bulk pricing applied", "2026-04-20T11:30:00Z", true),
        msg("msg-006-3", "conv-006", DEMO_HOSPITAL_USER, "Any further discount on cash payment?", "2026-04-20T12:30:00Z", true),
        msg("msg-006-4", "conv-006", supplierOrgIdNovaBio, "5% on advance, send PO", "2026-04-20T13:00:00Z", true),
        msg("msg-006-5", "conv-006", supplierOrgIdNovaBio, "Discount applied on bulk order", "2026-04-20T14:00:00Z", true),
    )

    // ─── Helpers ───

    private fun sp(
        id: String,
        name: String,
        partNumber: String,
        description: String,
        category: PartCategory,
        brands: List<String>,
        models: List<String>,
        equipCategories: List<String>,
        price: Double,
        mrp: Double?,
        stock: Int,
        sku: String,
        unit: String = "piece",
        warranty: Int,
        isOem: Boolean = false,
        isGenuine: Boolean = true,
        gst: Double = 12.0,
        moq: Int = 1,
    ): SparePart {
        val discount = if (mrp != null && mrp > price) (((mrp - price) / mrp) * 100).toInt() else 0
        val supplierId = listOf(supplierOrgIdMedTech, supplierOrgIdAxisHealth, supplierOrgIdNovaBio)
            .let { it[id.hashCode().rem(it.size).let { i -> if (i < 0) i + it.size else i }] }
        return SparePart(
            id = id,
            supplierOrgId = supplierId,
            name = name,
            partNumber = partNumber,
            description = description,
            category = category,
            compatibleBrands = brands,
            compatibleModels = models,
            compatibleEquipmentCategories = equipCategories,
            priceRupees = price,
            mrpRupees = mrp,
            discountPercent = discount.coerceIn(0, 99),
            stockQuantity = stock,
            minimumOrderQuantity = moq,
            unit = unit,
            imageUrls = emptyList(),
            isGenuine = isGenuine,
            isOem = isOem,
            warrantyMonths = warranty,
            sku = sku,
            gstRatePercent = gst,
        )
    }

    private fun eng(
        id: String,
        userId: String,
        @Suppress("UNUSED_PARAMETER") displayName: String,
        city: String,
        state: String,
        verification: VerificationStatus,
        hourlyRate: Double,
        years: Int,
        specs: List<RepairEquipmentCategory>,
        aadhaar: String?,
    ): Engineer = Engineer(
        id = id,
        userId = userId,
        aadhaarNumber = aadhaar,
        aadhaarVerified = verification == VerificationStatus.Verified && aadhaar != null,
        qualifications = listOf("Diploma in Biomedical Engineering"),
        specializations = specs,
        brandsServiced = listOf("Philips", "GE", "Mindray"),
        experienceYears = years,
        serviceRadiusKm = 35,
        city = city,
        state = state,
        verificationStatus = verification,
        backgroundCheckStatus = verification,
        certificates = emptyList(),
        hourlyRate = hourlyRate,
        yearsExperience = years,
        serviceAreas = listOf(city),
        // Stash display name in bio so list cards have a human label without
        // changing the Engineer schema.
        bio = displayName,
        isAvailable = verification == VerificationStatus.Verified,
    )

    private fun rj(
        id: String,
        jobNumber: String,
        status: RepairJobStatus,
        urgency: RepairJobUrgency,
        category: RepairEquipmentCategory,
        brand: String?,
        model: String?,
        issue: String,
        hospitalUserId: String?,
        engineerId: String?,
        estimatedCost: Double?,
        createdAt: String,
        startedAt: String? = null,
        completedAt: String? = null,
        hospitalRating: Int? = null,
        hospitalReview: String? = null,
    ): RepairJob {
        val title = issue.lineSequence().firstOrNull { it.isNotBlank() }?.take(80) ?: category.displayName
        return RepairJob(
            id = id,
            jobNumber = jobNumber,
            title = title,
            issueDescription = issue,
            equipmentCategory = category,
            equipmentBrand = brand,
            equipmentModel = model,
            status = status,
            urgency = urgency,
            estimatedCostRupees = estimatedCost,
            scheduledDate = null,
            scheduledTimeSlot = null,
            isAssignedToEngineer = engineerId != null,
            engineerId = engineerId,
            hospitalUserId = hospitalUserId,
            startedAtInstant = startedAt?.let(Instant::parse),
            completedAtInstant = completedAt?.let(Instant::parse),
            hospitalRating = hospitalRating,
            hospitalReview = hospitalReview,
            engineerRating = null,
            engineerReview = null,
            createdAtInstant = Instant.parse(createdAt),
            updatedAtInstant = Instant.parse(createdAt),
        )
    }

    private fun rb(
        id: String,
        jobId: String,
        engineerUserId: String,
        amount: Double,
        etaHours: Int?,
        status: RepairBidStatus,
        note: String?,
        createdAt: String,
    ): RepairBid = RepairBid(
        id = id,
        repairJobId = jobId,
        engineerUserId = engineerUserId,
        amountRupees = amount,
        etaHours = etaHours,
        note = note,
        status = status,
        createdAtInstant = Instant.parse(createdAt),
        updatedAtInstant = Instant.parse(createdAt),
    )

    private fun lg(
        id: String,
        jobNumber: String,
        jobType: String,
        equipmentDescription: String,
        pickupCity: String,
        pickupState: String,
        deliveryCity: String,
        deliveryState: String,
        quotedPrice: Double,
        status: String,
        partnerId: String?,
        deliveredAt: String? = null,
    ): LogisticsJob = LogisticsJob(
        id = id,
        jobNumber = jobNumber,
        requesterOrgId = DEMO_HOSPITAL_ORG,
        logisticsPartnerId = partnerId,
        jobType = jobType,
        equipmentDescription = equipmentDescription,
        pickupCity = pickupCity,
        pickupState = pickupState,
        deliveryCity = deliveryCity,
        deliveryState = deliveryState,
        preferredDateIso = "2026-04-23",
        actualPickupAtIso = if (status == "in_transit" || status == "delivered") "2026-04-22T08:00:00Z" else null,
        actualDeliveryAtIso = deliveredAt,
        quotedPriceRupees = quotedPrice,
        finalPriceRupees = if (status == "delivered") quotedPrice else null,
        status = status,
        specialInstructions = null,
        createdAtIso = "2026-04-22T07:00:00Z",
    )

    private fun li(partId: String, qty: Int): OrderLineItem {
        val part = spareParts.first { it.id == partId }
        return OrderLineItem(
            partId = part.id,
            name = part.name,
            partNumber = part.partNumber,
            quantity = qty,
            unitPriceRupees = part.priceRupees,
            gstRatePercent = part.gstRatePercent,
            imageUrl = part.primaryImageUrl,
        )
    }

    private fun ord(
        id: String,
        orderNumber: String,
        status: OrderStatus,
        paymentStatus: String,
        supplier: String,
        items: List<OrderLineItem>,
        city: String,
        state: String,
        pincode: String,
        createdAt: String,
        tracking: String? = null,
        estDelivery: String? = null,
        deliveredAt: String? = null,
    ): Order {
        val subtotal = items.sumOf { it.lineSubtotalRupees }
        val gst = items.sumOf { it.lineGstRupees }
        val shipping = if (subtotal > 5000) 0.0 else 250.0
        val total = subtotal + gst + shipping
        @Suppress("UNUSED_VARIABLE") val supplierTag = supplier // referenced via items only in fakes
        return Order(
            id = id,
            orderNumber = orderNumber,
            status = status,
            paymentStatus = paymentStatus,
            paymentId = if (paymentStatus == "completed") "pay_demo_${id}" else null,
            subtotal = subtotal,
            gstAmount = gst,
            shippingCost = shipping,
            totalAmount = total,
            lineItems = items,
            shippingAddress = "Hospital purchasing dept, Block C",
            shippingCity = city,
            shippingState = state,
            shippingPincode = pincode,
            trackingNumber = tracking,
            estimatedDelivery = estDelivery,
            deliveredAtIso = deliveredAt,
            notes = null,
            createdAtIso = createdAt,
        )
    }

    /**
     * Per-order supplier mapping. We compute this off the seed list so the Fake
     * order repository can answer `fetchForSupplier` without storing the supplier
     * id on the [Order] model (which the domain shape doesn't carry).
     */
    val orderSupplierMap: Map<String, String> = mapOf(
        "ord-001" to supplierOrgIdMedTech,
        "ord-002" to supplierOrgIdAxisHealth,
        "ord-003" to supplierOrgIdNovaBio,
        "ord-004" to supplierOrgIdMedTech,
        "ord-005" to supplierOrgIdAxisHealth,
        "ord-006" to supplierOrgIdMedTech,
        "ord-007" to supplierOrgIdNovaBio,
        "ord-008" to supplierOrgIdMedTech,
        "ord-009" to supplierOrgIdAxisHealth,
        "ord-010" to supplierOrgIdNovaBio,
        "ord-011" to supplierOrgIdMedTech,
        "ord-012" to supplierOrgIdAxisHealth,
    )

    private fun msg(
        id: String,
        conversationId: String,
        senderUserId: String,
        body: String,
        createdAt: String,
        isRead: Boolean,
    ): ChatMessage = ChatMessage(
        id = id,
        conversationId = conversationId,
        senderUserId = senderUserId,
        message = body,
        attachments = emptyList(),
        isRead = isRead,
        createdAtIso = createdAt,
    )
}

-- PENDING.md #59: Demo spare-part catalog seed
--
-- Seeds 18 realistic medical-equipment spare parts so first-run UX shows real
-- catalog data instead of "No parts yet". Uses stable UUIDs + ON CONFLICT (id)
-- DO NOTHING so re-running this migration is idempotent. Inserts are guarded
-- by a WHERE EXISTS check on the supplier organization so the FK never fails.
--
-- Suppliers used (already present in production):
--   c66f5587-677f-496d-91fd-45197a85c05d  MedEquip India Pvt Ltd  (manufacturer)
--   0568ba15-56a9-483a-9a23-43d62c7faddf  HealthTech Distributors (distributor)
--
-- Categories cover existing enum values: imaging_radiology, patient_monitoring,
-- surgical, laboratory, sterilization plus respiratory parts mapped to
-- life_support and ICU rotor/microscope items mapped to laboratory.
-- Prices in INR (numeric column, not paise) to match existing rows.
-- compatible_equipment_categories is equipment_category[] enum, cast explicitly.

INSERT INTO public.spare_parts (
  id, supplier_org_id, name, part_number, description, category,
  compatible_equipment_categories, compatible_brands, compatible_models,
  price, mrp, stock_quantity, minimum_order_quantity, unit,
  is_genuine, is_oem, warranty_months, hsn_code, gst_rate, is_active
)
SELECT v.id::uuid, v.supplier_org_id::uuid, v.name, v.part_number, v.description, v.category,
       v.compatible_equipment_categories::public.equipment_category[],
       v.compatible_brands, v.compatible_models,
       v.price, v.mrp, v.stock_quantity, v.minimum_order_quantity, v.unit,
       v.is_genuine, v.is_oem, v.warranty_months, v.hsn_code, v.gst_rate, true
FROM (
  VALUES
    -- Imaging / radiology
    ('a1f10001-0000-4000-8000-000000000001', 'c66f5587-677f-496d-91fd-45197a85c05d',
     'X-Ray Tube - 150kV Rotating Anode', 'XRAY-TUBE-150KV',
     'OEM rotating anode X-ray tube assembly, 150kV / 600mA, compatible with most fixed and mobile X-ray systems. Includes high-voltage connectors and oil-filled housing.',
     'imaging_radiology',
     ARRAY['imaging_radiology'], ARRAY['GE Healthcare','Siemens'], ARRAY['Optima XR220','Mobilett Mira Max'],
     85000.00, 120000.00, 6, 1, 'piece', true, true, 12, '90221400', 18.00),

    ('a1f10001-0000-4000-8000-000000000002', 'c66f5587-677f-496d-91fd-45197a85c05d',
     'CT Detector Module - 64 Slice', 'CT-DET-64S',
     'Replacement detector module for 64-slice CT scanners. Ceramic scintillator + photodiode array. Pre-calibrated, drop-in unit.',
     'imaging_radiology',
     ARRAY['imaging_radiology'], ARRAY['GE Healthcare','Philips'], ARRAY['Revolution CT','Brilliance 64'],
     245000.00, 320000.00, 2, 1, 'piece', true, true, 6, '90221400', 18.00),

    ('a1f10001-0000-4000-8000-000000000003', 'c66f5587-677f-496d-91fd-45197a85c05d',
     'MRI Gradient Coil Cooling Pump', 'MRI-GCP-001',
     'Closed-loop water cooling pump for 1.5T / 3.0T MRI gradient coils. Includes flow sensor and bypass valve.',
     'imaging_radiology',
     ARRAY['imaging_radiology'], ARRAY['Siemens','GE Healthcare'], ARRAY['Magnetom Aera','Signa Voyager'],
     58000.00, 82000.00, 4, 1, 'piece', true, false, 12, '84137010', 18.00),

    ('a1f10001-0000-4000-8000-000000000004', '0568ba15-56a9-483a-9a23-43d62c7faddf',
     'Ultrasound Transducer - Linear 7.5MHz', 'US-TRD-L75',
     'Linear array transducer, 7.5 MHz, 38mm footprint. Suitable for vascular, small parts, and musculoskeletal imaging.',
     'imaging_radiology',
     ARRAY['imaging_radiology'], ARRAY['Mindray','Samsung'], ARRAY['DC-70','HS40'],
     42000.00, 65000.00, 8, 1, 'piece', true, false, 6, '90181990', 12.00),

    -- Patient monitoring
    ('a1f10001-0000-4000-8000-000000000005', '0568ba15-56a9-483a-9a23-43d62c7faddf',
     'SpO2 Finger Sensor - Adult Reusable', 'SPO2-ADT-RU',
     'Adult reusable SpO2 finger clip sensor with DB9 connector. Soft silicone shell, 1.0m cable. Compatible with Masimo SET monitors.',
     'patient_monitoring',
     ARRAY['patient_monitoring'], ARRAY['Masimo','Nellcor'], ARRAY['Radical-7','PM-9000'],
     450.00, 850.00, 320, 1, 'piece', true, false, 6, '90189099', 12.00),

    ('a1f10001-0000-4000-8000-000000000006', '0568ba15-56a9-483a-9a23-43d62c7faddf',
     'ECG Patient Cable - 3 Lead AHA', 'ECG-3L-AHA',
     '3-lead patient cable with snap connectors, AHA color coding. 2.4m length, kink-resistant strain relief. For continuous bedside monitoring.',
     'patient_monitoring',
     ARRAY['patient_monitoring','cardiology'], ARRAY['Philips','Mindray','GE Healthcare'], ARRAY['IntelliVue MX450','iMEC12'],
     950.00, 1600.00, 180, 1, 'piece', true, false, 6, '90189099', 18.00),

    ('a1f10001-0000-4000-8000-000000000007', '0568ba15-56a9-483a-9a23-43d62c7faddf',
     'NIBP Cuff - Pediatric', 'NIBP-PED-01',
     'Reusable pediatric NIBP cuff, single-tube, hook-and-loop closure. Limb circumference 14-21.5 cm.',
     'patient_monitoring',
     ARRAY['patient_monitoring','neonatal'], ARRAY['Philips','Mindray'], ARRAY['IntelliVue MX450','iMEC12'],
     780.00, 1300.00, 220, 1, 'piece', true, false, 6, '90189099', 18.00),

    -- Surgical
    ('a1f10001-0000-4000-8000-000000000008', 'c66f5587-677f-496d-91fd-45197a85c05d',
     'Laparoscope Optic - 10mm 30 Degree', 'LAP-OPT-10-30',
     'Rigid laparoscope, 10mm diameter, 30-degree angle, autoclavable. HD optical resolution for general laparoscopy.',
     'surgical',
     ARRAY['surgical'], ARRAY['Karl Storz','Olympus'], ARRAY['Hopkins II','OTV-S190'],
     185000.00, 240000.00, 3, 1, 'piece', true, true, 12, '90189099', 18.00),

    ('a1f10001-0000-4000-8000-000000000009', '0568ba15-56a9-483a-9a23-43d62c7faddf',
     'Electrosurgical Pencil with Holster', 'ESU-PEN-HLD',
     'Disposable electrosurgical hand-control pencil with stainless blade electrode and holster. Sterile, single-patient use, box of 50.',
     'surgical',
     ARRAY['surgical'], ARRAY['Covidien','Erbe'], ARRAY['Force FX','VIO 300 D'],
     6500.00, 9500.00, 60, 1, 'piece', false, false, NULL, '90189099', 18.00),

    ('a1f10001-0000-4000-8000-00000000000a', 'c66f5587-677f-496d-91fd-45197a85c05d',
     'Surgical Light LED Bulb Module', 'SURG-LED-MOD',
     'Replacement LED module for ceiling-mounted surgical lights. 160,000 lux, 4500K color temperature, >50,000 hour rated life.',
     'surgical',
     ARRAY['surgical'], ARRAY['Maquet','Trumpf'], ARRAY['PowerLED 700','iLED 7'],
     32000.00, 48000.00, 10, 1, 'piece', true, true, 24, '94054090', 18.00),

    -- Laboratory
    ('a1f10001-0000-4000-8000-00000000000b', '0568ba15-56a9-483a-9a23-43d62c7faddf',
     'Centrifuge Rotor - 24 x 1.5ml', 'CENT-ROT-24',
     'Fixed-angle rotor for benchtop centrifuges, holds 24 x 1.5/2.0 ml microtubes. Aluminum, autoclavable, max 14,000 RPM.',
     'laboratory',
     ARRAY['laboratory'], ARRAY['Eppendorf','Thermo Fisher'], ARRAY['5424 R','Sorvall Legend Micro 17'],
     18500.00, 26000.00, 14, 1, 'piece', true, false, 12, '84211990', 18.00),

    ('a1f10001-0000-4000-8000-00000000000c', '0568ba15-56a9-483a-9a23-43d62c7faddf',
     'Pipette Tips - 200ul Sterile (Pack of 960)', 'PIP-TIP-200',
     'Universal-fit 200ul pipette tips, DNase/RNase free, sterile, racked. 10 racks of 96 tips per case.',
     'laboratory',
     ARRAY['laboratory'], ARRAY['Eppendorf','Gilson'], ARRAY[]::text[],
     2400.00, 3600.00, 400, 1, 'piece', false, false, NULL, '39239090', 18.00),

    ('a1f10001-0000-4000-8000-00000000000d', '0568ba15-56a9-483a-9a23-43d62c7faddf',
     'Microscope LED Illumination Bulb', 'MIC-LED-BLB',
     'Plug-in LED illumination unit for compound microscopes. 5W, 6500K daylight, replaces 30W halogen.',
     'laboratory',
     ARRAY['laboratory'], ARRAY['Olympus','Leica','Nikon'], ARRAY['CX23','DM500'],
     3200.00, 4800.00, 75, 1, 'piece', true, false, 12, '85393190', 18.00),

    -- Respiratory / life support
    ('a1f10001-0000-4000-8000-00000000000e', 'c66f5587-677f-496d-91fd-45197a85c05d',
     'Ventilator Expiratory Membrane', 'VENT-EXP-MEM',
     'Silicone expiratory valve membrane for ICU ventilators. Autoclavable, replace every 6 months or 1000 hours.',
     'life_support',
     ARRAY['life_support'], ARRAY['Drager','Hamilton'], ARRAY['Evita V300','HAMILTON-C3'],
     4200.00, 6500.00, 90, 1, 'piece', true, true, 6, '40169330', 18.00),

    ('a1f10001-0000-4000-8000-00000000000f', '0568ba15-56a9-483a-9a23-43d62c7faddf',
     'BVM Resuscitator Mask - Adult', 'BVM-MSK-ADT',
     'Silicone bag-valve-mask resuscitator, adult size #5, anatomical seal. Reusable, autoclavable up to 134C.',
     'life_support',
     ARRAY['life_support'], ARRAY['Ambu','Laerdal'], ARRAY['SPUR II','The Bag II'],
     2800.00, 4200.00, 110, 1, 'piece', true, false, 12, '90192090', 12.00),

    ('a1f10001-0000-4000-8000-000000000010', '0568ba15-56a9-483a-9a23-43d62c7faddf',
     'Oxygen Concentrator Sieve Bed', 'OXY-SIEVE-5L',
     'Replacement zeolite molecular sieve bed for 5L oxygen concentrators. Improves O2 purity to 93% +/- 3%.',
     'life_support',
     ARRAY['life_support'], ARRAY['Philips','Invacare'], ARRAY['EverFlo','Perfecto2'],
     7800.00, 11000.00, 22, 1, 'piece', true, false, 12, '90192090', 18.00),

    -- Sterilization
    ('a1f10001-0000-4000-8000-000000000011', '0568ba15-56a9-483a-9a23-43d62c7faddf',
     'Autoclave Door Gasket - 23L', 'ATC-GSK-23L',
     'Silicone door gasket for 23L benchtop autoclaves. Heat-resistant to 140C, easy snap-fit replacement.',
     'sterilization',
     ARRAY['sterilization'], ARRAY['Tuttnauer','Midmark'], ARRAY['2540M','M11'],
     1800.00, 2700.00, 65, 1, 'piece', true, false, 6, '40169330', 18.00),

    ('a1f10001-0000-4000-8000-000000000012', 'c66f5587-677f-496d-91fd-45197a85c05d',
     'Autoclave Heating Element - 2kW', 'ATC-HEAT-2KW',
     '2kW immersion heating element for steam autoclaves. Stainless steel sheath, screw-in fitting, 230V AC.',
     'sterilization',
     ARRAY['sterilization'], ARRAY['Tuttnauer','Yamato'], ARRAY['2540M','SM510'],
     5400.00, 7800.00, 18, 1, 'piece', true, true, 12, '85162900', 18.00)
) AS v(
  id, supplier_org_id, name, part_number, description, category,
  compatible_equipment_categories, compatible_brands, compatible_models,
  price, mrp, stock_quantity, minimum_order_quantity, unit,
  is_genuine, is_oem, warranty_months, hsn_code, gst_rate
)
WHERE EXISTS (
  SELECT 1 FROM public.organizations o WHERE o.id = v.supplier_org_id::uuid
)
ON CONFLICT (id) DO NOTHING;

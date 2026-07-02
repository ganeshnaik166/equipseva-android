-- Round r2999: Hospital Chain Quarterly OT-Table Hydraulic-System Leak & Pump Diagnostic Audit
-- HEAVY ★★★★ — r3000 milestone batch

create table if not exists ot_table_hydraulic_audits_r2999 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  chain_name text not null,
  hospital_site text not null,
  ot_room_code text not null,
  table_asset_tag text not null,
  table_model text not null,
  table_manufacturer text not null check (table_manufacturer in ('maquet','steris','mizuho','skytron','trumpf','hill_rom','schaerer')),
  audit_quarter text not null check (audit_quarter in ('q1_2026','q2_2026','q3_2026','q4_2026','q1_2027')),
  audit_date date not null,
  hydraulic_fluid_type text not null check (hydraulic_fluid_type in ('iso_vg32','iso_vg46','iso_vg68','biodegradable_hetg','phosphate_ester','mineral_oil')),
  fluid_level_pct numeric(5,2) not null,
  fluid_color_grade text not null check (fluid_color_grade in ('clear','pale_yellow','amber','dark_amber','brown','black_contaminated')),
  fluid_particle_count_iso text not null check (fluid_particle_count_iso in ('iso_14_11_8','iso_16_13_10','iso_18_15_12','iso_20_17_14','iso_22_19_16','iso_above_22')),
  pump_pressure_bar numeric(6,2) not null,
  pump_pressure_spec_bar numeric(6,2) not null,
  cylinder_leak_rate_ml_min numeric(7,3) not null,
  cylinder_leak_threshold_ml_min numeric(7,3) not null default 2.5,
  reservoir_temp_celsius numeric(5,2) not null,
  hose_inspection_result text not null check (hose_inspection_result in ('pass','minor_seepage','active_leak','bulging','replaced','fail')),
  seal_condition text not null check (seal_condition in ('new','good','worn','cracked','leaking','failed')),
  pump_motor_amperage_a numeric(5,2) not null,
  pump_motor_amperage_spec_a numeric(5,2) not null,
  trendelenburg_angle_test_deg numeric(5,2) not null,
  reverse_trendelenburg_angle_deg numeric(5,2) not null,
  lateral_tilt_max_deg numeric(5,2) not null,
  height_min_cm numeric(5,2) not null,
  height_max_cm numeric(5,2) not null,
  load_test_kg_held numeric(6,2) not null,
  drift_under_load_mm_per_hr numeric(6,3) not null,
  noise_level_db numeric(5,2) not null,
  emergency_lower_test_sec numeric(5,2) not null,
  overall_audit_grade text not null check (overall_audit_grade in ('a_excellent','b_good','c_acceptable','d_marginal','e_fail','f_immediate_shutdown')),
  remediation_status text not null check (remediation_status in ('not_required','scheduled','parts_ordered','work_started','completed','escalated_to_oem','condemned')),
  estimated_repair_cost_rupees numeric(12,2) not null default 0,
  next_audit_due date,
  ot_downtime_risk text not null check (ot_downtime_risk in ('none','low','medium','high','critical')),
  engineer_certification_level text not null check (engineer_certification_level in ('l1_trainee','l2_certified','l3_senior','l4_oem_trained','l5_master'))
);

alter table ot_table_hydraulic_audits_r2999 enable row level security;

drop policy if exists ot_table_hydraulic_audits_r2999_founder_select on ot_table_hydraulic_audits_r2999;
create policy ot_table_hydraulic_audits_r2999_founder_select on ot_table_hydraulic_audits_r2999 for select to authenticated using (is_founder());

create table if not exists ot_table_pump_diagnostic_findings_r2999 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  audit_id uuid not null references ot_table_hydraulic_audits_r2999(id) on delete cascade,
  finding_category text not null check (finding_category in ('hydraulic_leak','pump_degradation','seal_failure','fluid_contamination','motor_anomaly','sensor_drift','mechanical_wear','electrical_fault','safety_interlock','calibration_drift')),
  severity text not null check (severity in ('informational','low','medium','high','critical','life_safety')),
  component_affected text not null check (component_affected in ('main_pump','aux_pump','lift_cylinder','tilt_cylinder','reservoir','hose_assembly','manifold_block','accumulator','pressure_relief_valve','control_solenoid','foot_pedal','manual_override')),
  measured_value text not null,
  spec_value text not null,
  deviation_pct numeric(7,2) not null,
  recommended_action text not null check (recommended_action in ('monitor','replace_seal','replace_hose','flush_and_refill','rebuild_pump','replace_pump','recalibrate','oem_service','condemn_table','immediate_quarantine')),
  parts_needed text not null,
  parts_cost_rupees numeric(10,2) not null default 0,
  labor_hours_estimate numeric(5,2) not null default 0,
  oem_warranty_active boolean not null default false,
  finding_status text not null check (finding_status in ('open','acknowledged','parts_ordered','work_started','work_complete','verified','closed','deferred')),
  reported_by_engineer text not null
);

alter table ot_table_pump_diagnostic_findings_r2999 enable row level security;

drop policy if exists ot_table_pump_diagnostic_findings_r2999_founder_select on ot_table_pump_diagnostic_findings_r2999;
create policy ot_table_pump_diagnostic_findings_r2999_founder_select on ot_table_pump_diagnostic_findings_r2999 for select to authenticated using (is_founder());

-- Seed audits (20 rows)
insert into ot_table_hydraulic_audits_r2999 (chain_name, hospital_site, ot_room_code, table_asset_tag, table_model, table_manufacturer, audit_quarter, audit_date, hydraulic_fluid_type, fluid_level_pct, fluid_color_grade, fluid_particle_count_iso, pump_pressure_bar, pump_pressure_spec_bar, cylinder_leak_rate_ml_min, reservoir_temp_celsius, hose_inspection_result, seal_condition, pump_motor_amperage_a, pump_motor_amperage_spec_a, trendelenburg_angle_test_deg, reverse_trendelenburg_angle_deg, lateral_tilt_max_deg, height_min_cm, height_max_cm, load_test_kg_held, drift_under_load_mm_per_hr, noise_level_db, emergency_lower_test_sec, overall_audit_grade, remediation_status, estimated_repair_cost_rupees, next_audit_due, ot_downtime_risk, engineer_certification_level) values
('Apollo Hospitals','Apollo Jubilee Hills','OT-01','EQS-OT-A001','Magnus 1180','maquet','q2_2026','2026-06-15'::date,'iso_vg46',96.5,'pale_yellow','iso_16_13_10',180.2,180.0,0.85,42.3,'pass','good',4.2,4.5,30.0,30.0,20.0,68.0,118.0,360.0,0.8,52.3,8.5,'a_excellent','not_required',0,'2026-09-15'::date,'none','l4_oem_trained'),
('Apollo Hospitals','Apollo Hyderguda','OT-03','EQS-OT-A007','Cmax','steris','q2_2026','2026-06-12'::date,'iso_vg46',88.0,'amber','iso_18_15_12',172.0,180.0,2.10,46.8,'minor_seepage','worn',4.8,4.5,29.5,28.0,19.0,70.0,115.0,355.0,2.4,55.1,9.2,'b_good','scheduled',45000,'2026-09-12'::date,'low','l3_senior'),
('Fortis Healthcare','Fortis Bannerghatta','OT-02','EQS-OT-F012','MTC-2200','mizuho','q2_2026','2026-06-10'::date,'iso_vg32',72.5,'dark_amber','iso_20_17_14',155.5,170.0,3.80,52.1,'active_leak','cracked',5.4,4.8,27.0,26.5,17.5,72.0,112.0,340.0,4.2,58.7,11.5,'d_marginal','work_started',185000,'2026-07-10'::date,'high','l3_senior'),
('Fortis Healthcare','Fortis Mulund','OT-05','EQS-OT-F018','UFSK 1907','schaerer','q2_2026','2026-06-08'::date,'iso_vg68',92.0,'pale_yellow','iso_16_13_10',195.0,195.0,1.20,41.5,'pass','good',5.1,5.0,30.0,30.0,20.0,65.0,120.0,365.0,1.0,51.8,8.0,'a_excellent','not_required',0,'2026-09-08'::date,'none','l5_master'),
('Manipal Hospitals','Manipal Old Airport','OT-04','EQS-OT-M023','TruSystem 7500','trumpf','q2_2026','2026-06-05'::date,'biodegradable_hetg',94.5,'clear','iso_14_11_8',210.0,210.0,0.55,40.0,'pass','new',4.6,4.5,30.0,30.0,20.0,67.0,122.0,400.0,0.5,49.2,7.5,'a_excellent','not_required',0,'2026-09-05'::date,'none','l5_master'),
('Manipal Hospitals','Manipal HAL','OT-02','EQS-OT-M029','Magnus 1180','maquet','q1_2026','2026-03-22'::date,'iso_vg46',45.0,'black_contaminated','iso_above_22',98.5,180.0,8.50,68.3,'fail','failed',7.2,4.5,18.0,16.0,12.0,75.0,105.0,280.0,15.6,72.4,22.8,'f_immediate_shutdown','condemned',0,'2026-09-22'::date,'critical','l4_oem_trained'),
('Max Healthcare','Max Saket','OT-01','EQS-OT-X034','Cmax','steris','q2_2026','2026-06-18'::date,'iso_vg46',91.0,'pale_yellow','iso_16_13_10',178.5,180.0,1.45,43.8,'pass','good',4.6,4.5,29.8,29.5,19.8,68.5,118.5,355.0,1.3,53.0,8.8,'a_excellent','not_required',0,'2026-09-18'::date,'none','l3_senior'),
('Max Healthcare','Max Patparganj','OT-06','EQS-OT-X041','MTC-2200','mizuho','q2_2026','2026-06-14'::date,'iso_vg32',83.5,'amber','iso_18_15_12',165.0,170.0,2.65,48.2,'minor_seepage','worn',5.0,4.8,29.0,28.5,18.5,71.0,113.0,348.0,2.8,56.4,9.8,'c_acceptable','parts_ordered',62000,'2026-08-14'::date,'medium','l3_senior'),
('Narayana Health','NH Bommasandra','OT-03','EQS-OT-N048','TruSystem 7500','trumpf','q2_2026','2026-06-11'::date,'biodegradable_hetg',93.0,'clear','iso_14_11_8',208.0,210.0,0.70,40.8,'pass','new',4.7,4.5,30.0,30.0,20.0,66.5,121.5,395.0,0.6,50.0,7.8,'a_excellent','not_required',0,'2026-09-11'::date,'none','l4_oem_trained'),
('Narayana Health','NH HSR','OT-01','EQS-OT-N053','UFSK 1907','schaerer','q2_2026','2026-06-09'::date,'iso_vg68',76.0,'dark_amber','iso_20_17_14',148.0,195.0,4.20,55.6,'bulging','cracked',6.1,5.0,26.5,25.0,16.5,73.0,111.0,335.0,5.4,61.2,13.2,'d_marginal','escalated_to_oem',225000,'2026-07-09'::date,'high','l4_oem_trained'),
('Yashoda Hospitals','Yashoda Secunderabad','OT-02','EQS-OT-Y061','Cmax','steris','q2_2026','2026-06-16'::date,'iso_vg46',89.5,'pale_yellow','iso_16_13_10',176.0,180.0,1.85,44.5,'pass','good',4.7,4.5,29.5,29.0,19.5,69.0,117.5,352.0,1.7,54.0,9.0,'b_good','scheduled',28000,'2026-09-16'::date,'low','l3_senior'),
('Yashoda Hospitals','Yashoda Somajiguda','OT-04','EQS-OT-Y068','Magnus 1180','maquet','q2_2026','2026-06-13'::date,'iso_vg46',81.0,'amber','iso_18_15_12',168.5,180.0,2.95,49.8,'minor_seepage','worn',5.2,4.5,28.5,27.5,18.0,71.5,112.5,345.0,3.2,57.5,10.5,'c_acceptable','work_started',95000,'2026-08-13'::date,'medium','l3_senior'),
('Aster DM','Aster CMI','OT-05','EQS-OT-S075','MTC-2200','mizuho','q2_2026','2026-06-07'::date,'iso_vg32',94.0,'clear','iso_14_11_8',172.0,170.0,0.95,42.0,'pass','new',4.7,4.8,30.0,30.0,20.0,69.5,116.0,358.0,0.9,52.0,8.3,'a_excellent','not_required',0,'2026-09-07'::date,'none','l4_oem_trained'),
('Aster DM','Aster Whitefield','OT-02','EQS-OT-S082','Lemur','hill_rom','q2_2026','2026-06-04'::date,'mineral_oil',58.0,'brown','iso_22_19_16',128.0,165.0,5.80,62.5,'active_leak','leaking',6.8,4.6,22.0,20.0,14.0,74.5,108.0,310.0,9.5,66.8,16.4,'e_fail','escalated_to_oem',310000,'2026-07-04'::date,'critical','l4_oem_trained'),
('KIMS','KIMS Kondapur','OT-01','EQS-OT-K089','Magnus 1180','maquet','q2_2026','2026-06-17'::date,'iso_vg46',95.5,'clear','iso_14_11_8',182.0,180.0,0.68,41.0,'pass','new',4.4,4.5,30.0,30.0,20.0,68.0,118.0,360.0,0.6,50.5,7.7,'a_excellent','not_required',0,'2026-09-17'::date,'none','l5_master'),
('KIMS','KIMS Begumpet','OT-03','EQS-OT-K094','UFSK 1907','schaerer','q2_2026','2026-06-06'::date,'iso_vg68',87.0,'pale_yellow','iso_16_13_10',191.0,195.0,1.55,43.0,'pass','good',4.9,5.0,30.0,29.8,19.8,66.0,120.5,360.0,1.4,52.6,8.4,'a_excellent','not_required',0,'2026-09-06'::date,'none','l4_oem_trained'),
('Continental','Continental Gachibowli','OT-02','EQS-OT-C101','TruSystem 7500','trumpf','q1_2026','2026-03-15'::date,'biodegradable_hetg',62.0,'dark_amber','iso_20_17_14',142.0,210.0,4.65,57.2,'bulging','cracked',6.3,4.5,25.0,23.5,15.5,73.5,109.5,328.0,6.8,63.5,14.6,'e_fail','completed',265000,'2026-06-15'::date,'high','l5_master'),
('Continental','Continental Nallagandla','OT-04','EQS-OT-C108','Cmax','steris','q2_2026','2026-06-19'::date,'iso_vg46',90.0,'pale_yellow','iso_16_13_10',179.0,180.0,1.65,43.5,'pass','good',4.6,4.5,29.7,29.4,19.6,68.8,118.2,353.0,1.5,53.4,8.6,'b_good','not_required',0,'2026-09-19'::date,'low','l3_senior'),
('Rainbow Children','Rainbow Banjara','OT-01','EQS-OT-R115','MTC-2200','mizuho','q2_2026','2026-06-03'::date,'iso_vg32',92.5,'clear','iso_14_11_8',171.0,170.0,1.05,42.5,'pass','new',4.8,4.8,30.0,30.0,20.0,70.0,115.5,355.0,1.0,51.5,8.1,'a_excellent','not_required',0,'2026-09-03'::date,'none','l4_oem_trained'),
('Rainbow Children','Rainbow Vikrampuri','OT-02','EQS-OT-R122','Lemur','hill_rom','q2_2026','2026-06-02'::date,'mineral_oil',79.0,'amber','iso_18_15_12',158.0,165.0,3.10,50.5,'minor_seepage','worn',5.3,4.6,28.0,27.0,17.5,72.0,112.0,342.0,3.6,58.2,11.0,'c_acceptable','parts_ordered',78000,'2026-08-02'::date,'medium','l3_senior');

-- Seed findings (24 rows) - reference audits by chain+room
insert into ot_table_pump_diagnostic_findings_r2999 (audit_id, finding_category, severity, component_affected, measured_value, spec_value, deviation_pct, recommended_action, parts_needed, parts_cost_rupees, labor_hours_estimate, oem_warranty_active, finding_status, reported_by_engineer)
select id, 'fluid_contamination','high','reservoir','iso_above_22','iso_16_13_10',180.5,'flush_and_refill','15L ISO VG46 hydraulic fluid + 2 filter cartridges',18500,3.5,false,'verified','Ramesh Kumar (L4)' from ot_table_hydraulic_audits_r2999 where table_asset_tag='EQS-OT-M029' limit 1;
insert into ot_table_pump_diagnostic_findings_r2999 (audit_id, finding_category, severity, component_affected, measured_value, spec_value, deviation_pct, recommended_action, parts_needed, parts_cost_rupees, labor_hours_estimate, oem_warranty_active, finding_status, reported_by_engineer)
select id, 'pump_degradation','critical','main_pump','98.5 bar','180 bar',45.2,'replace_pump','Maquet OEM hydraulic pump assembly + mounting kit',145000,8.0,false,'work_complete','Ramesh Kumar (L4)' from ot_table_hydraulic_audits_r2999 where table_asset_tag='EQS-OT-M029' limit 1;
insert into ot_table_pump_diagnostic_findings_r2999 (audit_id, finding_category, severity, component_affected, measured_value, spec_value, deviation_pct, recommended_action, parts_needed, parts_cost_rupees, labor_hours_estimate, oem_warranty_active, finding_status, reported_by_engineer)
select id, 'seal_failure','critical','lift_cylinder','failed','new',100.0,'condemn_table','N/A - table beyond economic repair',0,2.0,false,'closed','Ramesh Kumar (L4)' from ot_table_hydraulic_audits_r2999 where table_asset_tag='EQS-OT-M029' limit 1;
insert into ot_table_pump_diagnostic_findings_r2999 (audit_id, finding_category, severity, component_affected, measured_value, spec_value, deviation_pct, recommended_action, parts_needed, parts_cost_rupees, labor_hours_estimate, oem_warranty_active, finding_status, reported_by_engineer)
select id, 'hydraulic_leak','high','hose_assembly','3.80 ml/min','2.5 ml/min',52.0,'replace_hose','Mizuho high-pressure hose set (3 hoses)',42000,4.0,true,'work_started','Sneha Reddy (L3)' from ot_table_hydraulic_audits_r2999 where table_asset_tag='EQS-OT-F012' limit 1;
insert into ot_table_pump_diagnostic_findings_r2999 (audit_id, finding_category, severity, component_affected, measured_value, spec_value, deviation_pct, recommended_action, parts_needed, parts_cost_rupees, labor_hours_estimate, oem_warranty_active, finding_status, reported_by_engineer)
select id, 'seal_failure','high','tilt_cylinder','cracked','good',100.0,'replace_seal','Cylinder seal kit OEM Mizuho',12500,3.0,true,'parts_ordered','Sneha Reddy (L3)' from ot_table_hydraulic_audits_r2999 where table_asset_tag='EQS-OT-F012' limit 1;
insert into ot_table_pump_diagnostic_findings_r2999 (audit_id, finding_category, severity, component_affected, measured_value, spec_value, deviation_pct, recommended_action, parts_needed, parts_cost_rupees, labor_hours_estimate, oem_warranty_active, finding_status, reported_by_engineer)
select id, 'motor_anomaly','medium','main_pump','5.4 A','4.8 A',12.5,'monitor','Continued amperage monitoring',0,1.0,true,'acknowledged','Sneha Reddy (L3)' from ot_table_hydraulic_audits_r2999 where table_asset_tag='EQS-OT-F012' limit 1;
insert into ot_table_pump_diagnostic_findings_r2999 (audit_id, finding_category, severity, component_affected, measured_value, spec_value, deviation_pct, recommended_action, parts_needed, parts_cost_rupees, labor_hours_estimate, oem_warranty_active, finding_status, reported_by_engineer)
select id, 'hydraulic_leak','critical','manifold_block','5.80 ml/min','2.5 ml/min',132.0,'rebuild_pump','Hill-Rom Lemur manifold rebuild kit',95000,6.5,false,'work_started','Vikram Singh (L4)' from ot_table_hydraulic_audits_r2999 where table_asset_tag='EQS-OT-S082' limit 1;
insert into ot_table_pump_diagnostic_findings_r2999 (audit_id, finding_category, severity, component_affected, measured_value, spec_value, deviation_pct, recommended_action, parts_needed, parts_cost_rupees, labor_hours_estimate, oem_warranty_active, finding_status, reported_by_engineer)
select id, 'pump_degradation','critical','aux_pump','128 bar','165 bar',22.4,'replace_pump','Hill-Rom Lemur aux hydraulic pump',135000,7.0,false,'parts_ordered','Vikram Singh (L4)' from ot_table_hydraulic_audits_r2999 where table_asset_tag='EQS-OT-S082' limit 1;
insert into ot_table_pump_diagnostic_findings_r2999 (audit_id, finding_category, severity, component_affected, measured_value, spec_value, deviation_pct, recommended_action, parts_needed, parts_cost_rupees, labor_hours_estimate, oem_warranty_active, finding_status, reported_by_engineer)
select id, 'fluid_contamination','high','reservoir','iso_22_19_16','iso_16_13_10',125.0,'flush_and_refill','20L mineral oil + 3 micron filter set',24000,4.0,false,'open','Vikram Singh (L4)' from ot_table_hydraulic_audits_r2999 where table_asset_tag='EQS-OT-S082' limit 1;
insert into ot_table_pump_diagnostic_findings_r2999 (audit_id, finding_category, severity, component_affected, measured_value, spec_value, deviation_pct, recommended_action, parts_needed, parts_cost_rupees, labor_hours_estimate, oem_warranty_active, finding_status, reported_by_engineer)
select id, 'mechanical_wear','high','hose_assembly','bulging','pass',100.0,'replace_hose','Schaerer UFSK hose set + clamps',55000,3.5,true,'parts_ordered','Arjun Patel (L4)' from ot_table_hydraulic_audits_r2999 where table_asset_tag='EQS-OT-N053' limit 1;
insert into ot_table_pump_diagnostic_findings_r2999 (audit_id, finding_category, severity, component_affected, measured_value, spec_value, deviation_pct, recommended_action, parts_needed, parts_cost_rupees, labor_hours_estimate, oem_warranty_active, finding_status, reported_by_engineer)
select id, 'pump_degradation','high','main_pump','148 bar','195 bar',24.1,'oem_service','OEM Schaerer service contract',125000,12.0,true,'open','Arjun Patel (L4)' from ot_table_hydraulic_audits_r2999 where table_asset_tag='EQS-OT-N053' limit 1;
insert into ot_table_pump_diagnostic_findings_r2999 (audit_id, finding_category, severity, component_affected, measured_value, spec_value, deviation_pct, recommended_action, parts_needed, parts_cost_rupees, labor_hours_estimate, oem_warranty_active, finding_status, reported_by_engineer)
select id, 'seal_failure','medium','lift_cylinder','cracked','good',100.0,'replace_seal','UFSK lift cylinder seal kit',18000,3.0,true,'open','Arjun Patel (L4)' from ot_table_hydraulic_audits_r2999 where table_asset_tag='EQS-OT-N053' limit 1;
insert into ot_table_pump_diagnostic_findings_r2999 (audit_id, finding_category, severity, component_affected, measured_value, spec_value, deviation_pct, recommended_action, parts_needed, parts_cost_rupees, labor_hours_estimate, oem_warranty_active, finding_status, reported_by_engineer)
select id, 'hydraulic_leak','medium','hose_assembly','2.10 ml/min','2.5 ml/min',-16.0,'monitor','Trend monitoring next quarter',0,0.5,false,'acknowledged','Priya Iyer (L3)' from ot_table_hydraulic_audits_r2999 where table_asset_tag='EQS-OT-A007' limit 1;
insert into ot_table_pump_diagnostic_findings_r2999 (audit_id, finding_category, severity, component_affected, measured_value, spec_value, deviation_pct, recommended_action, parts_needed, parts_cost_rupees, labor_hours_estimate, oem_warranty_active, finding_status, reported_by_engineer)
select id, 'seal_failure','medium','tilt_cylinder','worn','good',60.0,'replace_seal','Steris Cmax tilt seal',15000,2.5,false,'parts_ordered','Priya Iyer (L3)' from ot_table_hydraulic_audits_r2999 where table_asset_tag='EQS-OT-A007' limit 1;
insert into ot_table_pump_diagnostic_findings_r2999 (audit_id, finding_category, severity, component_affected, measured_value, spec_value, deviation_pct, recommended_action, parts_needed, parts_cost_rupees, labor_hours_estimate, oem_warranty_active, finding_status, reported_by_engineer)
select id, 'fluid_contamination','low','reservoir','iso_18_15_12','iso_16_13_10',25.0,'flush_and_refill','5L top-up + filter swap',8500,1.5,false,'verified','Priya Iyer (L3)' from ot_table_hydraulic_audits_r2999 where table_asset_tag='EQS-OT-A007' limit 1;
insert into ot_table_pump_diagnostic_findings_r2999 (audit_id, finding_category, severity, component_affected, measured_value, spec_value, deviation_pct, recommended_action, parts_needed, parts_cost_rupees, labor_hours_estimate, oem_warranty_active, finding_status, reported_by_engineer)
select id, 'mechanical_wear','medium','tilt_cylinder','worn','good',55.0,'replace_seal','Mizuho MTC tilt seal kit',14500,2.5,false,'parts_ordered','Karan Mehta (L3)' from ot_table_hydraulic_audits_r2999 where table_asset_tag='EQS-OT-X041' limit 1;
insert into ot_table_pump_diagnostic_findings_r2999 (audit_id, finding_category, severity, component_affected, measured_value, spec_value, deviation_pct, recommended_action, parts_needed, parts_cost_rupees, labor_hours_estimate, oem_warranty_active, finding_status, reported_by_engineer)
select id, 'hydraulic_leak','medium','hose_assembly','2.65 ml/min','2.5 ml/min',6.0,'replace_hose','Mizuho hose assembly',32000,3.0,false,'parts_ordered','Karan Mehta (L3)' from ot_table_hydraulic_audits_r2999 where table_asset_tag='EQS-OT-X041' limit 1;
insert into ot_table_pump_diagnostic_findings_r2999 (audit_id, finding_category, severity, component_affected, measured_value, spec_value, deviation_pct, recommended_action, parts_needed, parts_cost_rupees, labor_hours_estimate, oem_warranty_active, finding_status, reported_by_engineer)
select id, 'hydraulic_leak','high','manifold_block','4.65 ml/min','2.5 ml/min',86.0,'rebuild_pump','Trumpf TruSystem rebuild kit',185000,9.0,false,'work_complete','Aditya Bose (L5)' from ot_table_hydraulic_audits_r2999 where table_asset_tag='EQS-OT-C101' limit 1;
insert into ot_table_pump_diagnostic_findings_r2999 (audit_id, finding_category, severity, component_affected, measured_value, spec_value, deviation_pct, recommended_action, parts_needed, parts_cost_rupees, labor_hours_estimate, oem_warranty_active, finding_status, reported_by_engineer)
select id, 'seal_failure','high','accumulator','cracked','good',100.0,'replace_seal','Trumpf accumulator seal',28000,4.0,false,'verified','Aditya Bose (L5)' from ot_table_hydraulic_audits_r2999 where table_asset_tag='EQS-OT-C101' limit 1;
insert into ot_table_pump_diagnostic_findings_r2999 (audit_id, finding_category, severity, component_affected, measured_value, spec_value, deviation_pct, recommended_action, parts_needed, parts_cost_rupees, labor_hours_estimate, oem_warranty_active, finding_status, reported_by_engineer)
select id, 'calibration_drift','low','foot_pedal','drift +2.1°','±0.5°',320.0,'recalibrate','Calibration service only',0,1.5,true,'closed','Aditya Bose (L5)' from ot_table_hydraulic_audits_r2999 where table_asset_tag='EQS-OT-C101' limit 1;
insert into ot_table_pump_diagnostic_findings_r2999 (audit_id, finding_category, severity, component_affected, measured_value, spec_value, deviation_pct, recommended_action, parts_needed, parts_cost_rupees, labor_hours_estimate, oem_warranty_active, finding_status, reported_by_engineer)
select id, 'mechanical_wear','low','tilt_cylinder','worn','good',45.0,'replace_seal','Hill-Rom Lemur seal kit',16500,2.0,false,'parts_ordered','Nisha Rao (L3)' from ot_table_hydraulic_audits_r2999 where table_asset_tag='EQS-OT-R122' limit 1;
insert into ot_table_pump_diagnostic_findings_r2999 (audit_id, finding_category, severity, component_affected, measured_value, spec_value, deviation_pct, recommended_action, parts_needed, parts_cost_rupees, labor_hours_estimate, oem_warranty_active, finding_status, reported_by_engineer)
select id, 'hydraulic_leak','medium','hose_assembly','3.10 ml/min','2.5 ml/min',24.0,'replace_hose','Hill-Rom hose set',38000,3.5,false,'open','Nisha Rao (L3)' from ot_table_hydraulic_audits_r2999 where table_asset_tag='EQS-OT-R122' limit 1;
insert into ot_table_pump_diagnostic_findings_r2999 (audit_id, finding_category, severity, component_affected, measured_value, spec_value, deviation_pct, recommended_action, parts_needed, parts_cost_rupees, labor_hours_estimate, oem_warranty_active, finding_status, reported_by_engineer)
select id, 'electrical_fault','medium','control_solenoid','intermittent','steady',0.0,'oem_service','Solenoid control board diagnosis',22000,3.0,false,'work_started','Aditya Bose (L5)' from ot_table_hydraulic_audits_r2999 where table_asset_tag='EQS-OT-Y068' limit 1;

-- RPC 1: chain rollup
create or replace function rpc_r2999_chain_rollup()
returns table (chain_name text, audits_count int, fail_or_shutdown_count int, avg_leak_rate numeric, total_repair_cost numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not authorized'; end if;
  return query
    select a.chain_name,
      count(*)::int,
      (count(*) filter (where a.overall_audit_grade in ('e_fail','f_immediate_shutdown')))::int,
      round(avg(a.cylinder_leak_rate_ml_min)::numeric, 3),
      round(sum(a.estimated_repair_cost_rupees)::numeric, 2)
    from ot_table_hydraulic_audits_r2999 a
    group by a.chain_name
    order by sum(a.estimated_repair_cost_rupees) desc;
end; $$;
revoke all on function rpc_r2999_chain_rollup() from public, anon;
grant execute on function rpc_r2999_chain_rollup() to authenticated;

-- RPC 2: grade distribution
create or replace function rpc_r2999_grade_distribution()
returns table (grade text, audits_count int, pct_of_total numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
declare total int;
begin
  if not is_founder() then raise exception 'not authorized'; end if;
  select count(*)::int into total from ot_table_hydraulic_audits_r2999;
  return query
    select a.overall_audit_grade,
      count(*)::int,
      round((count(*)::numeric / nullif(total,0) * 100)::numeric, 2)
    from ot_table_hydraulic_audits_r2999 a
    group by a.overall_audit_grade
    order by a.overall_audit_grade;
end; $$;
revoke all on function rpc_r2999_grade_distribution() from public, anon;
grant execute on function rpc_r2999_grade_distribution() to authenticated;

-- RPC 3: critical findings
create or replace function rpc_r2999_critical_findings()
returns table (chain_name text, hospital_site text, ot_room_code text, table_model text, finding_category text, severity text, component_affected text, deviation_pct numeric, parts_cost_rupees numeric, finding_status text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not authorized'; end if;
  return query
    select a.chain_name, a.hospital_site, a.ot_room_code, a.table_model,
      f.finding_category, f.severity, f.component_affected, f.deviation_pct, f.parts_cost_rupees, f.finding_status
    from ot_table_pump_diagnostic_findings_r2999 f
    join ot_table_hydraulic_audits_r2999 a on a.id = f.audit_id
    where f.severity in ('critical','life_safety','high')
    order by f.severity, f.deviation_pct desc;
end; $$;
revoke all on function rpc_r2999_critical_findings() from public, anon;
grant execute on function rpc_r2999_critical_findings() to authenticated;

-- RPC 4: manufacturer reliability
create or replace function rpc_r2999_manufacturer_reliability()
returns table (manufacturer text, tables_audited int, avg_leak_rate numeric, fail_count int, avg_repair_cost numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not authorized'; end if;
  return query
    select a.table_manufacturer,
      count(*)::int,
      round(avg(a.cylinder_leak_rate_ml_min)::numeric, 3),
      (count(*) filter (where a.overall_audit_grade in ('d_marginal','e_fail','f_immediate_shutdown')))::int,
      round(avg(a.estimated_repair_cost_rupees)::numeric, 2)
    from ot_table_hydraulic_audits_r2999 a
    group by a.table_manufacturer
    order by avg(a.cylinder_leak_rate_ml_min) desc;
end; $$;
revoke all on function rpc_r2999_manufacturer_reliability() from public, anon;
grant execute on function rpc_r2999_manufacturer_reliability() to authenticated;

-- RPC 5: fluid contamination watch
create or replace function rpc_r2999_fluid_contamination_watch()
returns table (chain_name text, hospital_site text, ot_room_code text, fluid_color_grade text, particle_iso text, fluid_level_pct numeric, reservoir_temp_celsius numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not authorized'; end if;
  return query
    select a.chain_name, a.hospital_site, a.ot_room_code, a.fluid_color_grade, a.fluid_particle_count_iso, a.fluid_level_pct, a.reservoir_temp_celsius
    from ot_table_hydraulic_audits_r2999 a
    where a.fluid_color_grade in ('dark_amber','brown','black_contaminated')
       or a.fluid_particle_count_iso in ('iso_20_17_14','iso_22_19_16','iso_above_22')
       or a.fluid_level_pct < 80
    order by a.fluid_level_pct asc;
end; $$;
revoke all on function rpc_r2999_fluid_contamination_watch() from public, anon;
grant execute on function rpc_r2999_fluid_contamination_watch() to authenticated;

-- RPC 6: remediation pipeline
create or replace function rpc_r2999_remediation_pipeline()
returns table (remediation_status text, items_count int, total_cost numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not authorized'; end if;
  return query
    select a.remediation_status,
      count(*)::int,
      round(sum(a.estimated_repair_cost_rupees)::numeric, 2)
    from ot_table_hydraulic_audits_r2999 a
    group by a.remediation_status
    order by sum(a.estimated_repair_cost_rupees) desc;
end; $$;
revoke all on function rpc_r2999_remediation_pipeline() from public, anon;
grant execute on function rpc_r2999_remediation_pipeline() to authenticated;

-- RPC 7: downtime risk register
create or replace function rpc_r2999_downtime_risk_register()
returns table (chain_name text, hospital_site text, ot_room_code text, table_asset_tag text, ot_downtime_risk text, overall_audit_grade text, next_audit_due date, estimated_repair_cost_rupees numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not authorized'; end if;
  return query
    select a.chain_name, a.hospital_site, a.ot_room_code, a.table_asset_tag, a.ot_downtime_risk, a.overall_audit_grade, a.next_audit_due, a.estimated_repair_cost_rupees
    from ot_table_hydraulic_audits_r2999 a
    where a.ot_downtime_risk in ('medium','high','critical')
    order by case a.ot_downtime_risk when 'critical' then 1 when 'high' then 2 when 'medium' then 3 else 4 end, a.next_audit_due asc;
end; $$;
revoke all on function rpc_r2999_downtime_risk_register() from public, anon;
grant execute on function rpc_r2999_downtime_risk_register() to authenticated;

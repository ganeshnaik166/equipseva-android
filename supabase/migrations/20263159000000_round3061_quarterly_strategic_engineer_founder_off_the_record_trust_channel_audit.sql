-- Round 3061: Founder Quarterly Strategic Engineer-Founder Off-The-Record Trust Channel Audit
-- Heavy ★★★★ — 2 tables, 7 RPCs, founder-gated

create table if not exists trust_channel_sessions_r3061 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  quarter text not null check (quarter in ('q1_2026','q2_2026','q3_2026','q4_2026')),
  session_code text not null unique,
  engineer_alias text not null,
  engineer_tier text not null check (engineer_tier in ('bronze','silver','gold','platinum','diamond')),
  region text not null check (region in ('hyderabad','bangalore','chennai','mumbai','delhi','kolkata','pune')),
  channel text not null check (channel in ('signal','protonmail','in_person','phone_anon','letter')),
  duration_minutes int check (duration_minutes between 0 and 240),
  candor_score numeric(4,2) check (candor_score between 0 and 10),
  trust_index numeric(4,2) check (trust_index between 0 and 10),
  themes_count int check (themes_count between 0 and 20),
  redaction_level text not null check (redaction_level in ('none','light','medium','heavy','full')),
  founder_action_required boolean not null default false,
  follow_up_due date,
  session_status text not null check (session_status in ('scheduled','completed','no_show','rescheduled','cancelled')),
  notes text
);

create table if not exists trust_channel_themes_r3061 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  theme_code text not null unique,
  theme_title text not null,
  theme_category text not null check (theme_category in ('pay','tooling','customer','hospital','founder','peer','growth','wellbeing','process','strategic')),
  mention_count int not null check (mention_count between 0 and 500),
  sentiment text not null check (sentiment in ('strongly_negative','negative','neutral','positive','strongly_positive')),
  urgency text not null check (urgency in ('p0','p1','p2','p3','p4')),
  first_surfaced_at date not null,
  resolution_status text not null check (resolution_status in ('open','triaged','in_progress','resolved','wont_fix','watching')),
  owner_initial text,
  impact_engineers int not null check (impact_engineers between 0 and 2000),
  founder_aware boolean not null default true,
  blast_radius text not null check (blast_radius in ('individual','team','region','national','global')),
  notes text
);

alter table trust_channel_sessions_r3061 enable row level security;
alter table trust_channel_themes_r3061 enable row level security;

drop policy if exists tc_sessions_r3061_founder_select on trust_channel_sessions_r3061;
create policy tc_sessions_r3061_founder_select on trust_channel_sessions_r3061 for select using (is_founder());

drop policy if exists tc_themes_r3061_founder_select on trust_channel_themes_r3061;
create policy tc_themes_r3061_founder_select on trust_channel_themes_r3061 for select using (is_founder());

revoke all on trust_channel_sessions_r3061 from public, anon;
revoke all on trust_channel_themes_r3061 from public, anon;
grant select on trust_channel_sessions_r3061 to authenticated;
grant select on trust_channel_themes_r3061 to authenticated;

insert into trust_channel_sessions_r3061 (quarter, session_code, engineer_alias, engineer_tier, region, channel, duration_minutes, candor_score, trust_index, themes_count, redaction_level, founder_action_required, follow_up_due, session_status, notes) values
('q2_2026','TCS-3061-001','falcon-azure','gold','hyderabad','signal',62,8.4,8.9,5,'medium',true,'2026-07-15'::date,'completed','strong candor on parts logistics'),
('q2_2026','TCS-3061-002','heron-onyx','platinum','bangalore','in_person',95,9.2,9.5,7,'light',true,'2026-07-10'::date,'completed','wants tier ceiling raised'),
('q2_2026','TCS-3061-003','lynx-coral','silver','chennai','protonmail',45,7.1,7.6,4,'medium',false,'2026-07-20'::date,'completed','tooling pain on infusion pumps'),
('q2_2026','TCS-3061-004','orca-jade','gold','mumbai','phone_anon',38,6.8,7.0,3,'heavy',true,'2026-07-08'::date,'completed','hospital admin abuse incident'),
('q2_2026','TCS-3061-005','quail-amber','bronze','delhi','signal',28,7.9,7.4,4,'medium',false,'2026-07-25'::date,'completed','first quarter participant'),
('q2_2026','TCS-3061-006','raven-ivory','diamond','kolkata','in_person',120,9.6,9.8,9,'none',true,'2026-07-05'::date,'completed','founders-circle member'),
('q2_2026','TCS-3061-007','swan-rust','platinum','pune','letter',0,8.7,8.5,6,'light',true,'2026-07-12'::date,'completed','handwritten letter received'),
('q2_2026','TCS-3061-008','tiger-mint','gold','hyderabad','signal',55,7.4,7.8,5,'medium',false,'2026-07-18'::date,'completed','AMC pool fairness concerns'),
('q2_2026','TCS-3061-009','viper-slate','silver','bangalore','protonmail',40,6.2,6.5,3,'heavy',true,'2026-07-09'::date,'completed','engineer-on-engineer issue'),
('q2_2026','TCS-3061-010','wolf-cream','gold','chennai','signal',50,8.0,8.2,5,'medium',false,'2026-07-22'::date,'completed','customer rating dispute'),
('q2_2026','TCS-3061-011','yak-pearl','bronze','mumbai','phone_anon',25,7.0,7.1,2,'medium',false,null,'no_show','rescheduling'),
('q2_2026','TCS-3061-012','zebra-lavender','platinum','delhi','in_person',88,9.0,9.3,8,'light',true,'2026-07-06'::date,'completed','wants equity discussion'),
('q2_2026','TCS-3061-013','eagle-bronze','gold','kolkata','signal',60,8.3,8.4,5,'medium',false,'2026-07-19'::date,'completed','training quality feedback'),
('q2_2026','TCS-3061-014','fox-sapphire','silver','pune','protonmail',42,7.5,7.7,4,'medium',false,'2026-07-21'::date,'completed','spare parts wait time'),
('q2_2026','TCS-3061-015','goose-ruby','gold','hyderabad','in_person',75,8.8,8.9,6,'light',true,'2026-07-11'::date,'completed','referral bounty unfair'),
('q2_2026','TCS-3061-016','hare-emerald','diamond','bangalore','signal',70,9.4,9.6,7,'none',false,'2026-07-14'::date,'completed','strategic counsel given'),
('q2_2026','TCS-3061-017','ibis-topaz','platinum','chennai','phone_anon',55,8.1,8.0,5,'medium',true,'2026-07-13'::date,'completed','hospital chain pressure'),
('q2_2026','TCS-3061-018','jaguar-quartz','gold','mumbai','signal',65,8.5,8.6,6,'light',false,'2026-07-16'::date,'completed','founder transparency praised'),
('q2_2026','TCS-3061-019','kingfisher-onyx','bronze','delhi','letter',0,7.2,7.0,3,'medium',false,null,'completed','letter — kept anonymous'),
('q2_2026','TCS-3061-020','llama-violet','silver','kolkata','signal',35,6.5,6.8,3,'heavy',true,'2026-07-07'::date,'completed','safety incident report'),
('q1_2026','TCS-3061-021','meerkat-citrine','gold','pune','protonmail',48,7.8,8.0,5,'medium',false,'2026-04-25'::date,'completed','prior quarter — closed'),
('q1_2026','TCS-3061-022','newt-garnet','platinum','hyderabad','in_person',100,9.1,9.4,8,'light',true,'2026-04-15'::date,'completed','prior quarter — actioned'),
('q2_2026','TCS-3061-023','otter-aqua','silver','bangalore','signal',32,7.3,7.5,4,'medium',false,'2026-07-23'::date,'scheduled','upcoming'),
('q2_2026','TCS-3061-024','panther-rose','gold','chennai','protonmail',null,null,null,0,'none',false,null,'cancelled','engineer pulled out');

insert into trust_channel_themes_r3061 (theme_code, theme_title, theme_category, mention_count, sentiment, urgency, first_surfaced_at, resolution_status, owner_initial, impact_engineers, founder_aware, blast_radius, notes) values
('TCT-3061-001','AMC pool payout fairness','pay',47,'negative','p1','2026-04-10'::date,'in_progress','G',850,true,'national','algorithm to be revised q3'),
('TCT-3061-002','Spare parts ETA opacity','tooling',38,'negative','p2','2026-04-12'::date,'triaged','R',620,true,'national','dashboard in build'),
('TCT-3061-003','Hospital admin abusive tone','hospital',22,'strongly_negative','p1','2026-05-02'::date,'in_progress','G',180,true,'region','3 hospitals flagged'),
('TCT-3061-004','Engineer tier ceiling stagnant','pay',31,'negative','p2','2026-04-20'::date,'open','G',420,true,'national','platinum->diamond ladder proposal'),
('TCT-3061-005','Founder accessibility praised','founder',56,'strongly_positive','p4','2026-04-05'::date,'watching','G',1100,true,'national','keep weekly AMA'),
('TCT-3061-006','Customer rating gaming','customer',19,'negative','p2','2026-05-15'::date,'triaged','R',310,true,'region','fraud heuristics needed'),
('TCT-3061-007','Peer mentorship gaps','peer',14,'neutral','p3','2026-05-20'::date,'open','G',240,true,'team','buddy program piloting'),
('TCT-3061-008','On-call burnout signs','wellbeing',26,'negative','p1','2026-05-08'::date,'in_progress','G',380,true,'national','rotation policy q3'),
('TCT-3061-009','Referral bounty payouts late','growth',18,'negative','p2','2026-05-25'::date,'resolved','R',290,true,'national','cron fix shipped r3055'),
('TCT-3061-010','Equity / ESOP conversation','strategic',12,'positive','p2','2026-06-01'::date,'open','G',60,true,'team','platinum+ pool proposal'),
('TCT-3061-011','Training video quality','process',24,'negative','p3','2026-05-12'::date,'triaged','R',520,true,'national','re-shoot batch in q3'),
('TCT-3061-012','Founder transparency monthly','founder',41,'strongly_positive','p4','2026-04-08'::date,'watching','G',980,true,'national','keep dashboard public'),
('TCT-3061-013','Safety incident report flow','wellbeing',8,'negative','p0','2026-06-10'::date,'in_progress','G',45,true,'national','escalation path being formalised'),
('TCT-3061-014','Engineer-on-engineer conflict','peer',6,'negative','p1','2026-05-30'::date,'in_progress','G',12,true,'team','mediation protocol drafted'),
('TCT-3061-015','Hospital chain pricing pressure','hospital',15,'negative','p2','2026-05-18'::date,'open','G',95,true,'region','3 chains flagged'),
('TCT-3061-016','Tooling app crash on android 14','tooling',29,'negative','p1','2026-04-28'::date,'resolved','R',780,true,'national','fixed in v0.4.2'),
('TCT-3061-017','Customer no-show compensation','customer',17,'negative','p2','2026-05-22'::date,'triaged','R',340,true,'national','25% fee proposal'),
('TCT-3061-018','Founder-engineer roadshow ask','founder',9,'positive','p3','2026-06-05'::date,'open','G',150,true,'national','7 city tour proposed'),
('TCT-3061-019','Bronze tier ramp too steep','process',11,'negative','p3','2026-05-10'::date,'open','G',180,true,'national','adjust rubric'),
('TCT-3061-020','Diamond tier perks lacking','pay',5,'negative','p3','2026-06-08'::date,'open','G',22,true,'team','curated perks list q3');
-- 7 RPCs --

create or replace function rpc_r3061_session_overview()
returns table(total_sessions int, completed_sessions int, avg_candor numeric, avg_trust numeric, action_required int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select
    count(*)::int,
    (count(*) filter (where session_status = 'completed'))::int,
    round(avg(candor_score), 2),
    round(avg(trust_index), 2),
    (count(*) filter (where founder_action_required))::int
  from trust_channel_sessions_r3061;
end; $$;

create or replace function rpc_r3061_sessions_by_region()
returns table(region text, sessions int, avg_candor numeric, avg_trust numeric, action_pct numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select s.region, count(*)::int, round(avg(s.candor_score),2), round(avg(s.trust_index),2),
    round(100.0 * (count(*) filter (where s.founder_action_required))::numeric / nullif(count(*),0), 1)
  from trust_channel_sessions_r3061 s
  group by s.region
  order by count(*) desc;
end; $$;

create or replace function rpc_r3061_sessions_by_tier()
returns table(engineer_tier text, sessions int, avg_candor numeric, avg_themes numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select s.engineer_tier, count(*)::int, round(avg(s.candor_score),2), round(avg(s.themes_count),1)
  from trust_channel_sessions_r3061 s
  group by s.engineer_tier
  order by avg(s.candor_score) desc nulls last;
end; $$;

create or replace function rpc_r3061_channel_mix()
returns table(channel text, sessions int, avg_duration numeric, avg_trust numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select s.channel, count(*)::int, round(avg(s.duration_minutes),1), round(avg(s.trust_index),2)
  from trust_channel_sessions_r3061 s
  group by s.channel
  order by count(*) desc;
end; $$;

create or replace function rpc_r3061_top_themes()
returns table(theme_code text, theme_title text, category text, mentions int, urgency text, status text, blast text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select t.theme_code, t.theme_title, t.theme_category, t.mention_count, t.urgency, t.resolution_status, t.blast_radius
  from trust_channel_themes_r3061 t
  order by t.mention_count desc
  limit 12;
end; $$;

create or replace function rpc_r3061_themes_by_category()
returns table(category text, themes int, total_mentions int, open_themes int, avg_impact numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select t.theme_category, count(*)::int, sum(t.mention_count)::int,
    (count(*) filter (where t.resolution_status in ('open','triaged','in_progress')))::int,
    round(avg(t.impact_engineers),0)
  from trust_channel_themes_r3061 t
  group by t.theme_category
  order by sum(t.mention_count) desc;
end; $$;

create or replace function rpc_r3061_urgent_themes()
returns table(theme_code text, theme_title text, urgency text, status text, impact int, surfaced date, blast text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'forbidden'; end if;
  return query
  select t.theme_code, t.theme_title, t.urgency, t.resolution_status, t.impact_engineers, t.first_surfaced_at, t.blast_radius
  from trust_channel_themes_r3061 t
  where t.urgency in ('p0','p1') and t.resolution_status not in ('resolved','wont_fix')
  order by t.urgency asc, t.impact_engineers desc;
end; $$;

revoke all on function rpc_r3061_session_overview() from public, anon;
revoke all on function rpc_r3061_sessions_by_region() from public, anon;
revoke all on function rpc_r3061_sessions_by_tier() from public, anon;
revoke all on function rpc_r3061_channel_mix() from public, anon;
revoke all on function rpc_r3061_top_themes() from public, anon;
revoke all on function rpc_r3061_themes_by_category() from public, anon;
revoke all on function rpc_r3061_urgent_themes() from public, anon;

grant execute on function rpc_r3061_session_overview() to authenticated;
grant execute on function rpc_r3061_sessions_by_region() to authenticated;
grant execute on function rpc_r3061_sessions_by_tier() to authenticated;
grant execute on function rpc_r3061_channel_mix() to authenticated;
grant execute on function rpc_r3061_top_themes() to authenticated;
grant execute on function rpc_r3061_themes_by_category() to authenticated;
grant execute on function rpc_r3061_urgent_themes() to authenticated;

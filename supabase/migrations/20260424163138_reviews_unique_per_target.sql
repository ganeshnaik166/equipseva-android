-- Defence-in-depth: enforce one review per (reviewer, target) at the DB layer.
-- Android already client-dedups via OrderReviewRepository.fetchMineForOrder(),
-- but a concurrent double-tap or malicious client could still double-write.
-- Partial index so historical repair-only rows lacking the multi-target columns
-- are not affected.
create unique index if not exists uniq_reviews_per_reviewer_target
    on public.reviews (reviewer_user_id, related_entity_type, related_entity_id)
    where related_entity_id is not null;

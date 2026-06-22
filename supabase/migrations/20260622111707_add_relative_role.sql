-- Add the "relative" family role: can view the whole family and edit only their
-- own linked profile. Added in its own migration so the value is committed
-- before later migrations reference it.
alter type family_role add value if not exists 'relative';

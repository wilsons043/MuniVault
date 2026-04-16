-- =============================================
-- CivicPipeline Super Admin Dashboard Migration
-- Run this in Supabase SQL Editor
-- =============================================

-- 1. Add zip_code, state, and free_access columns to cities table
ALTER TABLE cities ADD COLUMN IF NOT EXISTS zip_code TEXT;
ALTER TABLE cities ADD COLUMN IF NOT EXISTS state TEXT;
ALTER TABLE cities ADD COLUMN IF NOT EXISTS free_access BOOLEAN DEFAULT false;
ALTER TABLE cities ADD COLUMN IF NOT EXISTS free_access_expires_at TIMESTAMPTZ;
ALTER TABLE cities ADD COLUMN IF NOT EXISTS free_access_note TEXT;

-- 2. Admin Invites table — tracks magic link invitations
CREATE TABLE IF NOT EXISTS admin_invites (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  city_name TEXT NOT NULL,
  slug TEXT NOT NULL,
  zip_code TEXT,
  state TEXT,
  email TEXT NOT NULL,
  access_type TEXT NOT NULL DEFAULT 'free_unlimited',
  expires_at TIMESTAMPTZ,
  tier TEXT CHECK (tier IN ('basic', 'starter', 'enterprise')) DEFAULT 'starter',
  note TEXT,
  magic_token TEXT UNIQUE NOT NULL,
  status TEXT CHECK (status IN ('pending', 'accepted', 'expired', 'revoked')) DEFAULT 'pending',
  accepted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE admin_invites ENABLE ROW LEVEL SECURITY;

-- Super admin can read/write all invites (using service role key in admin dashboard)
CREATE POLICY "Authenticated users can read invites" ON admin_invites FOR SELECT USING (true);
CREATE POLICY "Authenticated users can insert invites" ON admin_invites FOR INSERT WITH CHECK (true);
CREATE POLICY "Authenticated users can update invites" ON admin_invites FOR UPDATE USING (true);

-- 3. Admin Activity Log — tracks all admin actions
CREATE TABLE IF NOT EXISTS admin_activity_log (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  type TEXT NOT NULL DEFAULT 'system',
  description TEXT NOT NULL,
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE admin_activity_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read activity" ON admin_activity_log FOR SELECT USING (true);
CREATE POLICY "Authenticated users can insert activity" ON admin_activity_log FOR INSERT WITH CHECK (true);

-- 4. Usage Analytics table — tracks feature usage per city per day
CREATE TABLE IF NOT EXISTS usage_analytics (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  city_id UUID REFERENCES cities(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id),
  feature TEXT NOT NULL,
  action TEXT NOT NULL DEFAULT 'use',
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE usage_analytics ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read analytics" ON usage_analytics FOR SELECT USING (true);
CREATE POLICY "Authenticated users can insert analytics" ON usage_analytics FOR INSERT WITH CHECK (true);

-- 5. Index for performance
CREATE INDEX IF NOT EXISTS idx_usage_analytics_city ON usage_analytics(city_id);
CREATE INDEX IF NOT EXISTS idx_usage_analytics_created ON usage_analytics(created_at);
CREATE INDEX IF NOT EXISTS idx_usage_analytics_feature ON usage_analytics(feature);
CREATE INDEX IF NOT EXISTS idx_admin_invites_token ON admin_invites(magic_token);
CREATE INDEX IF NOT EXISTS idx_admin_invites_status ON admin_invites(status);
CREATE INDEX IF NOT EXISTS idx_cities_slug ON cities(slug);
CREATE INDEX IF NOT EXISTS idx_cities_zip ON cities(zip_code);
CREATE INDEX IF NOT EXISTS idx_cities_state ON cities(state);

-- 6. Update existing Waynesville record if it exists (set zip + state)
UPDATE cities SET zip_code = '65583', state = 'MO' WHERE slug = 'waynesville' AND zip_code IS NULL;

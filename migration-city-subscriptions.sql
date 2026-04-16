-- CivicPipeline Migration: Add subscription fields + public slug access
-- Run this in Supabase SQL Editor if your cities table already exists

-- Add subscription columns to cities table
ALTER TABLE cities ADD COLUMN IF NOT EXISTS tier TEXT CHECK (tier IN ('basic', 'starter', 'enterprise')) DEFAULT 'starter';
ALTER TABLE cities ADD COLUMN IF NOT EXISTS subscription_status TEXT CHECK (subscription_status IN ('trial', 'active', 'past_due', 'expired', 'deactivated')) DEFAULT 'trial';
ALTER TABLE cities ADD COLUMN IF NOT EXISTS trial_start TIMESTAMPTZ DEFAULT now();
ALTER TABLE cities ADD COLUMN IF NOT EXISTS subscribed_at TIMESTAMPTZ;
ALTER TABLE cities ADD COLUMN IF NOT EXISTS stripe_customer_id TEXT;
ALTER TABLE cities ADD COLUMN IF NOT EXISTS payment_failed_at TIMESTAMPTZ;
ALTER TABLE cities ADD COLUMN IF NOT EXISTS extra_seats INTEGER DEFAULT 0;

-- Allow public read access to cities by slug (needed for login page before auth)
-- Drop the old restrictive SELECT policy first if it exists
DROP POLICY IF EXISTS "Users can read their own city" ON cities;

-- New policy: anyone can read basic city info (slug, name, logo) for login pages
CREATE POLICY "Anyone can read city by slug" ON cities FOR SELECT USING (true);

-- Keep admin-only insert/update policies
-- (These should already exist from the original schema)

-- CivicPipeline Database Schema
-- Run this in Supabase SQL Editor to set up tables

-- Cities table
CREATE TABLE IF NOT EXISTS cities (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  slug TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  logo_url TEXT,
  invite_code TEXT UNIQUE NOT NULL,
  tier TEXT CHECK (tier IN ('basic', 'starter', 'enterprise')) DEFAULT 'starter',
  subscription_status TEXT CHECK (subscription_status IN ('trial', 'active', 'past_due', 'expired', 'deactivated')) DEFAULT 'trial',
  trial_start TIMESTAMPTZ DEFAULT now(),
  subscribed_at TIMESTAMPTZ,
  stripe_customer_id TEXT,
  payment_failed_at TIMESTAMPTZ,
  extra_seats INTEGER DEFAULT 0,
  created_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Public lookup by slug (unauthenticated users need this to see login screen)
CREATE POLICY "Anyone can read city by slug" ON cities FOR SELECT USING (true);

-- Departments table
CREATE TABLE IF NOT EXISTS departments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  city_id UUID REFERENCES cities(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  icon TEXT DEFAULT '📁',
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Crew members table
CREATE TABLE IF NOT EXISTS crew_members (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  city_id UUID REFERENCES cities(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id),
  email TEXT NOT NULL,
  name TEXT NOT NULL,
  role TEXT CHECK (role IN ('admin', 'crew')) DEFAULT 'crew',
  status TEXT CHECK (status IN ('active', 'invited', 'deactivated')) DEFAULT 'invited',
  invited_by UUID REFERENCES auth.users(id),
  invited_at TIMESTAMPTZ DEFAULT now(),
  activated_at TIMESTAMPTZ
);

-- Entries table
CREATE TABLE IF NOT EXISTS entries (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  city_id UUID REFERENCES cities(id) ON DELETE CASCADE NOT NULL,
  department_id UUID REFERENCES departments(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  description TEXT,
  transcript TEXT,
  audio_url TEXT,
  location_lat DOUBLE PRECISION,
  location_lng DOUBLE PRECISION,
  created_by UUID REFERENCES auth.users(id),
  created_by_name TEXT,
  created_by_email TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Entry photos table (one entry can have many photos)
CREATE TABLE IF NOT EXISTS entry_photos (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  entry_id UUID REFERENCES entries(id) ON DELETE CASCADE NOT NULL,
  photo_url TEXT NOT NULL,
  caption TEXT,
  sort_order INTEGER DEFAULT 0,
  captured_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS on all tables
ALTER TABLE cities ENABLE ROW LEVEL SECURITY;
ALTER TABLE departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE crew_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE entry_photos ENABLE ROW LEVEL SECURITY;

-- RLS Policies: Cities
CREATE POLICY "Users can read their own city" ON cities FOR SELECT USING (
  created_by = auth.uid() OR
  id IN (SELECT city_id FROM crew_members WHERE user_id = auth.uid() AND status = 'active')
);
CREATE POLICY "Admins can insert cities" ON cities FOR INSERT WITH CHECK (created_by = auth.uid());
CREATE POLICY "Admins can update their city" ON cities FOR UPDATE USING (created_by = auth.uid());

-- RLS Policies: Departments
CREATE POLICY "Crew can read departments" ON departments FOR SELECT USING (
  city_id IN (SELECT city_id FROM crew_members WHERE user_id = auth.uid() AND status = 'active')
);
CREATE POLICY "Admins can manage departments" ON departments FOR ALL USING (
  city_id IN (SELECT city_id FROM crew_members WHERE user_id = auth.uid() AND role = 'admin' AND status = 'active')
);

-- RLS Policies: Crew Members
CREATE POLICY "Crew can read crew list" ON crew_members FOR SELECT USING (
  city_id IN (SELECT city_id FROM crew_members WHERE user_id = auth.uid() AND status = 'active')
);
CREATE POLICY "Admins can manage crew" ON crew_members FOR ALL USING (
  city_id IN (SELECT city_id FROM crew_members WHERE user_id = auth.uid() AND role = 'admin' AND status = 'active')
);

-- RLS Policies: Entries
CREATE POLICY "Active crew can read entries" ON entries FOR SELECT USING (
  city_id IN (SELECT city_id FROM crew_members WHERE user_id = auth.uid() AND status = 'active')
);
CREATE POLICY "Active crew can insert entries" ON entries FOR INSERT WITH CHECK (
  city_id IN (SELECT city_id FROM crew_members WHERE user_id = auth.uid() AND status = 'active')
);
CREATE POLICY "Users can update own entries" ON entries FOR UPDATE USING (created_by = auth.uid());
CREATE POLICY "Admins can delete entries" ON entries FOR DELETE USING (
  city_id IN (SELECT city_id FROM crew_members WHERE user_id = auth.uid() AND role = 'admin' AND status = 'active')
  OR created_by = auth.uid()
);

-- RLS Policies: Entry Photos
CREATE POLICY "Active crew can read photos" ON entry_photos FOR SELECT USING (
  entry_id IN (SELECT id FROM entries WHERE city_id IN (
    SELECT city_id FROM crew_members WHERE user_id = auth.uid() AND status = 'active'
  ))
);
CREATE POLICY "Active crew can insert photos" ON entry_photos FOR INSERT WITH CHECK (
  entry_id IN (SELECT id FROM entries WHERE city_id IN (
    SELECT city_id FROM crew_members WHERE user_id = auth.uid() AND status = 'active'
  ))
);
CREATE POLICY "Users can delete own photos" ON entry_photos FOR DELETE USING (
  entry_id IN (SELECT id FROM entries WHERE created_by = auth.uid())
);

-- Create storage bucket for photos and logos
INSERT INTO storage.buckets (id, name, public) VALUES ('civicpipeline', 'civicpipeline', true)
ON CONFLICT (id) DO NOTHING;

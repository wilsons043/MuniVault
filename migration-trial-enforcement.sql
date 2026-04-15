-- MuniVault Migration: Trial Enforcement
-- Prevents cities from resetting their trial or reverting from expired to trial status.
-- Run this in Supabase SQL Editor.

-- Trigger function: block trial manipulation
CREATE OR REPLACE FUNCTION prevent_trial_reset()
RETURNS TRIGGER AS $$
BEGIN
  -- Cannot change trial_start once it's been set
  IF OLD.trial_start IS NOT NULL AND NEW.trial_start IS DISTINCT FROM OLD.trial_start THEN
    RAISE EXCEPTION 'Trial start date cannot be changed once set';
  END IF;
  -- Cannot revert from expired back to trial
  IF OLD.subscription_status = 'expired' AND NEW.subscription_status = 'trial' THEN
    RAISE EXCEPTION 'Cannot revert to trial after expiration';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Attach trigger to cities table
DROP TRIGGER IF EXISTS lock_trial_start ON cities;
CREATE TRIGGER lock_trial_start
BEFORE UPDATE ON cities
FOR EACH ROW EXECUTE FUNCTION prevent_trial_reset();

-- ============================================================
-- JayPOS Supabase Schema
-- Run this in Supabase SQL Editor (https://supabase.com/dashboard/project/iyrmmabzasmfovohbgti/sql/new)
-- ============================================================

-- 1. Subscription Plans (seeded tiers)
CREATE TABLE IF NOT EXISTS subscription_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  max_devices INT NOT NULL,
  max_bills INT NOT NULL,
  max_whatsapp INT NOT NULL,
  price_paise BIGINT NOT NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO subscription_plans (name, max_devices, max_bills, max_whatsapp, price_paise) VALUES
  ('Starter', 1, 500, 100, 49900),
  ('Growth', 5, 999999, 500, 99900),
  ('Pro', 10, 999999, 999999, 199900)
ON CONFLICT (name) DO NOTHING;

-- 2. Shops (tenants, linked to auth.users)
CREATE TABLE IF NOT EXISTS shops (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  shop_name TEXT NOT NULL,
  owner_name TEXT NOT NULL,
  phone TEXT DEFAULT '',
  address TEXT DEFAULT '',
  gstin TEXT DEFAULT '',
  currency TEXT DEFAULT '₹',
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 3. Subscriptions (per shop)
CREATE TABLE IF NOT EXISTS subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id UUID REFERENCES shops(id) ON DELETE CASCADE NOT NULL,
  plan_id UUID REFERENCES subscription_plans(id) NOT NULL,
  status TEXT NOT NULL DEFAULT 'active',
  start_date TIMESTAMPTZ NOT NULL DEFAULT now(),
  expiry_date TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '30 days'),
  grace_period_end TIMESTAMPTZ DEFAULT (now() + interval '37 days'),
  auto_renew BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 4. Payments
CREATE TABLE IF NOT EXISTS payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id UUID REFERENCES shops(id) ON DELETE CASCADE NOT NULL,
  subscription_id UUID REFERENCES subscriptions(id) ON DELETE SET NULL,
  amount_paise BIGINT NOT NULL,
  currency TEXT DEFAULT 'INR',
  status TEXT DEFAULT 'completed',
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 5. Shop Stats
CREATE TABLE IF NOT EXISTS shop_stats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id UUID REFERENCES shops(id) ON DELETE CASCADE UNIQUE NOT NULL,
  total_bills INT DEFAULT 0,
  total_customers INT DEFAULT 0,
  total_whatsapp_sent INT DEFAULT 0,
  last_synced TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- Auto-create shop + subscription on user signup
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  starter_plan_id UUID;
  new_shop_id UUID;
BEGIN
  -- Get the Starter plan ID
  SELECT id INTO starter_plan_id FROM subscription_plans WHERE name = 'Starter' LIMIT 1;

  -- Create shop
  INSERT INTO shops (owner_id, shop_name, owner_name, phone, address, gstin)
  VALUES (
    NEW.id,
    NEW.raw_user_meta_data->>'shop_name',
    NEW.raw_user_meta_data->>'owner_name',
    COALESCE(NEW.raw_user_meta_data->>'phone', ''),
    COALESCE(NEW.raw_user_meta_data->>'address', ''),
    COALESCE(NEW.raw_user_meta_data->>'gstin', '')
  )
  RETURNING id INTO new_shop_id;

  -- Create 30-day trial subscription
  IF starter_plan_id IS NOT NULL THEN
    INSERT INTO subscriptions (shop_id, plan_id, status, expiry_date, grace_period_end)
    VALUES (new_shop_id, starter_plan_id, 'active', now() + interval '30 days', now() + interval '37 days');
  END IF;

  -- Create shop stats
  INSERT INTO shop_stats (shop_id) VALUES (new_shop_id);

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- Row Level Security
-- ============================================================
ALTER TABLE shops ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscription_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE shop_stats ENABLE ROW LEVEL SECURITY;

-- Shop owners can read their own shop
CREATE POLICY "owners_read_own_shop" ON shops
  FOR SELECT USING (auth.uid() = owner_id);

-- Super admins can read all shops (via a custom claim or user metadata)
CREATE POLICY "super_admins_read_all_shops" ON shops
  FOR SELECT USING (
    COALESCE(auth.jwt() ->> 'role', '') = 'super_admin'
    OR auth.email() = 'admin@jaypos.com'
  );

-- Super admins can insert/update/delete shops
CREATE POLICY "super_admins_manage_shops" ON shops
  FOR ALL USING (
    COALESCE(auth.jwt() ->> 'role', '') = 'super_admin'
    OR auth.email() = 'admin@jaypos.com'
  );

-- Subscriptions: owners read own; super_admin read all
CREATE POLICY "owners_read_own_subscriptions" ON subscriptions
  FOR SELECT USING (
    shop_id IN (SELECT id FROM shops WHERE owner_id = auth.uid())
  );

CREATE POLICY "super_admins_all_subscriptions" ON subscriptions
  FOR ALL USING (
    COALESCE(auth.jwt() ->> 'role', '') = 'super_admin'
    OR auth.email() = 'admin@jaypos.com'
  );

-- Subscription plans: everyone can read active
CREATE POLICY "read_active_plans" ON subscription_plans
  FOR SELECT USING (is_active = true);

-- Payments: owners read own; super_admin read all
CREATE POLICY "owners_read_own_payments" ON payments
  FOR SELECT USING (
    shop_id IN (SELECT id FROM shops WHERE owner_id = auth.uid())
  );

CREATE POLICY "super_admins_all_payments" ON payments
  FOR ALL USING (
    COALESCE(auth.jwt() ->> 'role', '') = 'super_admin'
    OR auth.email() = 'admin@jaypos.com'
  );

-- Shop stats: owners read own; super_admin read all
CREATE POLICY "owners_read_own_stats" ON shop_stats
  FOR SELECT USING (
    shop_id IN (SELECT id FROM shops WHERE owner_id = auth.uid())
  );

CREATE POLICY "super_admins_all_stats" ON shop_stats
  FOR ALL USING (
    COALESCE(auth.jwt() ->> 'role', '') = 'super_admin'
    OR auth.email() = 'admin@jaypos.com'
  );

-- ============================================================
-- Create initial super admin user
-- (run this AFTER creating the user in Supabase Auth UI)
-- ============================================================
-- First, create a user manually in Supabase Auth dashboard:
--   Email: admin@jaypos.com
--   Password: admin@123
-- Then run this to set up the shop:
-- INSERT INTO shops (owner_id, shop_name, owner_name, phone, address)
-- VALUES (
--   (SELECT id FROM auth.users WHERE email = 'admin@jaypos.com'),
--   'Super Admin', 'Super Admin', '', ''
-- );

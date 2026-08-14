-- Fix schema and Insert Dummy Data for Quick Actions and Vouchers System
-- Date: 2026-08-10

BEGIN;

-- 0. Fix vouchers schema (DROP and recreate to ensure all columns like 'title' and 'farmer_id' exist)
DROP TABLE IF EXISTS public.user_vouchers CASCADE;
DROP TABLE IF EXISTS public.vouchers CASCADE;

CREATE TABLE public.vouchers (
  voucher_id uuid NOT NULL DEFAULT gen_random_uuid(),
  farmer_id uuid NOT NULL,
  code text NOT NULL UNIQUE,
  title text NOT NULL,
  description text,
  discount_percentage numeric,
  min_spend numeric,
  valid_until timestamp with time zone,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT vouchers_pkey PRIMARY KEY (voucher_id),
  CONSTRAINT fk_vouchers_farmer FOREIGN KEY (farmer_id) REFERENCES public.farmers(farmer_id) ON DELETE CASCADE
);

CREATE TABLE public.user_vouchers (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  voucher_id uuid NOT NULL,
  status text NOT NULL CHECK (status IN ('available', 'used', 'expired')),
  claimed_at timestamp with time zone DEFAULT now(),
  CONSTRAINT user_vouchers_pkey PRIMARY KEY (id),
  CONSTRAINT fk_user_vouchers_user FOREIGN KEY (user_id) REFERENCES public.users(user_id) ON DELETE CASCADE,
  CONSTRAINT fk_user_vouchers_voucher FOREIGN KEY (voucher_id) REFERENCES public.vouchers(voucher_id) ON DELETE CASCADE,
  CONSTRAINT uq_user_voucher UNIQUE (user_id, voucher_id)
);


-- 1. Randomly assign boolean flags to existing products
UPDATE public.products
SET 
  is_free_shipping = (random() > 0.7),
  is_wholesale = (random() > 0.8),
  is_flash_sale = (random() > 0.85);

-- 2. Insert dummy vouchers for the first farmer
DO $$ 
DECLARE
  v_farmer_id uuid;
BEGIN
  SELECT farmer_id INTO v_farmer_id FROM public.farmers LIMIT 1;
  
  IF v_farmer_id IS NOT NULL THEN
    INSERT INTO public.vouchers (farmer_id, code, title, description, discount_percentage, min_spend, valid_until, is_active)
    VALUES 
    (v_farmer_id, 'WELCOME20', '20% OFF', 'Get 20% off your first purchase', 20.0, 500, now() + interval '30 days', true),
    (v_farmer_id, 'FREESHIP', 'Free Shipping', 'Free delivery on orders above ₱1000', NULL, 1000, now() + interval '15 days', true),
    (v_farmer_id, 'FLASH50', '50% OFF Flash Sale', 'Massive discount for flash sale items', 50.0, 2000, now() + interval '1 days', true),
    (v_farmer_id, 'EXPIRED10', '10% OFF', 'This voucher has expired', 10.0, 300, now() - interval '5 days', false)
    ON CONFLICT (code) DO NOTHING;
  END IF;
END $$;

-- 3. Assign vouchers to users
DO $$ 
DECLARE
  v_user record;
  v_voucher record;
BEGIN
  FOR v_user IN SELECT user_id FROM public.users LIMIT 10 LOOP
    FOR v_voucher IN SELECT voucher_id, code FROM public.vouchers LOOP
      
      IF v_voucher.code = 'EXPIRED10' THEN
        INSERT INTO public.user_vouchers (user_id, voucher_id, status)
        VALUES (v_user.user_id, v_voucher.voucher_id, 'expired')
        ON CONFLICT DO NOTHING;
      ELSIF v_voucher.code = 'FLASH50' THEN
        INSERT INTO public.user_vouchers (user_id, voucher_id, status)
        VALUES (v_user.user_id, v_voucher.voucher_id, 'used')
        ON CONFLICT DO NOTHING;
      ELSE
        INSERT INTO public.user_vouchers (user_id, voucher_id, status)
        VALUES (v_user.user_id, v_voucher.voucher_id, 'available')
        ON CONFLICT DO NOTHING;
      END IF;

    END LOOP;
  END LOOP;
END $$;

COMMIT;

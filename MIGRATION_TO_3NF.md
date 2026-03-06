# Migration Guide: Current Schema → 3NF Normalized Schema

> **Status:** Not yet applied to live database  
> **Target Normalization Level:** Third Normal Form (3NF)  
> **Estimated Downtime:** 30-60 minutes for data migration

---

## Overview

This guide shows how to migrate your existing Supabase tables from a denormalized structure to a **3NF-compliant normalized schema** with zero data loss. Computed columns are replaced with database VIEWs.

---

## Before & After: Table Comparison

### USERS Table

#### Current (Denormalized)
```sql
CREATE TABLE users (
  id uuid PRIMARY KEY,
  email text UNIQUE NOT NULL,
  name text NOT NULL,
  is_seller boolean DEFAULT false,     -- PROBLEMATIC: binary flag (should be role)
  is_admin boolean DEFAULT false,       -- PROBLEMATIC: binary flag
  phone text,
  address text,                         -- PROBLEMATIC: multi-valued (street, city, zip)
  avatar_url text,
  bio text,
  email_verified boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
```

#### After (Normalized 3NF)
```sql
CREATE TABLE users (
  id uuid PRIMARY KEY,
  email text UNIQUE NOT NULL,
  name text NOT NULL,
  phone text,
  avatar_url text,
  bio text,
  email_verified boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
-- is_seller, is_admin REMOVED → USER_ROLES junction table
-- address REMOVED → USER_ADDRESSES table
```

**What Changed:**
- ✂️ Removed `is_seller` and `is_admin` flags
- ✂️ Removed `address` text blob
- ✅ Added USER_ROLES and USER_ADDRESSES tables

---

### PRODUCTS Table

#### Current (Denormalized)
```sql
CREATE TABLE products (
  id uuid PRIMARY KEY,
  name text NOT NULL,
  farm text,                            -- PROBLEMATIC: transitively dependent on farmer
  price decimal NOT NULL,
  image_url text,
  average_rating decimal,               -- PROBLEMATIC: derived from PRODUCT_REVIEWS
  review_count integer,                 -- PROBLEMATIC: derived from PRODUCT_REVIEWS
  harvest_days integer,
  is_preorder boolean DEFAULT false,
  farmer_id uuid REFERENCES users(id),
  category_id uuid REFERENCES categories(id),
  unit_id uuid REFERENCES units(id),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
```

#### After (Normalized 3NF)
```sql
CREATE TABLE products (
  id uuid PRIMARY KEY,
  name text NOT NULL,
  price decimal NOT NULL,
  image_url text,
  harvest_days integer,
  is_preorder boolean DEFAULT false,
  farmer_id uuid REFERENCES users(id),
  category_id uuid REFERENCES categories(id),
  unit_id uuid REFERENCES units(id),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
-- farm REMOVED → computed from FARMER_PROFILES.farm_name
-- average_rating REMOVED → computed via v_products VIEW
-- review_count REMOVED → computed via v_products VIEW
```

**What Changed:**
- ✂️ Removed `farm` (transitively dependent)
- ✂️ Removed `average_rating` and `review_count` (derived)
- ✅ Use `v_products` VIEW for aggregates

---

### FORUM_POSTS Table

#### Current (Denormalized)
```sql
CREATE TABLE forum_posts (
  id uuid PRIMARY KEY,
  user_id uuid REFERENCES users(id),
  title text NOT NULL,
  body text NOT NULL,
  image_url text,
  likes_count integer DEFAULT 0,        -- PROBLEMATIC: derived from POST_LIKES
  comments_count integer DEFAULT 0,     -- PROBLEMATIC: derived from FORUM_COMMENTS
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
```

#### After (Normalized 3NF)
```sql
CREATE TABLE forum_posts (
  id uuid PRIMARY KEY,
  user_id uuid REFERENCES users(id),
  title text NOT NULL,
  body text NOT NULL,
  image_url text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
-- likes_count REMOVED → computed via v_forum_posts VIEW
-- comments_count REMOVED → computed via v_forum_posts VIEW
```

**What Changed:**
- ✂️ Removed `likes_count` and `comments_count` (derived)
- ✅ Use `v_forum_posts` VIEW for counts

---

### ORDERS Table

#### Current (Denormalized)
```sql
CREATE TABLE orders (
  id uuid PRIMARY KEY,
  order_number text UNIQUE NOT NULL,
  customer_id uuid REFERENCES users(id),
  farmer_id uuid REFERENCES users(id),
  total decimal,                        -- PROBLEMATIC: derived from ORDER_ITEMS
  status text DEFAULT 'PENDING',
  item_count integer,                   -- PROBLEMATIC: derived from ORDER_ITEMS
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
```

#### After (Normalized 3NF)
```sql
CREATE TABLE orders (
  id uuid PRIMARY KEY,
  order_number text UNIQUE NOT NULL,
  customer_id uuid REFERENCES users(id),
  farmer_id uuid REFERENCES users(id),
  status order_status NOT NULL,         -- Use ENUM type
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
-- total REMOVED → computed via v_orders VIEW
-- item_count REMOVED → computed via v_orders VIEW
```

**What Changed:**
- ✂️ Removed `total` and `item_count` (derived)
- ✅ Changed `status` to ENUM type
- ✅ Use `v_orders` VIEW for aggregates

---

### ORDER_ITEMS Table

#### Current (Denormalized)
```sql
CREATE TABLE order_items (
  id uuid PRIMARY KEY,
  order_id uuid REFERENCES orders(id),
  product_id uuid REFERENCES products(id),
  quantity decimal NOT NULL,
  unit_price decimal NOT NULL,
  subtotal decimal,                     -- PROBLEMATIC: derived from quantity × unit_price
  created_at timestamptz DEFAULT now()
);
```

#### After (Normalized 3NF)
```sql
CREATE TABLE order_items (
  id uuid PRIMARY KEY,
  order_id uuid REFERENCES orders(id),
  product_id uuid REFERENCES products(id),
  quantity decimal NOT NULL,
  unit_price decimal NOT NULL,
  created_at timestamptz DEFAULT now()
);
-- subtotal REMOVED → computed via v_order_items VIEW as (quantity * unit_price)
```

**What Changed:**
- ✂️ Removed `subtotal` (derived)
- ✅ Use `v_order_items` VIEW for computed subtotal

---

### FARMER_PROFILES Table

#### Current (Denormalized)
```sql
CREATE TABLE farmer_profiles (
  id uuid PRIMARY KEY,
  user_id uuid UNIQUE REFERENCES users(id),
  farm_name text NOT NULL,
  specialty text,
  location text,
  distance text,                        -- PROBLEMATIC: context-dependent
  rating decimal,                       -- PROBLEMATIC: derived from PRODUCT_REVIEWS
  badge text,
  image_url text,
  is_verified boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);
```

#### After (Normalized 3NF)
```sql
CREATE TABLE farmer_profiles (
  id uuid PRIMARY KEY,
  user_id uuid UNIQUE REFERENCES users(id),
  farm_name text NOT NULL,
  specialty text,
  location text,
  badge text,
  image_url text,
  is_verified boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
-- distance REMOVED → computed at query time (relative to user location)
-- rating REMOVED → computed via v_farmer_profiles VIEW
```

**What Changed:**
- ✂️ Removed `distance` (context-dependent)
- ✂️ Removed `rating` (derived)
- ✅ Use `v_farmer_profiles` VIEW for computed rating

---

### FARMER_REGISTRATIONS Table

#### Current (Denormalized)
```sql
CREATE TABLE farmer_registrations (
  id uuid PRIMARY KEY,
  user_id uuid UNIQUE REFERENCES users(id),
  full_name text,                       -- PROBLEMATIC: duplicate of USERS.name
  birth_date text,
  years_in_farming text,                -- PROBLEMATIC: duplicate of years_of_experience
  residential_address text,
  crop_types text,                      -- PROBLEMATIC: multi-valued (should be separate rows)
  livestock text,                       -- PROBLEMATIC: multi-valued
  face_photo_path text,
  valid_id_path text,
  elementary text,                      -- PROBLEMATIC: repeating group (education)
  high_school text,                     -- PROBLEMATIC: repeating group
  college text,                         -- PROBLEMATIC: repeating group
  farming_history text,
  years_of_experience integer,
  certification_accepted boolean,
  status text DEFAULT 'pending',
  created_at timestamptz DEFAULT now()
);
```

#### After (Normalized 3NF)
```sql
CREATE TABLE farmer_registrations (
  id uuid PRIMARY KEY,
  user_id uuid UNIQUE REFERENCES users(id),
  birth_date text,
  years_of_experience integer,
  residential_address text,
  face_photo_path text,
  valid_id_path text,
  farming_history text,
  certification_accepted boolean,
  status text DEFAULT 'pending',
  created_at timestamptz DEFAULT now()
);
-- full_name REMOVED → derive from USERS.name via user_id
-- years_in_farming REMOVED → duplicate of years_of_experience
-- crop_types REMOVED → separate FARMER_CROP_TYPES table (one row per crop)
-- livestock REMOVED → separate FARMER_LIVESTOCK table (one row per livestock)
-- elementary, high_school, college REMOVED → separate FARMER_EDUCATION table
```

**New Tables:**
```sql
CREATE TABLE farmer_education (
  id uuid PRIMARY KEY,
  registration_id uuid REFERENCES farmer_registrations(id) ON DELETE CASCADE,
  level text,                           -- 'elementary', 'high_school', 'college', etc.
  school_name text,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE farmer_crop_types (
  id uuid PRIMARY KEY,
  registration_id uuid REFERENCES farmer_registrations(id) ON DELETE CASCADE,
  crop_type text,                       -- One row per crop (e.g., 'rice', 'corn', etc.)
  created_at timestamptz DEFAULT now()
);

CREATE TABLE farmer_livestock (
  id uuid PRIMARY KEY,
  registration_id uuid REFERENCES farmer_registrations(id) ON DELETE CASCADE,
  livestock_type text,                  -- One row per livestock (e.g., 'chicken', 'pig', etc.)
  created_at timestamptz DEFAULT now()
);
```

**What Changed:**
- ✂️ Removed `full_name` (duplicate)
- ✂️ Removed `years_in_farming` (duplicate)
- ✂️ Removed `crop_types` text blob → FARMER_CROP_TYPES table
- ✂️ Removed `livestock` text blob → FARMER_LIVESTOCK table
- ✂️ Removed education repeating group → FARMER_EDUCATION table
- ✅ Each crop/livestock/education is now a separate atomic row

---

### ARTICLES Table

#### Current (Denormalized)
```sql
CREATE TABLE articles (
  id uuid PRIMARY KEY,
  title text NOT NULL,
  excerpt text,                         -- PROBLEMATIC: derived from content if auto-generated
  content text NOT NULL,
  author_id uuid REFERENCES users(id),
  read_time text,
  image_url text,
  published boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
```

#### After (Normalized 3NF)
```sql
CREATE TABLE articles (
  id uuid PRIMARY KEY,
  title text NOT NULL,
  content text NOT NULL,
  author_id uuid REFERENCES users(id),
  read_time text,
  image_url text,
  published boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
-- excerpt REMOVED → computed via v_articles VIEW as LEFT(content, 200)
```

**What Changed:**
- ✂️ Removed `excerpt` if auto-generated (derived)
- ✅ Use `v_articles` VIEW for computed excerpt

---

### New Tables (Normalization)

#### ROLES Reference Table
```sql
CREATE TABLE roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text UNIQUE NOT NULL,            -- 'consumer', 'seller', 'admin'
  created_at timestamptz DEFAULT now()
);

INSERT INTO roles (name) VALUES ('consumer'), ('seller'), ('admin');
```

#### USER_ROLES Junction Table
```sql
CREATE TABLE user_roles (
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  role_id uuid REFERENCES roles(id) ON DELETE CASCADE,
  PRIMARY KEY (user_id, role_id)
);
-- Replaces USERS.is_seller and USERS.is_admin
```

#### USER_ADDRESSES Table (Atomic Address)
```sql
CREATE TABLE user_addresses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  street text,
  barangay text,
  city text,
  province text,
  zip_code text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
-- Replaces USERS.address text blob
```

---

## Step-by-Step Migration Script

### Phase 1: Create New Tables

```sql
-- 1. Create ENUM types (if not exists)
DO $$ BEGIN
  CREATE TYPE order_status AS ENUM ('PENDING', 'CONFIRMED', 'SHIPPED', 'DELIVERED', 'CANCELLED');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 2. Create ROLES table
CREATE TABLE IF NOT EXISTS roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text UNIQUE NOT NULL,
  created_at timestamptz DEFAULT now()
);

INSERT INTO roles (name) VALUES ('consumer'), ('seller'), ('admin')
ON CONFLICT (name) DO NOTHING;

-- 3. Create USER_ROLES junction table
CREATE TABLE IF NOT EXISTS user_roles (
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  role_id uuid REFERENCES roles(id) ON DELETE CASCADE,
  PRIMARY KEY (user_id, role_id)
);

-- 4. Create USER_ADDRESSES table
CREATE TABLE IF NOT EXISTS user_addresses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  street text,
  barangay text,
  city text,
  province text,
  zip_code text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- 5. Create FARMER_EDUCATION table
CREATE TABLE IF NOT EXISTS farmer_education (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  registration_id uuid REFERENCES farmer_registrations(id) ON DELETE CASCADE,
  level text,
  school_name text,
  created_at timestamptz DEFAULT now()
);

-- 6. Create FARMER_CROP_TYPES table
CREATE TABLE IF NOT EXISTS farmer_crop_types (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  registration_id uuid REFERENCES farmer_registrations(id) ON DELETE CASCADE,
  crop_type text,
  created_at timestamptz DEFAULT now()
);

-- 7. Create FARMER_LIVESTOCK table
CREATE TABLE IF NOT EXISTS farmer_livestock (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  registration_id uuid REFERENCES farmer_registrations(id) ON DELETE CASCADE,
  livestock_type text,
  created_at timestamptz DEFAULT now()
);
```

### Phase 2: Migrate Data

```sql
-- 1. Migrate roles from USERS flags to USER_ROLES
INSERT INTO user_roles (user_id, role_id)
SELECT u.id, r.id FROM users u, roles r WHERE u.is_seller AND r.name = 'seller'
ON CONFLICT (user_id, role_id) DO NOTHING;

INSERT INTO user_roles (user_id, role_id)
SELECT u.id, r.id FROM users u, roles r WHERE u.is_admin AND r.name = 'admin'
ON CONFLICT (user_id, role_id) DO NOTHING;

-- All users get 'consumer' role
INSERT INTO user_roles (user_id, role_id)
SELECT u.id, r.id FROM users u, roles r WHERE r.name = 'consumer'
ON CONFLICT (user_id, role_id) DO NOTHING;

-- 2. Migrate addresses from USERS.address to USER_ADDRESSES
-- NOTE: This is a simple migration; adjust parsing as needed based on your format
INSERT INTO user_addresses (user_id, barangay, city)
SELECT id, user_metadata->>'barangay', user_metadata->>'city'
FROM users
WHERE address IS NOT NULL OR (user_metadata->>'address_parts') IS NOT NULL;

-- 3. Migrate farmer education from FARMER_REGISTRATIONS to FARMER_EDUCATION
INSERT INTO farmer_education (registration_id, level, school_name)
SELECT id, 'elementary', elementary FROM farmer_registrations WHERE elementary IS NOT NULL;

INSERT INTO farmer_education (registration_id, level, school_name)
SELECT id, 'high_school', high_school FROM farmer_registrations WHERE high_school IS NOT NULL;

INSERT INTO farmer_education (registration_id, level, school_name)
SELECT id, 'college', college FROM farmer_registrations WHERE college IS NOT NULL;

-- 4. Migrate crop types from FARMER_REGISTRATIONS to FARMER_CROP_TYPES
-- Example: if crop_types is comma-separated like 'rice,corn,mango'
INSERT INTO farmer_crop_types (registration_id, crop_type)
SELECT 
  fr.id, 
  TRIM(crop) 
FROM farmer_registrations fr
CROSS JOIN LATERAL unnest(string_to_array(fr.crop_types, ',')) AS crop
WHERE fr.crop_types IS NOT NULL;

-- 5. Migrate livestock from FARMER_REGISTRATIONS to FARMER_LIVESTOCK
INSERT INTO farmer_livestock (registration_id, livestock_type)
SELECT 
  fr.id, 
  TRIM(animal) 
FROM farmer_registrations fr
CROSS JOIN LATERAL unnest(string_to_array(fr.livestock, ',')) AS animal
WHERE fr.livestock IS NOT NULL;
```

### Phase 3: Create VIEWs for Computed Data

```sql
-- 1. Create v_products VIEW
CREATE OR REPLACE VIEW v_products AS
SELECT
  p.*,
  c.name AS category_name,
  u.name AS unit_name,
  u.abbreviation AS unit_abbr,
  fp.farm_name,
  COALESCE(AVG(pr.rating), 0) AS average_rating,
  COUNT(pr.id) AS review_count
FROM products p
LEFT JOIN categories c ON c.id = p.category_id
LEFT JOIN units u ON u.id = p.unit_id
LEFT JOIN farmer_profiles fp ON fp.user_id = p.farmer_id
LEFT JOIN product_reviews pr ON pr.product_id = p.id
GROUP BY p.id, c.name, u.name, u.abbreviation, fp.farm_name;

-- 2. Create v_forum_posts VIEW
CREATE OR REPLACE VIEW v_forum_posts AS
SELECT
  fp.*,
  usr.name AS author_name,
  COALESCE(lk.likes_count, 0) AS likes_count,
  COALESCE(cm.comments_count, 0) AS comments_count
FROM forum_posts fp
JOIN users usr ON usr.id = fp.user_id
LEFT JOIN (
  SELECT post_id, COUNT(*) AS likes_count FROM post_likes GROUP BY post_id
) lk ON lk.post_id = fp.id
LEFT JOIN (
  SELECT post_id, COUNT(*) AS comments_count FROM forum_comments GROUP BY post_id
) cm ON cm.post_id = fp.id;

-- 3. Create v_orders VIEW
CREATE OR REPLACE VIEW v_orders AS
SELECT
  o.*,
  COALESCE(SUM(oi.quantity * oi.unit_price), 0) AS total,
  COUNT(oi.id) AS item_count
FROM orders o
LEFT JOIN order_items oi ON oi.order_id = o.id
GROUP BY o.id;

-- 4. Create v_order_items VIEW
CREATE OR REPLACE VIEW v_order_items AS
SELECT
  oi.*,
  (oi.quantity * oi.unit_price) AS subtotal
FROM order_items oi;

-- 5. Create v_farmer_profiles VIEW
CREATE OR REPLACE VIEW v_farmer_profiles AS
SELECT
  fp.*,
  usr.name AS farmer_name,
  COALESCE(AVG(pr.rating), 0) AS average_rating,
  COUNT(DISTINCT pr.id) AS total_reviews
FROM farmer_profiles fp
JOIN users usr ON usr.id = fp.user_id
LEFT JOIN products p ON p.farmer_id = fp.user_id
LEFT JOIN product_reviews pr ON pr.product_id = p.id
GROUP BY fp.id, usr.name;

-- 6. Create v_articles VIEW
CREATE OR REPLACE VIEW v_articles AS
SELECT
  a.*,
  usr.name AS author_name,
  LEFT(a.content, 200) AS excerpt
FROM articles a
LEFT JOIN users usr ON usr.id = a.author_id;
```

### Phase 4: Remove Old Columns (Optional – Enable Column Removal Policy)

```sql
-- CAUTION: Only execute this after verifying views work and app is updated

-- Step 1: Update app code to use VIEWs instead of base table columns
-- Step 2: Test all queries with VIEWs for 1-2 weeks
-- Step 3: Then remove old columns:

ALTER TABLE users DROP COLUMN is_seller;
ALTER TABLE users DROP COLUMN is_admin;
ALTER TABLE users DROP COLUMN address;

ALTER TABLE products DROP COLUMN farm;
ALTER TABLE products DROP COLUMN average_rating;
ALTER TABLE products DROP COLUMN review_count;

ALTER TABLE forum_posts DROP COLUMN likes_count;
ALTER TABLE forum_posts DROP COLUMN comments_count;

ALTER TABLE orders DROP COLUMN total;
ALTER TABLE orders DROP COLUMN item_count;

ALTER TABLE order_items DROP COLUMN subtotal;

ALTER TABLE farmer_profiles DROP COLUMN distance;
ALTER TABLE farmer_profiles DROP COLUMN rating;

ALTER TABLE farmer_registrations DROP COLUMN full_name;
ALTER TABLE farmer_registrations DROP COLUMN years_in_farming;
ALTER TABLE farmer_registrations DROP COLUMN crop_types;
ALTER TABLE farmer_registrations DROP COLUMN livestock;
ALTER TABLE farmer_registrations DROP COLUMN elementary;
ALTER TABLE farmer_registrations DROP COLUMN high_school;
ALTER TABLE farmer_registrations DROP COLUMN college;

ALTER TABLE articles DROP COLUMN excerpt;
```

---

## Migration Checklist

- [ ] **Pre-migration**
  - [ ] Backup current Supabase database
  - [ ] Review normalization changes above
  - [ ] Identify custom queries that use old columns
  - [ ] Notify users of maintenance window (30-60 min)

- [ ] **Phase 1: Create New Tables**
  - [ ] Run new table creation script
  - [ ] Verify tables exist: `\dt` in psql

- [ ] **Phase 2: Migrate Data**
  - [ ] Run data migration script
  - [ ] Verify data counts:
    - [ ] `SELECT COUNT(*) FROM user_roles` (should have entries)
    - [ ] `SELECT COUNT(*) FROM farmer_crop_types` (should have entries if crops exist)
    - [ ] `SELECT COUNT(*) FROM user_addresses` (should have entries if addresses populated)

- [ ] **Phase 3: Create VIEWs**
  - [ ] Run view creation script
  - [ ] Test views return correct data:
    - [ ] `SELECT * FROM v_products LIMIT 1`
    - [ ] `SELECT * FROM v_orders LIMIT 1`
    - [ ] Verify aggregates (avg ratings, counts, totals)

- [ ] **Phase 4: Update App Code**
  - [ ] Update queries to use VIEWs where needed
  - [ ] Update INSERT/UPDATE logic for new tables
  - [ ] Test all screens in dev & staging
  - [ ] Run integration tests

- [ ] **Phase 5: Remove Old Columns**
  - [ ] Deploy app to production first
  - [ ] Monitor for 1-2 weeks
  - [ ] Then run column removal script
  - [ ] Update database documentation

---

## Rollback Plan

If issues occur:

```sql
-- Restore dropped columns (if still within Supabase recovery window)
-- Or restore from backup:
-- Supabase → Database → Backups → Restore

-- Disable new constraints temporarily if needed:
ALTER TABLE order_items ADD COLUMN subtotal decimal;
UPDATE order_items SET subtotal = quantity * unit_price;
```

---

## Testing Queries

### Test Data Integrity

```sql
-- Verify no NULLs in critical foreign keys
SELECT COUNT(*) FROM user_roles WHERE user_id IS NULL OR role_id IS NULL;
SELECT COUNT(*) FROM user_addresses WHERE user_id IS NULL;
SELECT COUNT(*) FROM farmer_crop_types WHERE registration_id IS NULL;

-- Verify summary aggregates match old columns (before deletion)
SELECT 
  p.id,
  p.average_rating AS old_rating,
  (SELECT AVG(rating) FROM product_reviews WHERE product_id = p.id) AS new_rating
FROM products p
WHERE ABS(p.average_rating - COALESCE((SELECT AVG(rating) FROM product_reviews WHERE product_id = p.id), 0)) > 0.01;

-- Verify order totals (before deletion)
SELECT 
  o.id,
  o.total AS old_total,
  (SELECT SUM(quantity * unit_price) FROM order_items WHERE order_id = o.id) AS new_total
FROM orders o
WHERE o.total != COALESCE((SELECT SUM(quantity * unit_price) FROM order_items WHERE order_id = o.id), 0);
```

### Test VIEWs

```sql
-- Test v_products includes aggregates
SELECT id, name, average_rating, review_count FROM v_products LIMIT 5;

-- Test v_orders includes totals
SELECT id, order_number, total, item_count FROM v_orders LIMIT 5;

-- Test v_forum_posts includes counts
SELECT id, title, likes_count, comments_count FROM v_forum_posts LIMIT 5;

-- Test user roles
SELECT u.id, u.name, r.name AS role FROM users u
JOIN user_roles ur ON ur.user_id = u.id
JOIN roles r ON r.id = ur.role_id;
```

---

## FAQ

**Q: Can I keep the old columns alongside the new tables?**  
A: Yes, during the transition period. Run Phase 1-3, update app code, then Phase 4 when confident.

**Q: What if I have custom queries using `products.farm` or `orders.total`?**  
A: They will break once you drop those columns. Use `v_products` and `v_orders` views instead, which compute these values.

**Q: What about RLS policies?**  
A: Add RLS policies to new tables (`user_roles`, `user_addresses`, etc.) following the same permissions as the original tables. Views inherit base table security.

**Q: Can I use this with Supabase's auto-generated API?**  
A: Yes. Supabase auto-generates CRUD endpoints for base tables. Views are read-only, so use views for `SELECT` and base tables for `INSERT/UPDATE/DELETE`.

---

## Summary

| Phase | Action | Duration | Risk |
|-------|--------|----------|------|
| **1** | Create new tables | 5 min | Low — additive only |
| **2** | Migrate data | 10-15 min | Low — data duplication, can rollback |
| **3** | Create VIEWs | 5 min | None — VIEWs don't modify data |
| **4** | Update app code | 1-2 hours | Medium — test after deploy |
| **5** | Remove old columns | 5 min | High — permanent (backup first!) |

**Total migration time:** ~30-60 minutes with proper planning.


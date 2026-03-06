# AgrIDirect Database ERD (Entity Relationship Diagram)

> **Normalization Level:** Third Normal Form (3NF)  
> All derived/computed columns have been removed from base tables and moved to database VIEWs.  
> All multi-valued attributes have been decomposed into separate tables.  
> All transitive dependencies have been eliminated.

## Database Structure Overview

```mermaid
erDiagram
    USERS ||--o{ USER_ROLES : has
    ROLES ||--o{ USER_ROLES : assigned_to
    USERS ||--o| USER_ADDRESSES : lives_at
    USERS ||--o{ PRODUCTS : creates
    USERS ||--o{ PRODUCT_REVIEWS : writes
    USERS ||--o{ FORUM_POSTS : creates
    USERS ||--o{ FORUM_COMMENTS : writes
    USERS ||--o{ POST_LIKES : gives
    USERS ||--o{ ORDERS : places
    USERS ||--o{ ORDERS : fulfills
    USERS ||--o| FARMER_PROFILES : has
    USERS ||--o| FARMER_REGISTRATIONS : registers
    USERS ||--o| USER_SUSPENSIONS : may_have
    USERS ||--o{ ADMIN_LOGS : performs
    USERS ||--o{ REPORTED_CONTENT : submits
    USERS ||--o{ REPORTED_CONTENT : resolves
    PRODUCTS ||--o{ PRODUCT_REVIEWS : has
    PRODUCTS ||--o{ ORDER_ITEMS : included_in
    PRODUCTS ||--o{ PRODUCT_TAG_MAPPINGS : tagged_with
    CATEGORIES ||--o{ PRODUCTS : contains
    UNITS ||--o{ PRODUCTS : measured_by
    PRODUCT_TAGS ||--o{ PRODUCT_TAG_MAPPINGS : maps_to
    FORUM_POSTS ||--o{ POST_LIKES : receives
    FORUM_POSTS ||--o{ FORUM_COMMENTS : has
    ORDERS ||--o{ ORDER_ITEMS : contains
    FARMER_PROFILES ||--o{ FARMER_SPECIALIZATIONS : specializes_in
    FARMER_REGISTRATIONS ||--o{ FARMER_EDUCATION : educated_at
    FARMER_REGISTRATIONS ||--o{ FARMER_CROP_TYPES : grows
    FARMER_REGISTRATIONS ||--o{ FARMER_LIVESTOCK : raises
    
    USERS {
        uuid user_id PK
        text email UK
        text name
        text phone
        text avatar_url
        text bio
        boolean email_verified
        timestamptz created_at
        timestamptz updated_at
    }

    ROLES {
        uuid role_id PK
        text name UK
        timestamptz created_at
    }

    USER_ROLES {
        uuid user_id FK
        uuid role_id FK
    }

    USER_ADDRESSES {
        uuid address_id PK
        uuid user_id FK UK
        text street
        text barangay
        text city
        text province
        text zip_code
        timestamptz created_at
        timestamptz updated_at
    }
    
    PRODUCTS {
        uuid product_id PK
        text name
        decimal price
        text image_url
        integer harvest_days
        boolean is_preorder
        uuid farmer_id FK
        uuid category_id FK
        uuid unit_id FK
        timestamptz created_at
        timestamptz updated_at
    }
    
    CATEGORIES {
        uuid category_id PK
        text name UK
        text description
        text icon
        timestamptz created_at
    }
    
    UNITS {
        uuid unit_id PK
        text name UK
        text abbreviation UK
        timestamptz created_at
    }
    
    PRODUCT_REVIEWS {
        uuid review_id PK
        uuid product_id FK
        uuid user_id FK
        decimal rating
        text review_text
        timestamptz created_at
        timestamptz updated_at
    }
    
    PRODUCT_TAGS {
        uuid tag_id PK
        text name UK
        timestamptz created_at
    }
    
    PRODUCT_TAG_MAPPINGS {
        uuid product_id FK
        uuid tag_id FK
    }
    
    FORUM_POSTS {
        uuid post_id PK
        uuid user_id FK
        text title
        text body
        text image_url
        timestamptz created_at
        timestamptz updated_at
    }
    
    FORUM_COMMENTS {
        uuid comment_id PK
        uuid post_id FK
        uuid user_id FK
        text body
        timestamptz created_at
        timestamptz updated_at
    }
    
    POST_LIKES {
        uuid like_id PK
        uuid post_id FK
        uuid user_id FK
        timestamptz created_at
    }
    
    ARTICLES {
        uuid article_id PK
        text title
        text content
        uuid author_id FK
        text read_time
        text image_url
        boolean published
        timestamptz created_at
        timestamptz updated_at
    }
    
    ORDERS {
        uuid order_id PK
        text order_number UK
        uuid customer_id FK
        uuid farmer_id FK
        order_status status_enum
        timestamptz created_at
        timestamptz updated_at
    }
    
    ORDER_ITEMS {
        uuid order_item_id PK
        uuid order_id FK
        uuid product_id FK
        decimal quantity
        decimal unit_price
        timestamptz created_at
    }
    
    FARMER_PROFILES {
        uuid profile_id PK
        uuid user_id FK UK
        text farm_name
        text specialty
        text location
        text badge
        text image_url
        boolean is_verified
        timestamptz created_at
        timestamptz updated_at
    }
    
    FARMER_SPECIALIZATIONS {
        uuid specialization_id PK
        uuid farmer_id FK
        text specialization
        timestamptz created_at
    }
    
    FARMER_REGISTRATIONS {
        uuid registration_id PK
        uuid user_id FK UK
        text birth_date
        integer years_of_experience
        text residential_address
        text face_photo_path
        text valid_id_path
        text farming_history
        boolean certification_accepted
        text status
        timestamptz created_at
        timestamptz updated_at
    }

    FARMER_EDUCATION {
        uuid education_id PK
        uuid registration_id FK
        text level
        text school_name
        timestamptz created_at
    }

    FARMER_CROP_TYPES {
        uuid crop_type_id PK
        uuid registration_id FK
        text crop_type
        timestamptz created_at
    }

    FARMER_LIVESTOCK {
        uuid livestock_id PK
        uuid registration_id FK
        text livestock_type
        timestamptz created_at
    }
    
    ADMIN_LOGS {
        uuid log_id PK
        uuid admin_id FK
        text action
        text details
        uuid target_user_id FK
        timestamptz created_at
    }
    
    REPORTED_CONTENT {
        uuid report_id PK
        uuid reporter_id FK
        text content_type
        uuid content_id
        text reason
        text description
        text status
        uuid resolved_by FK
        text resolution_notes
        timestamptz created_at
        timestamptz resolved_at
    }
    
    USER_SUSPENSIONS {
        uuid suspension_id PK
        uuid user_id FK UK
        text reason
        uuid suspended_by FK
        timestamptz suspended_at
        timestamptz expires_at
        boolean is_permanent
        timestamptz created_at
    }
```

---

## Computed VIEWs (Derived Data)

All aggregated/derived values are computed at query time via database VIEWs instead of stored redundantly in base tables.

### `v_products` — Product listing with computed aggregates
```sql
CREATE VIEW v_products AS
SELECT
    p.*,
    c.name AS category_name,
    u.name AS unit_name,
    u.abbreviation AS unit_abbr,
    fp.farm_name,
    COALESCE(AVG(pr.rating), 0) AS average_rating,
    COUNT(pr.review_id) AS review_count
FROM products p
LEFT JOIN categories c ON c.category_id = p.category_id
LEFT JOIN units u ON u.unit_id = p.unit_id
LEFT JOIN farmer_profiles fp ON fp.user_id = p.farmer_id
LEFT JOIN product_reviews pr ON pr.product_id = p.product_id
GROUP BY p.product_id, c.name, u.name, u.abbreviation, fp.farm_name;
```

### `v_forum_posts` — Forum posts with like/comment counts
```sql
CREATE VIEW v_forum_posts AS
SELECT
    fp.*,
    usr.name AS author_name,
    COALESCE(lk.likes_count, 0) AS likes_count,
    COALESCE(cm.comments_count, 0) AS comments_count
FROM forum_posts fp
JOIN users usr ON usr.user_id = fp.user_id
LEFT JOIN (
    SELECT post_id, COUNT(*) AS likes_count FROM post_likes GROUP BY post_id
) lk ON lk.post_id = fp.post_id
LEFT JOIN (
    SELECT post_id, COUNT(*) AS comments_count FROM forum_comments GROUP BY post_id
) cm ON cm.post_id = fp.post_id;
```

### `v_orders` — Orders with computed total and item count
```sql
CREATE VIEW v_orders AS
SELECT
    o.*,
    COALESCE(SUM(oi.quantity * oi.unit_price), 0) AS total,
    COUNT(oi.order_item_id) AS item_count
FROM orders o
LEFT JOIN order_items oi ON oi.order_id = o.order_id
GROUP BY o.order_id;
```

### `v_order_items` — Order items with computed subtotal
```sql
CREATE VIEW v_order_items AS
SELECT
    oi.*,
    (oi.quantity * oi.unit_price) AS subtotal
FROM order_items oi;
```

### `v_farmer_profiles` — Farmer profiles with computed rating
```sql
CREATE VIEW v_farmer_profiles AS
SELECT
    fp.*,
    usr.name AS farmer_name,
    COALESCE(AVG(pr.rating), 0) AS average_rating,
    COUNT(DISTINCT pr.review_id) AS total_reviews
FROM farmer_profiles fp
JOIN users usr ON usr.user_id = fp.user_id
LEFT JOIN products p ON p.farmer_id = fp.user_id
LEFT JOIN product_reviews pr ON pr.product_id = p.product_id
GROUP BY fp.profile_id, usr.name;
```

### `v_articles` — Articles with computed excerpt
```sql
CREATE VIEW v_articles AS
SELECT
    a.*,
    usr.name AS author_name,
    LEFT(a.content, 200) AS excerpt
FROM articles a
LEFT JOIN users usr ON usr.user_id = a.author_id;
```

### `v_users_with_roles` — Users with aggregated role names
```sql
CREATE VIEW v_users_with_roles AS
SELECT
    u.*,
    STRING_AGG(r.name, ', ') AS roles
FROM users u
LEFT JOIN user_roles ur ON ur.user_id = u.user_id
LEFT JOIN roles r ON r.role_id = ur.role_id
GROUP BY u.user_id;
```

---

## Table Relationships Summary

### Core User System
- **USERS** — Central identity table (Supabase Auth)
  - Stores only intrinsic user attributes (name, email, phone, avatar, bio)
  - No role flags — roles managed via USER_ROLES junction table

- **ROLES** — Reference table for role definitions
  - Predefined values: `consumer`, `seller`, `admin`
  - Extensible without schema changes

- **USER_ROLES** — Junction table (USERS ↔ ROLES)
  - Composite PK: (user_id, role_id)
  - A user can hold multiple roles simultaneously

- **USER_ADDRESSES** — Decomposed address (1NF compliant)
  - 1-to-1 with USERS
  - Street, barangay, city, province, zip are separate atomic columns

### Product Management
- **PRODUCTS** — Farmer-created product listings
  - FK to USERS (farmer_id), CATEGORIES, UNITS
  - No stored aggregates — `average_rating` and `review_count` computed via `v_products`
  - No `farm` column — farm name derived from FARMER_PROFILES via farmer_id

- **CATEGORIES** — Normalized reference table for product categories

- **UNITS** — Normalized reference table for measurement units

- **PRODUCT_REVIEWS** — One review per user per product
  - UNIQUE(product_id, user_id)
  - Source of truth for ratings

- **PRODUCT_TAGS** + **PRODUCT_TAG_MAPPINGS** — Many-to-many tagging

### Farmer System
- **FARMER_PROFILES** — Extended farm info (1-to-1 with USERS)
  - No `rating` — computed via `v_farmer_profiles`
  - No `distance` — context-dependent, computed at query time

- **FARMER_SPECIALIZATIONS** — Multi-valued specializations (normalized)

- **FARMER_REGISTRATIONS** — Verification application
  - No `full_name` — derived from USERS.name via user_id
  - No `crop_types`/`livestock` text blobs — decomposed to child tables
  - No `elementary`/`high_school`/`college` repeating group — normalized to FARMER_EDUCATION
  - Single `years_of_experience` (removed duplicate `years_in_farming`)

- **FARMER_EDUCATION** — Education records (level + school_name)
  - level values: `elementary`, `high_school`, `college`, `vocational`, etc.
  
- **FARMER_CROP_TYPES** — Individual crop type entries

- **FARMER_LIVESTOCK** — Individual livestock type entries

### Shopping & Orders
- **ORDERS** — Transaction header
  - No `total` or `item_count` — computed via `v_orders`
  - order_status ENUM: PENDING, CONFIRMED, SHIPPED, DELIVERED, CANCELLED

- **ORDER_ITEMS** — Line items
  - No `subtotal` — computed as quantity × unit_price via `v_order_items`

### Community Features
- **FORUM_POSTS** — User discussions
  - No `likes_count` or `comments_count` — computed via `v_forum_posts`

- **FORUM_COMMENTS** — Post replies

- **POST_LIKES** — Like junction table, UNIQUE(post_id, user_id)

### Content Management
- **ARTICLES** — Published content
  - No `excerpt` — computed via `v_articles` as LEFT(content, 200)

### Admin & Moderation
- **ADMIN_LOGS** — Audit trail (FK to USERS for admin_id and target_user_id)
- **REPORTED_CONTENT** — Moderation reports with status tracking
- **USER_SUSPENSIONS** — Temporary or permanent account restrictions

---

## 3NF Compliance Checklist

| Rule | Status | Details |
|------|--------|---------|
| **1NF: Atomic values** | ✅ | All multi-valued fields decomposed (address → USER_ADDRESSES, crops → FARMER_CROP_TYPES, livestock → FARMER_LIVESTOCK, education → FARMER_EDUCATION) |
| **1NF: No repeating groups** | ✅ | `elementary`/`high_school`/`college` replaced with FARMER_EDUCATION(level, school_name) |
| **2NF: No partial dependencies** | ✅ | All non-key attributes depend on the full primary key |
| **2NF: Junction tables** | ✅ | PRODUCT_TAG_MAPPINGS, POST_LIKES, USER_ROLES use composite keys |
| **3NF: No transitive dependencies** | ✅ | Derived columns removed: `average_rating`, `review_count`, `likes_count`, `comments_count`, `total`, `item_count`, `subtotal`, `rating`, `excerpt`, `farm` |
| **3NF: No derived data in base tables** | ✅ | All computed values served via database VIEWs |
| **3NF: No redundant attributes** | ✅ | `full_name` removed (→ USERS.name), `years_in_farming` removed (duplicate of `years_of_experience`), `distance` removed (context-dependent) |

---

## Normalization Changes Applied

### Redundant / Derived Columns Removed (→ VIEWs)
| Table | Removed Column(s) | Source of Truth |
|-------|--------------------|-----------------|
| PRODUCTS | `average_rating`, `review_count` | `v_products` aggregates from PRODUCT_REVIEWS |
| PRODUCTS | `farm` | `v_products` joins FARMER_PROFILES.farm_name |
| FORUM_POSTS | `likes_count`, `comments_count` | `v_forum_posts` counts from POST_LIKES, FORUM_COMMENTS |
| ORDERS | `total`, `item_count` | `v_orders` aggregates from ORDER_ITEMS |
| ORDER_ITEMS | `subtotal` | `v_order_items` computes quantity × unit_price |
| FARMER_PROFILES | `rating` | `v_farmer_profiles` aggregates from PRODUCT_REVIEWS |
| FARMER_PROFILES | `distance` | Computed at query time (not a stored attribute) |
| ARTICLES | `excerpt` | `v_articles` computes LEFT(content, 200) |

### Multi-Valued Attributes Decomposed (1NF → 3NF)
| Table | Removed Column(s) | New Table |
|-------|--------------------|-----------|
| USERS | `address` (text blob) | USER_ADDRESSES (street, barangay, city, province, zip_code) |
| USERS | `is_seller`, `is_admin` (flags) | ROLES + USER_ROLES (junction) |
| FARMER_REGISTRATIONS | `crop_types` (text) | FARMER_CROP_TYPES (individual entries) |
| FARMER_REGISTRATIONS | `livestock` (text) | FARMER_LIVESTOCK (individual entries) |
| FARMER_REGISTRATIONS | `elementary`, `high_school`, `college` | FARMER_EDUCATION (level, school_name) |

### Transitive Dependencies Removed
| Table | Removed Column | Reason |
|-------|----------------|--------|
| FARMER_REGISTRATIONS | `full_name` | Transitively dependent via user_id → USERS.name |
| FARMER_REGISTRATIONS | `years_in_farming` | Duplicate of `years_of_experience` |

---

## Database Constraints

- **Product Reviews**: UNIQUE(product_id, user_id) — One review per user per product
- **Post Likes**: UNIQUE(post_id, user_id) — One like per user per post
- **User Roles**: UNIQUE(user_id, role_id) — No duplicate role assignments
- **User Suspensions**: UNIQUE(user_id) — One active suspension per user
- **User Addresses**: UNIQUE(user_id) — One address per user
- **Farmer Registrations**: UNIQUE(user_id) — One registration per user
- **Order Numbers**: UNIQUE(order_number) — Unique order identifiers
- **Categories**: UNIQUE(name) — No duplicate categories
- **Units**: UNIQUE(name), UNIQUE(abbreviation) — No duplicate units
- **Roles**: UNIQUE(name) — No duplicate role names
- **Users**: UNIQUE(email) — No duplicate emails

---

## Data Flow

1. **User Registration** → USERS + USER_ROLES(consumer) + USER_ADDRESSES
2. **Farmer Verification** → FARMER_REGISTRATIONS + FARMER_EDUCATION + FARMER_CROP_TYPES + FARMER_LIVESTOCK
3. **Farmer Approved** → FARMER_PROFILES + FARMER_SPECIALIZATIONS + USER_ROLES(seller)
4. **Product Creation** → PRODUCTS (FK to CATEGORIES, UNITS) + PRODUCT_TAG_MAPPINGS
5. **Product Reviews** → PRODUCT_REVIEWS (aggregates computed by `v_products`)
6. **Shopping** → ORDERS + ORDER_ITEMS (totals computed by `v_orders`)
7. **Community** → FORUM_POSTS + FORUM_COMMENTS + POST_LIKES (counts computed by `v_forum_posts`)
8. **Content** → ARTICLES (excerpt computed by `v_articles`)
9. **Admin Functions** → ADMIN_LOGS + REPORTED_CONTENT + USER_SUSPENSIONS

---

## Key Characteristics

✅ **Third Normal Form (3NF)** — No transitive dependencies, no derived data in base tables  
✅ **First Normal Form (1NF)** — All values atomic, no repeating groups, no multi-valued columns  
✅ **Row Level Security (RLS)** — All tables have security policies  
✅ **Computed VIEWs** — Aggregates (ratings, counts, totals) served via VIEWs, not stored redundantly  
✅ **UUIDs** — All primary keys use UUID for security  
✅ **Foreign Keys** — Proper FK relationships with ON DELETE CASCADE  
✅ **ENUM Types** — order_status for type safety  
✅ **Unique Constraints** — Enforced at the database level for all business rules  
✅ **Audit Trail** — Admin logs and moderation tracking  
✅ **Zero Redundancy** — No column stores data derivable from other tables

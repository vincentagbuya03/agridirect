# Database Schema Quick Reference

## Tables Overview

### USER MANAGEMENT

**users**
```
user_id: UUID (PK, FK auth.users.id)
email: TEXT (UK)
name: TEXT
phone: TEXT
avatar_url: TEXT
bio: TEXT
email_verified: BOOL
created_at: TIMESTAMPTZ
updated_at: TIMESTAMPTZ
```

**roles**
```
role_id: UUID (PK)
name: TEXT (UK) - 'consumer', 'seller', 'admin'
created_at: TIMESTAMPTZ
```

**user_roles** (Junction)
```
user_id: UUID (FK users)
role_id: UUID (FK roles)
PK: (user_id, role_id)
```

**user_addresses**
```
address_id: UUID (PK)
user_id: UUID (UK, FK users)
street: TEXT
barangay: TEXT
city: TEXT
province: TEXT
zip_code: TEXT
created_at: TIMESTAMPTZ
updated_at: TIMESTAMPTZ
```

**verification_codes**
```
verification_id: UUID (PK)
user_email: TEXT (UK)
code: TEXT
attempts: INT
is_verified: BOOL
expires_at: TIMESTAMPTZ
created_at: TIMESTAMPTZ
```

### PRODUCTS

**categories**
```
category_id: UUID (PK)
name: TEXT (UK)
description: TEXT
icon: TEXT
created_at: TIMESTAMPTZ
```

**units**
```
unit_id: UUID (PK)
name: TEXT (UK)
abbreviation: TEXT (UK)
created_at: TIMESTAMPTZ
```

**products**
```
product_id: UUID (PK)
name: TEXT
price: DECIMAL(10,2)
description: TEXT
image_url: TEXT
harvest_days: INT
is_preorder: BOOL
farmer_id: UUID (FK users)
category_id: UUID (FK categories)
unit_id: UUID (FK units)
created_at: TIMESTAMPTZ
updated_at: TIMESTAMPTZ
```

**product_tags**
```
tag_id: UUID (PK)
name: TEXT (UK)
created_at: TIMESTAMPTZ
```

**product_tag_mappings** (Junction)
```
product_id: UUID (FK products)
tag_id: UUID (FK product_tags)
PK: (product_id, tag_id)
```

**product_reviews**
```
review_id: UUID (PK)
product_id: UUID (FK products)
user_id: UUID (FK users)
rating: DECIMAL(2,1) - 1 to 5
review_text: TEXT
created_at: TIMESTAMPTZ
updated_at: TIMESTAMPTZ
UNIQUE: (product_id, user_id)
```

### FARMER SYSTEM

**farmer_profiles**
```
profile_id: UUID (PK)
user_id: UUID (UK, FK users)
farm_name: TEXT
specialty: TEXT
location: TEXT
badge: TEXT
image_url: TEXT
is_verified: BOOL
created_at: TIMESTAMPTZ
updated_at: TIMESTAMPTZ
```

**farmer_specializations**
```
specialization_id: UUID (PK)
farmer_id: UUID (FK users)
specialization: TEXT
created_at: TIMESTAMPTZ
```

**farmer_registrations**
```
registration_id: UUID (PK)
user_id: UUID (UK, FK users)
birth_date: TEXT
years_of_experience: INT
residential_address: TEXT
face_photo_path: TEXT
valid_id_path: TEXT
farming_history: TEXT
certification_accepted: BOOL
status: TEXT - 'pending', 'approved', 'rejected'
created_at: TIMESTAMPTZ
updated_at: TIMESTAMPTZ
```

**farmer_education**
```
education_id: UUID (PK)
registration_id: UUID (FK farmer_registrations)
level: TEXT - 'elementary', 'high_school', 'college', 'vocational'
school_name: TEXT
created_at: TIMESTAMPTZ
```

**farmer_crop_types**
```
crop_type_id: UUID (PK)
registration_id: UUID (FK farmer_registrations)
crop_type: TEXT
created_at: TIMESTAMPTZ
```

**farmer_livestock**
```
livestock_id: UUID (PK)
registration_id: UUID (FK farmer_registrations)
livestock_type: TEXT
created_at: TIMESTAMPTZ
```

### ORDERS

**orders**
```
order_id: UUID (PK)
order_number: TEXT (UK)
customer_id: UUID (FK users)
farmer_id: UUID (FK users)
status: ENUM - 'pending', 'confirmed', 'shipped', 'delivered', 'cancelled'
created_at: TIMESTAMPTZ
updated_at: TIMESTAMPTZ
```

**order_items**
```
order_item_id: UUID (PK)
order_id: UUID (FK orders)
product_id: UUID (FK products)
quantity: DECIMAL(10,2)
unit_price: DECIMAL(10,2)
created_at: TIMESTAMPTZ
```

### COMMUNITY

**forum_posts**
```
post_id: UUID (PK)
user_id: UUID (FK users)
title: TEXT
body: TEXT
image_url: TEXT
created_at: TIMESTAMPTZ
updated_at: TIMESTAMPTZ
```

**forum_comments**
```
comment_id: UUID (PK)
post_id: UUID (FK forum_posts)
user_id: UUID (FK users)
body: TEXT
created_at: TIMESTAMPTZ
updated_at: TIMESTAMPTZ
```

**post_likes** (Junction)
```
like_id: UUID (PK)
post_id: UUID (FK forum_posts)
user_id: UUID (FK users)
created_at: TIMESTAMPTZ
UNIQUE: (post_id, user_id)
```

### ADMIN

**articles**
```
article_id: UUID (PK)
title: TEXT
content: TEXT
author_id: UUID (FK users, NULL)
read_time: TEXT
image_url: TEXT
published: BOOL
created_at: TIMESTAMPTZ
updated_at: TIMESTAMPTZ
```

**admin_logs**
```
log_id: UUID (PK)
admin_id: UUID (FK users)
action: TEXT
details: TEXT
target_user_id: UUID (FK users, NULL)
created_at: TIMESTAMPTZ
```

**reported_content**
```
report_id: UUID (PK)
reporter_id: UUID (FK users)
content_type: TEXT - 'post', 'comment', 'review', 'product', 'profile'
content_id: UUID
reason: TEXT
description: TEXT
status: TEXT - 'pending', 'reviewing', 'resolved', 'dismissed'
resolved_by: UUID (FK users, NULL)
resolution_notes: TEXT
created_at: TIMESTAMPTZ
resolved_at: TIMESTAMPTZ
```

**user_suspensions**
```
suspension_id: UUID (PK)
user_id: UUID (UK, FK users)
reason: TEXT
suspended_by: UUID (FK users)
suspended_at: TIMESTAMPTZ
expires_at: TIMESTAMPTZ
is_permanent: BOOL
created_at: TIMESTAMPTZ
```

## VIEWS (Denormalized Data for Display)

**v_products**
```
[columns from products]
+ category_name: TEXT
+ unit_name: TEXT
+ unit_abbr: TEXT
+ farm_name: TEXT
+ average_rating: DECIMAL(2,1)
+ review_count: INT
```

**v_forum_posts**
```
[columns from forum_posts]
+ author_name: TEXT
+ author_avatar: TEXT
+ likes_count: INT
+ comments_count: INT
```

**v_orders**
```
[columns from orders]
+ total: DECIMAL
+ item_count: INT
```

**v_order_items**
```
[columns from order_items]
+ subtotal: DECIMAL
+ product_name: TEXT
+ product_image: TEXT
```

**v_farmer_profiles**
```
[columns from farmer_profiles]
+ farmer_name: TEXT
+ farmer_email: TEXT
+ farmer_phone: TEXT
+ average_rating: DECIMAL(2,1)
+ total_reviews: INT
```

**v_articles**
```
[columns from articles]
+ author_name: TEXT
+ excerpt: TEXT (first 200 chars)
```

**v_users_with_roles**
```
[columns from users]
+ roles: TEXT (comma-separated)
```

## Key Relationships

```
users
├── user_addresses (1:1)
├── user_roles (many:many via roles)
├── products (1:many as farmer_id)
├── product_reviews (1:many as user_id)
├── farmer_profiles (1:1)
├── farmer_registrations (1:1)
├── forum_posts (1:many)
├── forum_comments (1:many)
├── post_likes (1:many)
├── orders (1:many as customer_id)
├── orders (1:many as farmer_id)
├── admin_logs (1:many as admin_id)
└── reported_content (1:many as reporter_id)

products
├── categories (many:1)
├── units (many:1)
├── product_reviews (1:many)
├── product_tag_mappings (many:many via product_tags)
└── order_items (1:many)

orders
└── order_items (1:many)

forum_posts
├── forum_comments (1:many)
└── post_likes (1:many)

farmer_registrations
├── farmer_education (1:many)
├── farmer_crop_types (1:many)
└── farmer_livestock (1:many)
```

## Indexes for Performance

```
users: (email), created_at
user_addresses: (user_id)
user_roles: (role_id)
products: (farmer_id), (category_id), (unit_id), (name), (created_at)
product_reviews: (product_id), (user_id)
product_tags: (name)
product_tag_mappings: (tag_id)
categories: (name)
units: (abbreviation)
farmer_profiles: (user_id), (is_verified)
farmer_specializations: (farmer_id)
farmer_registrations: (user_id), (status)
farmer_education: (registration_id)
farmer_crop_types: (registration_id)
farmer_livestock: (registration_id)
orders: (customer_id), (farmer_id), (order_number), (status)
order_items: (order_id), (product_id)
forum_posts: (user_id), (created_at)
forum_comments: (post_id), (user_id)
post_likes: (post_id), (user_id)
articles: (author_id), (published)
admin_logs: (admin_id), (target_user_id), (created_at)
reported_content: (reporter_id), (status), (content_type)
user_suspensions: (user_id), (suspended_by), (expires_at)
```

## Column Types Reference

| Type | Usage | Example |
|------|-------|---------|
| UUID | Primary/Foreign keys | user_id, product_id |
| TEXT | Strings | name, email, description |
| DECIMAL(10,2) | Money, measurements | price: 150.50, quantity: 5.25 |
| INT | Counts, days | harvest_days, years_of_experience |
| BOOL | Flags | is_preorder, email_verified |
| TIMESTAMPTZ | Timestamps | created_at, updated_at |
| ENUM | Fixed options | order_status, farmer_registration_status |

## RLS Policies Summary

| Table | SELECT | INSERT | UPDATE | DELETE |
|-------|--------|--------|--------|--------|
| users | Self + Public limited | Self (signup) | Self | Admin |
| products | Public | Seller only | Owner + Admin | Owner |
| orders | Customer/Farmer | Customer | Both can update status | Customer |
| farmer_profiles | Public | Farmer (self) | Farmer (self) | Admin |
| forum_posts | Public | Authenticated | Owner | Owner |
| articles | Published + Admin sees all | Admin | Admin | Admin |
| admin_logs | Admin | System | Admin | - |
| user_suspensions | Self/Admin | Admin | Admin | Admin |

---

**Quick Link**: See [BACKEND_SETUP.md](BACKEND_SETUP.md) for implementation details

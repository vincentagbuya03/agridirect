# AgrIDirect Backend Setup Guide

Complete backend infrastructure for AgrIDirect platform built with Supabase and Flutter.

## 📋 Project Structure

```
agridirect/
├── database/
│   └── migrations/
│       ├── 001_init_core_tables.sql       # Users, roles, auth
│       ├── 002_products_tables.sql        # Products, categories, reviews
│       ├── 003_farmer_tables.sql          # Farmer profiles, registrations
│       ├── 004_orders_tables.sql          # Orders, order items
│       ├── 005_community_tables.sql       # Forum, comments, likes
│       ├── 006_admin_tables.sql           # Moderation, admin logs
│       ├── 007_views.sql                  # Database views for aggregates
│       └── 008_rls_policies.sql           # Row Level Security policies
│
├── lib/
│   └── shared/
│       ├── models/
│       │   ├── auth/
│       │   │   ├── user_model.dart
│       │   │   └── user_address_model.dart
│       │   ├── product/
│       │   │   ├── product_model.dart
│       │   │   ├── category_model.dart
│       │   │   ├── unit_model.dart
│       │   │   └── product_review_model.dart
│       │   ├── farmer/
│       │   │   ├── farmer_profile_model.dart
│       │   │   └── farmer_registration_model.dart
│       │   ├── order/
│       │   │   ├── order_model.dart
│       │   │   └── order_item_model.dart
│       │   └── forum/
│       │       ├── forum_post_model.dart
│       │       └── forum_comment_model.dart
│       │
│       └── services/
│           ├── user_service.dart          # User profile & address management
│           ├── product_service.dart       # Products, categories, reviews
│           ├── farmer_service.dart        # Farmer profiles & registrations
│           ├── order_service.dart         # Orders & order items
│           ├── forum_service.dart         # Community posts & interactions
│           ├── admin_service.dart         # Admin operations & moderation
│           └── supabase_config.dart       # Supabase initialization
```

## 🚀 Installation Steps

### 1. Add JSON Serialization Dependencies

Add to `pubspec.yaml`:

```yaml
dev_dependencies:
  build_runner: ^2.4.0
  json_serializable: ^6.7.0
```

Run:
```bash
flutter pub get
```

### 2. Generate JSON Serialization Code

For each model file, run:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

Or watch mode for continuous generation:
```bash
flutter pub run build_runner watch --delete-conflicting-outputs
```

### 3. Create Supabase Migration Files

1. Go to your Supabase project dashboard
2. Navigate to **SQL Editor** → **New Query**
3. Copy contents from each migration file in order:
   - `001_init_core_tables.sql`
   - `002_products_tables.sql`
   - `003_farmer_tables.sql`
   - `004_orders_tables.sql`
   - `005_community_tables.sql`
   - `006_admin_tables.sql`
   - `007_views.sql`
   - `008_rls_policies.sql`
4. Run each migration sequentially

### 4. Verify Database Setup

After migrations, verify in Supabase:
- ✅ All tables created with correct columns
- ✅ Views visible in **Database** → **Views**
- ✅ RLS policies enabled on all tables
- ✅ Indexes created for performance

## 📦 Database Schema

### Core Tables (3NF Compliant)

**USERS** - Supabase Auth integration
```
user_id (UUID, PK, FK auth.users.id)
email (TEXT, UK)
name (TEXT)
phone (TEXT, NULL)
avatar_url (TEXT, NULL)  
bio (TEXT, NULL)
email_verified (BOOL)
created_at, updated_at (TIMESTAMPTZ)
```

**PRODUCTS** - Farmer listings
```
product_id (UUID, PK)
name, price (DECIMAL), description, image_url
harvest_days (INT), is_preorder (BOOL)
farmer_id (UUID, FK users)
category_id (UUID, FK categories)
unit_id (UUID, FK units)
created_at, updated_at
```

**ORDERS** - Customer purchases
```
order_id (UUID, PK)
order_number (TEXT, UK)
customer_id, farmer_id (UUID, FK users)
status (ENUM: PENDING, CONFIRMED, SHIPPED, DELIVERED, CANCELLED)
created_at, updated_at
```

**FARMER_PROFILES**
```
profile_id (UUID, PK)
user_id (UUID, UK, FK users)
farm_name, specialty, location, badge, image_url
is_verified (BOOL)
created_at, updated_at
```

**FARMER_REGISTRATIONS**
```
registration_id (UUID, PK)
user_id (UUID, UK, FK users)
birth_date, years_of_experience
residential_address, face_photo_path, valid_id_path
farming_history, certification_accepted
status (ENUM: PENDING, APPROVED, REJECTED)
created_at, updated_at
```

See [DATABASE_ERD.md](DATABASE_ERD.md) for complete schema.

## 🔐 Row Level Security (RLS)

All tables have RLS policies implemented:

- **Public read**: Users, products (anyone can view)
- **Own data access**: Each user can only read/modify their own records
- **Role-based**: Admin-only access to moderation features
- **Farmer operations**: Only sellers can create/manage products
- **Customer orders**: Only customer/farmer of order can view it

Example checking RLS in Flutter:
```dart
try {
  final products = await productService.getProducts();
  // If user has no permission, Supabase throws exception
} on PostgrestException catch (e) {
  if (e.code == '42501') {
    print('Permission denied - RLS policy');
  }
}
```

## 🔧 Using Services

### Example: Fetch Products

```dart
import 'package:agridirect/shared/services/product_service.dart';

final productService = ProductService();

// Get all products
final products = await productService.getProducts(limit: 20);

// Get by category
final categoryProducts = 
  await productService.getProductsByCategory(categoryId);

// Create product (seller only)
final newProduct = await productService.createProduct(
  name: 'Fresh Tomatoes',
  price: 150.00,
  categoryId: 'cat-001',
  unitId: 'unit-001',
  description: 'Organic tomatoes',
  isPreorder: false,
);

// Search
final results = await productService.searchProducts('tomato');
```

### Example: Create Order

```dart
import 'package:agridirect/shared/services/order_service.dart';

final orderService = OrderService();

final order = await orderService.createOrder(
  farmerId: 'farmer-123',
  items: [
    OrderItemInput(
      productId: 'prod-001',
      quantity: 5,
      unitPrice: 150.00,
    ),
    OrderItemInput(
      productId: 'prod-002',
      quantity: 3,
      unitPrice: 200.00,
    ),
  ],
);
```

### Example: Forum Operations

```dart
import 'package:agridirect/shared/services/forum_service.dart';

final forumService = ForumService();

// Create post
final post = await forumService.createPost(
  title: 'Tips for growing vegetables',
  body: 'Here are some effective techniques...',
);

// Get posts
final posts = await forumService.getPosts(limit: 20);

// Comment on post
final comment = await forumService.createComment(
  postId: post.postId,
  body: 'Great tips!',
);

// Like post
await forumService.likePost(post.postId);
```

### Example: Farmer Registration

```dart
import 'package:agridirect/shared/services/farmer_service.dart';

final farmerService = FarmerService();

// Register as farmer
final registration = await farmerService.createRegistration(
  birthDate: '1990-05-15',
  yearsOfExperience: 10,
  residentialAddress: '123 Farm Lane',
  farmingHistory: 'Third generation farmer',
  certificationAccepted: true,
);

// Add education
await farmerService.addEducation(
  registrationId: registration.registrationId,
  level: 'high_school',
  schoolName: 'Quezon National High School',
);

// Add crops
await farmerService.addCropType(
  registrationId: registration.registrationId,
  cropType: 'Rice',
);
```

### Example: Admin Operations

```dart
import 'package:agridirect/shared/services/admin_service.dart';

final adminService = AdminService();

// Check if user is admin
final isAdmin = await adminService.isCurrentUserAdmin();

if (isAdmin) {
  // Get pending registrations
  final pending = await adminService.getPendingRegistrations();
  
  // Approve farmer
  await adminService.approveFarmerRegistration(
    registrationId,
    userId,
  );
  
  // Handle content report
  final reports = await adminService.getPendingReports();
  await adminService.resolveReport(
    reportId,
    action: 'delete_post',
    resolutionNotes: 'Violates community guidelines',
  );
  
  // Suspend user
  await adminService.suspendUser(
    userId,
    reason: 'Inappropriate behavior',
    isPermanent: false,
    expiresAt: DateTime.now().add(Duration(days: 7)),
  );
}
```

## 📋 Common Queries

### Search Products
```dart
final results = await productService.searchProducts('tomato');
```

### Get Farmer's Products
```dart
final farmProducts = await productService.getFarmerProducts(farmerId);
```

### Get User's Orders
```dart
final myOrders = await orderService.getMyOrders(limit: 20);
```

### Get Farmer's Received Orders
```dart
final receivedOrders = await orderService.getFarmerOrders(limit: 20);
```

### Filter By Status
```dart
// Modify services to add status filtering if needed
// Currently orders are retrieved by user role
```

## 🔄 Data Flow Examples

### Product Listing Flow
1. User opens Products screen
2. `ProductService.getProducts()` → Calls `v_products` view
3. View aggregates ratings + farm info
4. UI displays products with ratings & farm names

### Order Creation Flow
1. User adds items to cart
2. `OrderService.createOrder()` 
3. Creates Order + inserts OrderItems
4. Automatic order_number generation
5. Status defaults to 'pending'
6. Customer & farmer can track via `getMyOrders()` / `getFarmerOrders()`

### Farmer Verification Flow
1. Farmer submits `FarmerService.createRegistration()`
2. Admin sees in `AdminService.getPendingRegistrations()`
3. Admin reviews documents & calls `approveFarmerRegistration()`
4. User gets 'seller' role automatically
5. Can now create products

### Forum Interaction Flow
1. User posts: `ForumService.createPost()`
2. Others comment: `createComment()`
3. Others like: `likePost()`
4. View `v_forum_posts` shows likes_count + comments_count
5. Delete: `deletePost()` / `deleteComment()`

## 🛡️ Error Handling

All service methods throw exceptions:

```dart
try {
  final product = await productService.createProduct(
    name: 'Tomatoes',
    price: 150,
    categoryId: 'cat-001',
    unitId: 'unit-001',
  );
} on PostgrestException catch (e) {
  // Supabase error (constraint violation, permission, etc)
  print('Database error: ${e.message}');
} catch (e) {
  // Other errors
  print('Error: $e');
}
```

## 📈 Performance Optimizations

- **Indexes**: Created on frequently queried columns (farmer_id, category_id, created_at)
- **Views**: Computed aggregates at query time, not stored redundantly
- **Pagination**: Use limit/offset to handle large datasets
- **RLS**: Automatically filters data at database level

## ✅ Testing Checklist

Before deploying:

- [ ] Run all migrations in order
- [ ] Test user registration flow
- [ ] Test farmer registration & approval
- [ ] Test product creation & search
- [ ] Test order creation & status updates
- [ ] Test forum posts & comments
- [ ] Test RLS policies (should block unauthorized access)
- [ ] Test admin functions
- [ ] Verify computed views return correct aggregates

## 📞 Next Steps

1. **Generate JSON models**: Run `flutter pub run build_runner build`
2. **Test services**: Create simple test screens
3. **Implement UI**: Build screens using services
4. **Add state management**: Consider Provider, Riverpod, or GetX
5. **Error handling**: Add user-friendly error messages

## 📚 Additional Resources

- [Supabase Docs](https://supabase.com/docs)
- [Flutter Supabase Plugin](https://supabase.com/docs/reference/dart)
- [Database ERD](DATABASE_ERD.md)
- [Normalization Details](MIGRATION_TO_3NF.md)

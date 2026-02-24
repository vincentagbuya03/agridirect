/// Shared data layer — used by both mobile and web UIs.
/// Only data & logic lives here; no Flutter widgets.

class ProductItem {
  final String name;
  final String farm;
  final String price;
  final String unit;
  final String imageUrl;
  final String? rating;
  final String? reviews;
  final String? harvestDays;

  const ProductItem({
    required this.name,
    required this.farm,
    required this.price,
    required this.unit,
    required this.imageUrl,
    this.rating,
    this.reviews,
    this.harvestDays,
  });
}

class CategoryItem {
  final String name;
  final int iconCodePoint;
  final int bgColor;
  final int iconColor;

  const CategoryItem({
    required this.name,
    required this.iconCodePoint,
    required this.bgColor,
    required this.iconColor,
  });
}

class ForumPostItem {
  final String userName;
  final String time;
  final String title;
  final String body;
  final String? imageUrl;
  final int likes;
  final int comments;
  final bool isLiked;

  const ForumPostItem({
    required this.userName,
    required this.time,
    required this.title,
    required this.body,
    this.imageUrl,
    required this.likes,
    required this.comments,
    required this.isLiked,
  });
}

class ArticleItem {
  final String title;
  final String excerpt;
  final String author;
  final String readTime;
  final String? imageUrl;

  const ArticleItem({
    required this.title,
    required this.excerpt,
    this.author = 'AgriDirect',
    this.readTime = '4 min read',
    this.imageUrl,
  });
}

class DashboardMetric {
  final String label;
  final String value;
  final String subtitle;
  final int iconCodePoint;
  final int color;

  const DashboardMetric({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.iconCodePoint,
    required this.color,
  });
}

// ─────────────────────────────────────────────
//  Static data constants shared across platforms
// ─────────────────────────────────────────────

class AppData {
  AppData._();

  // Image URLs
  static const String farmerAvatarUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuA7SO8J3CebwmP_4K0nwWhDkMsWISrTpnfbOkYJ79_ZiTCLVxdvX_FJArJ1xwYsLAJx8gW_Wtk3xValGb9mDShlpRvdPIMoD9UGWJ9LwNRlF0vvmsKesjK6liNaDGy7C5HGWdOAE1hEPvF3UTq81_QK7QkgKAAMQgeICa4pykDXTF8JYtnrFYPiavyC7N-wkK4pGMGQJcdoyKpRglzbFXWGqTdoa3xP-Bm86BGxFKlWg21Mbw-FylTfHiJeJMKgLbfSJr8MhPFg1zqB';

  static const String tomatoImageUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuC3s936BvGOwFH5Pc8hRKIB2w1ylddc7XqdTh2n_z740ysBDvNPiQGq-eBGDkmN4Nv4YLrDQy5kon3ABU7rTEBhPq_8YTJabLHxNGJT8pD5PwiPsdVd_aMWZrsiO2tDr_BoHp3L2C6e1IGVNVNhnO0ewUPLxMLf03rC1tP_Kl31p2fkib4GvCE1epTRTN53gFWgqQPnYgSfvzTSDv_TOwVRzOQS-DLnnh5C6Pd7p1q0VGvBFr04swnJVDQUhNcp4FKqhUV5T_WkTeXI';

  static const String cauliflowerImageUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuDFaQTdzl2IyUcUoH9jfP_TSPARzBFAvJbQjZzvoOUI90R72wmj1N0SWz8tRpAJXORbY4ZX1Y_MEd7edirhUW2pwMpLcSU9UQ53SgUQIepuy04PJrtUIp1PKE3Sgu4DxYdo-pi5CwQzWz-IGFRzRk-1b0WacMgkbNW-EgnkAt0EKqe-p0l2t7rlclG_rZtSn-fNIIBggUTiLr-Jn8q86JU79X3teeNt4tA4Hz-cFcy4F29m23EvZhmsCHJlvvDGias0ukkLoPZ6_c0F';

  static const String spinachImageUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuBACl6FiXMfquE6zNBeNtkQhdEIqZkwlURp2Xh--BjMgMWluRDSrD0FdAHwUSnj_1WglWmFfeuICooOHlBeyWkksKYez20U4E4VRpn1_HFgvdcmb4ym3thUmEJjE7w_j71FLDP09M9wTLHGdNCqUzj8ByzMCDBo_xRjljPqUHgFW0AD4GAYUQx45xU9-84M2nt4lKfvDGw4VHewq4WmunWk2KIS89kjjJ-B9fi8MMxDBl7jgn4iA3Qg9Tp2wVsdVnFfEQTeo04yWpJC';

  static const String mangoImageUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuCzaycfp36jzsWuHU3oZT7Xz3dqm0ERiWpttIP6--gPaasAI-N0F4f3b8F9Mnciub2heSQEAfkHrzCY5qT7JOvNS4_2sRHlBTrDH80hlwNUocAXAJJVpEeY1rPlOKjOgwpbHRA1GxAuVV8hkZb3dhsIe8YZhcKGjYUqgTcXeW1_yYUV6iyvEgQzTflMAGfHI5JamjQk6AIk4N1GvNHsT0ny3WJPyU4pvxa9GJ76A3-cRDTR8CZUXzGCUqv0Z3PLE6e2_WOUtHq5rAxr';

  static const String carrotsHeroImageUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuCVCYBm88jPNAGEUzu0F4fjpowH8six3tnJISCt39AlsGwpTBZJJoT--5pgw3BmmXHnjtx0ajJjSqgHo53GUOLi3KLGPtPbs3DXKaLTZ4OCgkkCp0Mqj11XLmI93ub3inMtyUvEq5OVXXcT2AFJ8V_iRDGver4b4knqQ3DdXOjlw-ZBBCyjOk5tris8sIG5R-vYgPyh1Xt6t13CRg3L7dm-BcYBOuci06ybbYJivaHwJHWxD43kHUEi3uZkpWjidhrvlWHrYtTrtBbW';

  static const String farmStoryAvatarUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuBoVS1AG40SSaFSUU2moL6YqWM3YpcS6jHQsRPh6KSBUaY1RugzPdmPa39E3LPmSmHFnPxGCMN9T8zTGVOjHPDCWUu8CLRDpTNEJ-8JODbAgIAYYuNYJAnXTlz4-Yxqs2ccfPtcDSrbdZ6d5eKcPWD1cdtRyyEG3qc7H8MkQ4Xqh3ygXFK7IEmWug0N1bJRnh-KJqa6MyXdYHPnvp6KqPpyMBvxPbH5BWYFdmKurL6pD20OTlZav1esmVgy2F_loUUgQfL9p9CQVlL1';

  static const String farmMapImageUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuB-JtNk4HGhZ6HsMXiIKdyyd-VCQi0rV4whdO-MCNzdF_ma6gsDJTVVDbsQz4VbUnpHKSbiTqciqEwJpQOkqmAhc97CJ9PNDtOK9GxMKGWZ_qZSqtec5cGgpzsVlWRcOzwuEvp0ivWmEw27i9bTiMXqW_Lzj17OrLB6kSyTmHLFfFCkzfCl5gtn9uLPdS9596wRIuDKdchPcRBOwcaEcZ_XL1nr8zDazy0t-lU-jgd0Vw7Qr0nYyBvJz8nMD5o7tYw2GF8tokynMBYE';

  static const String forumImageUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuAU5BsZk45a4YKNRYGbLaIQtrv4SrXQisINXE6bEWrn68xyvpSXq3DGS0NIoQ6S61cLQd-k6WgXWLxteyZ6anZKx-ZZ0nYRrD4xbcEQciC1ZJE-Nx3Tkp6YKeBtp9G_uCIVYiMjp2CmFRrJw9Vgzz-Ny3lzle9oxyIc5OWEFCAkbqgeTzwA4jtitlBSWTAEKE3gntriMWx1wR2w6aENpGu7RC6EMwg1KT1IpY4zqekWP8B30sin5nEXmA4blGH07t_yood2PKglLaqQ';

  static const String articleImageUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuCEX_FGbTSlEvgcVwHHEMfPDvDPCwf1jJgoRvqWeM8YKnhq8MslvsCTDPBiEOLgf3ghqffQxCGDQaDPrUPojIs8Hun-ffZwkSQqnqYzomI0eTTnZPMnVJBbp9YWKVBJ11uHyhNV9em8FQJ4zwY1NdiWx-7XTpZ99nPgQrz7YSgBAbjFGHI-kjDVMfghvcp1_6wcRXV6PUgvLTA215YdbIKOEwxK0JE2lWioNIZ-pdZHBenPdwZi2VwpDUO-Z7_KTqbiJBgPyZTYBanU';

  // Pre-order products
  static const List<ProductItem> preOrderProducts = [
    ProductItem(
      name: 'Premium Vine Tomatoes',
      farm: 'Poblacion Farm, Benguet',
      price: '₱120',
      unit: '/kg',
      imageUrl: tomatoImageUrl,
      harvestDays: '5',
    ),
    ProductItem(
      name: 'Organic Cauliflower',
      farm: 'Green Valley, Batangas',
      price: '₱85',
      unit: '/pc',
      imageUrl: cauliflowerImageUrl,
      harvestDays: '3',
    ),
    ProductItem(
      name: 'Fresh Bell Peppers',
      farm: 'Sunrise Farm',
      price: '₱95',
      unit: '/kg',
      imageUrl: tomatoImageUrl,
      harvestDays: '7',
    ),
    ProductItem(
      name: 'Organic Spinach',
      farm: 'Luntian Gardens',
      price: '₱55',
      unit: '/bunch',
      imageUrl: spinachImageUrl,
      harvestDays: '4',
    ),
  ];

  // Nearby farm products
  static const List<ProductItem> nearbyProducts = [
    ProductItem(
      name: 'Sweet Carabao Mango',
      farm: 'Vibrant Farms, Cavite',
      price: '₱180',
      unit: '/kg',
      imageUrl: mangoImageUrl,
      rating: '4.8',
      reviews: '120',
    ),
    ProductItem(
      name: 'Organic Spinach',
      farm: 'Luntian Gardens, Laguna',
      price: '₱45',
      unit: '/bunch',
      imageUrl: spinachImageUrl,
      rating: '4.9',
      reviews: '86',
    ),
    ProductItem(
      name: 'Fresh Carrots',
      farm: 'Orange Hills Farm',
      price: '₱60',
      unit: '/kg',
      imageUrl: tomatoImageUrl,
      rating: '4.7',
      reviews: '156',
    ),
  ];

  // Forum posts
  static const List<ForumPostItem> forumPosts = [
    ForumPostItem(
      userName: 'Samuel Green',
      time: '2 hours ago • Punjab',
      title: 'Pest control tips for Cabbage',
      body:
          "I've found that neem oil works wonders for aphids on young cabbage plants. Make sure to spray in the evening to avoid leaf burn...",
      imageUrl: forumImageUrl,
      likes: 24,
      comments: 12,
      isLiked: true,
    ),
    ForumPostItem(
      userName: 'Anita Rao',
      time: '5 hours ago • Karnataka',
      title: 'New organic fertilizer subsidy?',
      body:
          'Has anyone heard about the new state-level subsidies for organic vermicompost setups? Looking for registration details.',
      likes: 8,
      comments: 3,
      isLiked: false,
    ),
  ];

  // Articles
  static const List<ArticleItem> articles = [
    ArticleItem(
      title: 'Optimizing Drip Irrigation for Small Farms in 2024',
      excerpt:
          'Learn how to maximize water efficiency while reducing operational costs in modern agriculture...',
      imageUrl: articleImageUrl,
    ),
    ArticleItem(
      title: 'Sustainable Water Management in Agriculture',
      excerpt:
          'Learn how to optimize water usage while maintaining crop health...',
    ),
    ArticleItem(
      title: 'Market Trends: Q4 2024',
      excerpt: 'Overview of upcoming agricultural market opportunities...',
    ),
  ];

  // Dashboard metrics
  static const List<DashboardMetric> dashboardMetrics = [
    DashboardMetric(
      label: 'PENDING',
      value: '12',
      subtitle: 'Orders to fulfill',
      iconCodePoint: 0xe8cc, // shopping_cart
      color: 0xFF10B981,
    ),
    DashboardMetric(
      label: 'LISTINGS',
      value: '48',
      subtitle: 'Active products',
      iconCodePoint: 0xef37, // inventory_2
      color: 0xFF3B82F6,
    ),
    DashboardMetric(
      label: 'REVENUE',
      value: '₱4.2K',
      subtitle: 'This week',
      iconCodePoint: 0xe8e5, // trending_up
      color: 0xFFF59E0B,
    ),
  ];
}

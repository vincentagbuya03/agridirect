/// Shared data layer — used by both mobile and web UIs.
/// Only data & logic lives here; no Flutter widgets.
library;

class ProductItem {
  final String? productId;
  final String? farmerId;
  final String? farmerName;
  final String? farmerAvatarUrl;
  final String? farmerImageUrl;
  final String name;
  final String farm;
  final String price;
  final String unit;
  final String imageUrl;
  final List<String> imageUrls;
  final String? categoryName;
  final String? rating;
  final String? reviews;
   final String? harvestDays;
  final String? description;
  final double? reservedQuantity;
  final double? targetQuantity;
  final double? stockQuantity;
  final double? latitude;
  final double? longitude;
  final bool isFeatured;
  final bool isPreorder;
  final DateTime? createdAt;

  const ProductItem({
    this.productId,
    this.farmerId,
    this.farmerName,
    this.farmerAvatarUrl,
    this.farmerImageUrl,
    required this.name,
    required this.farm,
    required this.price,
    required this.unit,
    required this.imageUrl,
    this.imageUrls = const [],
    this.categoryName,
    this.rating,
    this.reviews,
    this.harvestDays,
    this.description,
    this.reservedQuantity,
    this.targetQuantity,
    this.stockQuantity,
    this.latitude,
    this.longitude,
    this.isFeatured = false,
    this.isPreorder = false,
    this.createdAt,
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
  final String id;
  final String? userId;
  final String userName;
  final String time;
  final String title;
  final String body;
  final String? imageUrl;
  final String? videoUrl;
  final int likes;
  final int comments;
  final bool isLiked;
  final bool isPinned;
  final String? authorAvatarUrl;

  const ForumPostItem({
    required this.id,
    this.userId,
    required this.userName,
    required this.time,
    required this.title,
    required this.body,
    this.imageUrl,
    this.videoUrl,
    required this.likes,
    required this.comments,
    required this.isLiked,
    this.isPinned = false,
    this.authorAvatarUrl,
  });

  ForumPostItem copyWith({
    String? id,
    String? userId,
    String? userName,
    String? time,
    String? title,
    String? body,
    String? imageUrl,
    String? videoUrl,
    int? likes,
    int? comments,
    bool? isLiked,
    bool? isPinned,
    String? authorAvatarUrl,
  }) {
    return ForumPostItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      time: time ?? this.time,
      title: title ?? this.title,
      body: body ?? this.body,
      imageUrl: imageUrl ?? this.imageUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      isLiked: isLiked ?? this.isLiked,
      isPinned: isPinned ?? this.isPinned,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
    );
  }
}

class ArticleItem {
  final String? id;
  final String title;
  final String excerpt;
  final String? content;
  final List<String>? keyInsights;
  final String author;
  final String readTime;
  final String time;
  final String? imageUrl;
  final String? audience;

  const ArticleItem({
    this.id,
    required this.title,
    required this.excerpt,
    this.content,
    this.keyInsights,
    required this.author,
    required this.readTime,
    required this.time,
    this.imageUrl,
    this.audience,
  });

  /// Dynamically calculates the read time based on word count
  /// Average reading speed: 200 words per minute
  String get calculatedReadTime {
    final fullText = '$excerpt ${content ?? ''}';
    final words = fullText.split(RegExp(r'\s+')).length;
    final minutes = (words / 200).ceil();
    return '$minutes min read';
  }
}

class CartItem {
  final String farmerId;
  final String productId;
  final String name;
  final String farm;
  final String price;
  final String unit;
  final String imageUrl;
  int quantity;
  bool isSelected;

  CartItem({
    required this.farmerId,
    required this.productId,
    required this.name,
    required this.farm,
    required this.price,
    required this.unit,
    required this.imageUrl,
    this.quantity = 1,
    this.isSelected = true,
  });

  double get priceValue => double.tryParse(price.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
  double get total => priceValue * quantity;

  Map<String, dynamic> toJson() {
    return {
      'farmerId': farmerId,
      'productId': productId,
      'name': name,
      'farm': farm,
      'price': price,
      'unit': unit,
      'imageUrl': imageUrl,
      'quantity': quantity,
      'isSelected': isSelected,
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      farmerId: json['farmerId'] as String? ?? '',
      productId: json['productId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      farm: json['farm'] as String? ?? '',
      price: json['price'] as String? ?? '',
      unit: json['unit'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 1,
      isSelected: json['isSelected'] as bool? ?? true,
    );
  }
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
//  Constants shared across platforms
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
}

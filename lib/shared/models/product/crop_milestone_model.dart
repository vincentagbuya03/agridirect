// ============================================================================
// lib/shared/models/product/crop_milestone_model.dart
// Crop milestone data model
// ============================================================================

class CropMilestone {
  final String milestoneId;
  final String productId;
  final String title;
  final String description;
  final String? imageUrl;
  final DateTime createdAt;

  CropMilestone({
    required this.milestoneId,
    required this.productId,
    required this.title,
    required this.description,
    this.imageUrl,
    required this.createdAt,
  });

  factory CropMilestone.fromJson(Map<String, dynamic> json) {
    return CropMilestone(
      milestoneId: json['milestone_id'] as String? ?? '',
      productId: json['product_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'milestone_id': milestoneId,
      'product_id': productId,
      'title': title,
      'description': description,
      'image_url': imageUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }

  CropMilestone copyWith({
    String? milestoneId,
    String? productId,
    String? title,
    String? description,
    String? imageUrl,
    DateTime? createdAt,
  }) {
    return CropMilestone(
      milestoneId: milestoneId ?? this.milestoneId,
      productId: productId ?? this.productId,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

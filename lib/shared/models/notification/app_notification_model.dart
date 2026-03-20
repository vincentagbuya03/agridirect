import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';

part 'app_notification_model.g.dart';

@JsonSerializable()
class AppNotification {
  @JsonKey(name: 'notification_id')
  final String notificationId;
  @JsonKey(name: 'user_id')
  final String userId;
  final String type;
  final String title;
  final String message;
  @JsonKey(name: 'related_entity_id')
  final String? relatedEntityId;
  @JsonKey(name: 'related_entity_type')
  final String? relatedEntityType;
  @JsonKey(name: 'is_read')
  final bool isRead;
  @JsonKey(name: 'read_at')
  final DateTime? readAt;
  @JsonKey(name: 'action_url')
  final String? actionUrl;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  AppNotification({
    required this.notificationId,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.relatedEntityId,
    this.relatedEntityType,
    this.isRead = false,
    this.readAt,
    this.actionUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      _$AppNotificationFromJson(json);
  Map<String, dynamic> toJson() => _$AppNotificationToJson(this);

  @JsonKey(includeFromJson: false, includeToJson: false)
  IconData get icon {
    switch (type) {
      case 'order_created':
        return Icons.shopping_bag_outlined;
      case 'order_shipped':
        return Icons.local_shipping_outlined;
      case 'order_delivered':
        return Icons.check_circle_outline;
      case 'new_message':
        return Icons.chat_bubble_outline;
      case 'product_review':
      case 'farmer_review':
        return Icons.star_outline;
      case 'new_follower':
        return Icons.person_add_outlined;
      case 'farmer_approved':
        return Icons.verified_outlined;
      case 'farmer_rejected':
        return Icons.cancel_outlined;
      case 'product_added':
        return Icons.add_box_outlined;
      case 'system_alert':
        return Icons.info_outline;
      default:
        return Icons.notifications_outlined;
    }
  }

  AppNotification copyWith({
    String? notificationId,
    String? userId,
    String? type,
    String? title,
    String? message,
    String? relatedEntityId,
    String? relatedEntityType,
    bool? isRead,
    DateTime? readAt,
    String? actionUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppNotification(
      notificationId: notificationId ?? this.notificationId,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      relatedEntityId: relatedEntityId ?? this.relatedEntityId,
      relatedEntityType: relatedEntityType ?? this.relatedEntityType,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      actionUrl: actionUrl ?? this.actionUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

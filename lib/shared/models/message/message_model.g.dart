// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Message _$MessageFromJson(Map<String, dynamic> json) => Message(
  messageId: json['message_id'] as String,
  conversationId: json['conversation_id'] as String,
  senderId: json['sender_id'] as String,
  recipientId: json['recipient_id'] as String,
  content: json['content'] as String,
  imageUrl: json['image_url'] as String?,
  isRead: json['is_read'] as bool? ?? false,
  readAt: json['read_at'] == null
      ? null
      : DateTime.parse(json['read_at'] as String),
  createdAt: DateTime.parse(json['created_at'] as String),
  updatedAt: DateTime.parse(json['updated_at'] as String),
  senderName: json['sender_name'] as String?,
  senderAvatar: json['sender_avatar'] as String?,
);

Map<String, dynamic> _$MessageToJson(Message instance) => <String, dynamic>{
  'message_id': instance.messageId,
  'conversation_id': instance.conversationId,
  'sender_id': instance.senderId,
  'recipient_id': instance.recipientId,
  'content': instance.content,
  'image_url': instance.imageUrl,
  'is_read': instance.isRead,
  'read_at': instance.readAt?.toIso8601String(),
  'created_at': instance.createdAt.toIso8601String(),
  'updated_at': instance.updatedAt.toIso8601String(),
  'sender_name': instance.senderName,
  'sender_avatar': instance.senderAvatar,
};

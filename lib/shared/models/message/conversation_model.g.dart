// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Conversation _$ConversationFromJson(Map<String, dynamic> json) => Conversation(
  conversationId: json['conversation_id'] as String,
  participant1Id: json['participant_1_id'] as String,
  participant2Id: json['participant_2_id'] as String,
  orderId: json['order_id'] as String?,
  lastMessageId: json['last_message_id'] as String?,
  createdAt: DateTime.parse(json['created_at'] as String),
  updatedAt: DateTime.parse(json['updated_at'] as String),
  participant1Name: json['participant_1_name'] as String?,
  participant1Avatar: json['participant_1_avatar'] as String?,
  participant2Name: json['participant_2_name'] as String?,
  participant2Avatar: json['participant_2_avatar'] as String?,
  lastMessageContent: json['last_message_content'] as String?,
  lastMessageAt: json['last_message_at'] == null
      ? null
      : DateTime.parse(json['last_message_at'] as String),
  lastMessageSenderId: json['last_message_sender_id'] as String?,
);

Map<String, dynamic> _$ConversationToJson(Conversation instance) =>
    <String, dynamic>{
      'conversation_id': instance.conversationId,
      'participant_1_id': instance.participant1Id,
      'participant_2_id': instance.participant2Id,
      'order_id': instance.orderId,
      'last_message_id': instance.lastMessageId,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
      'participant_1_name': instance.participant1Name,
      'participant_1_avatar': instance.participant1Avatar,
      'participant_2_name': instance.participant2Name,
      'participant_2_avatar': instance.participant2Avatar,
      'last_message_content': instance.lastMessageContent,
      'last_message_at': instance.lastMessageAt?.toIso8601String(),
      'last_message_sender_id': instance.lastMessageSenderId,
    };

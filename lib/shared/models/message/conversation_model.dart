import 'package:json_annotation/json_annotation.dart';

part 'conversation_model.g.dart';

@JsonSerializable()
class Conversation {
  @JsonKey(name: 'conversation_id')
  final String conversationId;
  @JsonKey(name: 'participant_1_id')
  final String participant1Id;
  @JsonKey(name: 'participant_2_id')
  final String participant2Id;
  @JsonKey(name: 'order_id')
  final String? orderId;
  @JsonKey(name: 'last_message_id')
  final String? lastMessageId;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  // View fields
  @JsonKey(name: 'participant_1_name')
  final String? participant1Name;
  @JsonKey(name: 'participant_1_avatar')
  final String? participant1Avatar;
  @JsonKey(name: 'participant_2_name')
  final String? participant2Name;
  @JsonKey(name: 'participant_2_avatar')
  final String? participant2Avatar;
  @JsonKey(name: 'last_message_content')
  final String? lastMessageContent;
  @JsonKey(name: 'last_message_at')
  final DateTime? lastMessageAt;
  @JsonKey(name: 'last_message_sender_id')
  final String? lastMessageSenderId;

  Conversation({
    required this.conversationId,
    required this.participant1Id,
    required this.participant2Id,
    this.orderId,
    this.lastMessageId,
    required this.createdAt,
    required this.updatedAt,
    this.participant1Name,
    this.participant1Avatar,
    this.participant2Name,
    this.participant2Avatar,
    this.lastMessageContent,
    this.lastMessageAt,
    this.lastMessageSenderId,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) =>
      _$ConversationFromJson(json);
  Map<String, dynamic> toJson() => _$ConversationToJson(this);

  String getOtherParticipantName(String currentUserId) {
    return currentUserId == participant1Id
        ? (participant2Name ?? 'Unknown')
        : (participant1Name ?? 'Unknown');
  }

  String? getOtherParticipantAvatar(String currentUserId) {
    return currentUserId == participant1Id
        ? participant2Avatar
        : participant1Avatar;
  }

  String getOtherParticipantId(String currentUserId) {
    return currentUserId == participant1Id ? participant2Id : participant1Id;
  }

  Conversation copyWith({
    String? conversationId,
    String? participant1Id,
    String? participant2Id,
    String? orderId,
    String? lastMessageId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? participant1Name,
    String? participant1Avatar,
    String? participant2Name,
    String? participant2Avatar,
    String? lastMessageContent,
    DateTime? lastMessageAt,
    String? lastMessageSenderId,
  }) {
    return Conversation(
      conversationId: conversationId ?? this.conversationId,
      participant1Id: participant1Id ?? this.participant1Id,
      participant2Id: participant2Id ?? this.participant2Id,
      orderId: orderId ?? this.orderId,
      lastMessageId: lastMessageId ?? this.lastMessageId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      participant1Name: participant1Name ?? this.participant1Name,
      participant1Avatar: participant1Avatar ?? this.participant1Avatar,
      participant2Name: participant2Name ?? this.participant2Name,
      participant2Avatar: participant2Avatar ?? this.participant2Avatar,
      lastMessageContent: lastMessageContent ?? this.lastMessageContent,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
    );
  }
}

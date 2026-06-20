import 'package:flutter/material.dart';
import 'package:agridirect/shared/services/auth/auth_service.dart';
import '../../data/app_data.dart';

import 'farmer_messages_screen.dart';
import 'consumer_messages_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({
    super.key,
    this.initialFarmerId,
    this.initialConversationId,
    this.asFarmer,
    this.initialProduct,
    this.initialCustomerId,
  });

  final String? initialFarmerId;
  final String? initialCustomerId;
  final String? initialConversationId;
  final bool? asFarmer;
  final ProductItem? initialProduct;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _auth = AuthService();
  late bool _asFarmerInbox;

  @override
  void initState() {
    super.initState();
    _asFarmerInbox =
        widget.asFarmer ??
        (widget.initialFarmerId == null ? _auth.isViewingAsFarmer : false);
  }

  @override
  Widget build(BuildContext context) {
    if (_asFarmerInbox) {
      return FarmerMessagesScreen(
        initialConversationId: widget.initialConversationId,
        initialCustomerId: widget.initialCustomerId,
      );
    } else {
      return ConsumerMessagesScreen(
        initialFarmerId: widget.initialFarmerId,
        initialConversationId: widget.initialConversationId,
        initialProduct: widget.initialProduct,
      );
    }
  }
}

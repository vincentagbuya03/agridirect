/// Stub implementation of [evalJs] for non-web platforms.
void evalJs(String code) {
  // No-op on mobile/native platforms.
}

/// Stub implementation of [registerNotificationCallback] for non-web platforms.
void registerNotificationCallback(void Function(String linkType, String linkId) callback) {
  // No-op on mobile/native platforms.
}

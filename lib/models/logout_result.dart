class LogoutResult {
  const LogoutResult({
    required this.backendRevoked,
    this.errorMessage,
  });

  final bool backendRevoked;
  final String? errorMessage;

  bool get hasBackendError => errorMessage != null && errorMessage!.isNotEmpty;
}

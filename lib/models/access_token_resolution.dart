/// Result of resolving the bearer token used for authenticated API calls.
class AccessTokenResolution {
  const AccessTokenResolution({
    this.token,
    this.source,
    this.failureStage,
    this.failureLocation,
  });

  final String? token;
  final String? source;
  final String? failureStage;
  final String? failureLocation;

  bool get isResolved => token != null && token!.isNotEmpty;

  int get tokenLength => token?.length ?? 0;
}

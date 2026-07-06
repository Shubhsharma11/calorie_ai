class OnboardingResponseModel {
  const OnboardingResponseModel({
    this.message,
    this.success = true,
    this.raw,
  });

  final String? message;
  final bool success;
  final Map<String, dynamic>? raw;

  factory OnboardingResponseModel.fromJson(Map<String, dynamic> json) {
    return OnboardingResponseModel(
      message: json['message'] as String?,
      success: json['success'] as bool? ?? true,
      raw: json,
    );
  }
}

import '../models/onboarding_request_model.dart';
import '../models/onboarding_response_model.dart';
import '../services/onboarding_api_service.dart';

class OnboardingRepository {
  OnboardingRepository({OnboardingApiService? apiService})
    : _apiService = apiService ?? OnboardingApiService();

  final OnboardingApiService _apiService;

  Future<OnboardingResponseModel> submitOnboarding({
    required String accessToken,
    required OnboardingRequestModel request,  
  }) async {
    try {
      return await _apiService.submitOnboarding(
        accessToken: accessToken,
        request: request,
      );
    } on OnboardingApiException {
      rethrow;
    } catch (error) {
      throw OnboardingApiException(
        'Network error during onboarding: $error',
      );
    }
  }

  Future<OnboardingResponseModel> patchOnboarding({
    required String accessToken,
    required Map<String, dynamic> payload,
  }) async {
    try {
      return await _apiService.patchOnboarding(
        accessToken: accessToken,
        payload: payload,
      );
    } on OnboardingApiException {
      rethrow;
    } catch (error) {
      throw OnboardingApiException(
        'Network error during onboarding update: $error',
      );
    }
  }

  Future<OnboardingResponseModel> fetchOnboarding({
    required String accessToken,
  }) async {
    try {
      return await _apiService.fetchOnboarding(accessToken: accessToken);
    } on OnboardingApiException {
      rethrow;
    } catch (error) {
      throw OnboardingApiException(
        'Network error while loading onboarding profile: $error',
      );
    }
  }
}

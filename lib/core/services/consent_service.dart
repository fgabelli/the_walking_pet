
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class ConsentService {
  /// Request consent info update, show form if needed, and wait for completion.
  /// Returns a Future that completes only after the entire UMP flow is done.
  Future<void> requestConsent() async {
    final completer = Completer<void>();
    final params = ConsentRequestParameters();

    // For testing:
    // ConsentDebugSettings debugSettings = ConsentDebugSettings(
    //   debugGeography: DebugGeography.debugGeographyEea,
    //   testIdentifiers: ['YOUR-TEST-DEVICE-HASHED-ID'],
    // );
    // params = ConsentRequestParameters(consentDebugSettings: debugSettings);

    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () async {
          // The consent information state was updated.
          if (await ConsentInformation.instance.isConsentFormAvailable()) {
            await _loadAndShowConsentForm();
          }
          if (!completer.isCompleted) completer.complete();
        },
        (FormError error) {
          debugPrint('Consent info update failed: ${error.message}');
          if (!completer.isCompleted) completer.complete();
        },
      );
    } catch (e) {
      debugPrint('Error requesting consent info: $e');
      if (!completer.isCompleted) completer.complete();
    }

    return completer.future;
  }

  /// Loads and shows the consent form, returning a Future that completes
  /// when the form is dismissed.
  Future<void> _loadAndShowConsentForm() async {
    final completer = Completer<void>();

    try {
      ConsentForm.loadConsentForm(
        (ConsentForm consentForm) async {
          final status = await ConsentInformation.instance.getConsentStatus();
          if (status == ConsentStatus.required) {
            consentForm.show(
              (FormError? formError) {
                if (formError != null) {
                  debugPrint('Consent form error: ${formError.message}');
                }
                if (!completer.isCompleted) completer.complete();
              },
            );
          } else {
            if (!completer.isCompleted) completer.complete();
          }
        },
        (formError) {
          debugPrint('Failed to load consent form: ${formError.message}');
          if (!completer.isCompleted) completer.complete();
        },
      );
    } catch (e) {
      debugPrint('Error loading consent form: $e');
      if (!completer.isCompleted) completer.complete();
    }

    return completer.future;
  }
}

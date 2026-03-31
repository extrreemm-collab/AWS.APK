import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'api.dart';

class GoogleIdentity {
  const GoogleIdentity({required this.email, required this.idToken});

  final String email;
  final String idToken;
}

class GoogleAuthException implements Exception {
  const GoogleAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class GoogleAuthClient {
  Future<GoogleIdentity?> signIn();

  Future<void> signOut();
}

class GoogleSignInAuthClient implements GoogleAuthClient {
  GoogleSignInAuthClient({
    GoogleSignIn? googleSignIn,
    String? clientId,
    String? serverClientId,
    String? hostedDomain,
  }) : _googleSignIn = googleSignIn ?? GoogleSignIn.instance,
       _clientId = _normalize(clientId),
       _serverClientId = _normalize(serverClientId),
       _hostedDomain = _normalize(hostedDomain);

  factory GoogleSignInAuthClient.fromEnvironment() {
    return GoogleSignInAuthClient(
      clientId: _normalize(
        const String.fromEnvironment('AMS_GOOGLE_WEB_CLIENT_ID'),
      ),
      serverClientId: const String.fromEnvironment(
        'AMS_GOOGLE_SERVER_CLIENT_ID',
      ),
      hostedDomain: const String.fromEnvironment('AMS_GOOGLE_HOSTED_DOMAIN'),
    );
  }

  static Future<GoogleSignInAuthClient> buildFromEnvironment({
    AmsApi? api,
  }) async {
    final envClientId = _normalize(
      const String.fromEnvironment('AMS_GOOGLE_WEB_CLIENT_ID'),
    );
    final envServerClientId = _normalize(
      const String.fromEnvironment('AMS_GOOGLE_SERVER_CLIENT_ID'),
    );
    final hostedDomain = _normalize(
      const String.fromEnvironment('AMS_GOOGLE_HOSTED_DOMAIN'),
    );

    final clientId = kIsWeb
        ? await _resolveWebClientId(
            api: api,
            envClientId: envClientId,
            envServerClientId: envServerClientId,
          )
        : envClientId;

    return GoogleSignInAuthClient(
      clientId: clientId,
      serverClientId: envServerClientId,
      hostedDomain: hostedDomain,
    );
  }

  final GoogleSignIn _googleSignIn;
  final String? _clientId;
  final String? _serverClientId;
  final String? _hostedDomain;
  bool _initialized = false;

  static String? _normalize(String? value) {
    if (value == null) {
      return null;
    }

    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static Future<String?> _resolveWebClientId({
    AmsApi? api,
    String? envClientId,
    String? envServerClientId,
  }) async {
    if (api != null) {
      try {
        final runtimeClientId = _normalize(await api.fetchGoogleClientId());
        if (runtimeClientId != null) {
          debugPrint(
            'AMS Google web sign-in loaded the client ID from the backend.',
          );
          return runtimeClientId;
        }
      } on ApiException catch (error) {
        debugPrint(
          'AMS Google web sign-in could not load the client ID from the '
          'backend: ${error.message}',
        );
      } catch (error) {
        debugPrint(
          'AMS Google web sign-in could not load the client ID from the '
          'backend: $error',
        );
      }
    }

    return envClientId ?? envServerClientId;
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) {
      return;
    }

    if (kIsWeb) {
      final clientId = _clientId ?? _serverClientId;
      if (clientId == null) {
        throw const GoogleAuthException(
          'Google Sign-In for web is missing a client ID. Run Flutter with '
          '--dart-define=AMS_GOOGLE_WEB_CLIENT_ID=YOUR_GOOGLE_WEB_CLIENT_ID.',
        );
      }

      debugPrint(
        'AMS Google web sign-in initializing with clientId=$clientId '
        '(envClientId=${_clientId ?? '(null)'}, '
        'fallbackServerClientId=${_serverClientId ?? '(null)'})',
      );

      await _googleSignIn.initialize(
        clientId: clientId,
        hostedDomain: _hostedDomain,
      );
    } else {
      await _googleSignIn.initialize(
        serverClientId: _serverClientId,
        hostedDomain: _hostedDomain,
      );
    }
    _initialized = true;
  }

  Future<void> ensureInitialized() => _ensureInitialized();

  Stream<GoogleSignInAuthenticationEvent> get authenticationEvents =>
      _googleSignIn.authenticationEvents;

  @override
  Future<GoogleIdentity?> signIn() async {
    await _ensureInitialized();

    if (kIsWeb) {
      throw const GoogleAuthException(
        'Flutter web must use the Google web sign-in button.',
      );
    }

    try {
      final account = await _googleSignIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.trim().isEmpty) {
        throw const GoogleAuthException(
          'Google Sign-In did not return a usable ID token.',
        );
      }

      return GoogleIdentity(email: account.email, idToken: idToken);
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled ||
          error.code == GoogleSignInExceptionCode.interrupted) {
        return null;
      }

      throw GoogleAuthException(_messageForException(error));
    } on UnsupportedError {
      throw const GoogleAuthException(
        'Google Sign-In is not supported on this platform configuration.',
      );
    }
  }

  @override
  Future<void> signOut() async {
    if (!_initialized) {
      return;
    }

    await _googleSignIn.signOut();
  }

  String _messageForException(GoogleSignInException error) {
    return switch (error.code) {
      GoogleSignInExceptionCode.clientConfigurationError =>
        'Google Sign-In is not configured correctly for this app.',
      GoogleSignInExceptionCode.providerConfigurationError =>
        'Google services are not configured correctly on this device.',
      GoogleSignInExceptionCode.uiUnavailable =>
        'Google Sign-In is not available right now on this device.',
      GoogleSignInExceptionCode.userMismatch =>
        'Please sign in with the Google account assigned to your college profile.',
      _ =>
        error.description?.trim().isNotEmpty == true
            ? error.description!.trim()
            : 'Google Sign-In could not be completed.',
    };
  }

  String messageForException(GoogleSignInException error) =>
      _messageForException(error);
}

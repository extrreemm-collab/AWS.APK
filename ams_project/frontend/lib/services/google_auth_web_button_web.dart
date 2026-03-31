import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart'
    show
        GoogleSignInAuthenticationEvent,
        GoogleSignInAuthenticationEventSignIn,
        GoogleSignInException;
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:google_sign_in_web/google_sign_in_web.dart';

import 'google_auth.dart';

class GoogleWebSignInButton extends StatefulWidget {
  const GoogleWebSignInButton({
    super.key,
    required this.client,
    required this.onIdentity,
    required this.onError,
  });

  final GoogleSignInAuthClient client;
  final Future<void> Function(GoogleIdentity identity) onIdentity;
  final ValueChanged<String> onError;

  @override
  State<GoogleWebSignInButton> createState() => _GoogleWebSignInButtonState();
}

class _GoogleWebSignInButtonState extends State<GoogleWebSignInButton> {
  StreamSubscription<GoogleSignInAuthenticationEvent>? _subscription;
  Object? _initializationError;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await widget.client.ensureInitialized();
      _subscription = widget.client.authenticationEvents.listen(
        _handleEvent,
        onError: _handleStreamError,
      );
      if (mounted) {
        setState(() {});
      }
    } catch (error) {
      _initializationError = error;
      if (mounted) {
        setState(() {});
      }
      widget.onError(_stringifyError(error));
    }
  }

  void _handleEvent(GoogleSignInAuthenticationEvent event) {
    if (event is! GoogleSignInAuthenticationEventSignIn) {
      return;
    }

    final idToken = event.user.authentication.idToken;
    if (idToken == null || idToken.trim().isEmpty) {
      widget.onError('Google Sign-In did not return a usable ID token.');
      return;
    }

    unawaited(
      widget.onIdentity(
        GoogleIdentity(email: event.user.email, idToken: idToken),
      ),
    );
  }

  void _handleStreamError(Object error) {
    if (error is GoogleSignInException) {
      widget.onError(widget.client.messageForException(error));
      return;
    }

    widget.onError(_stringifyError(error));
  }

  String _stringifyError(Object error) {
    final message = error.toString().trim();
    if (message.isEmpty) {
      return 'Google Sign-In could not be started.';
    }
    return message;
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initializationError != null) {
      return const SizedBox.shrink();
    }

    final platform = GoogleSignInPlatform.instance;
    if (platform is! GoogleSignInPlugin) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: platform.renderButton(
        configuration: GSIButtonConfiguration(
          theme: GSIButtonTheme.outline,
          text: GSIButtonText.continueWith,
          size: GSIButtonSize.large,
          shape: GSIButtonShape.pill,
          minimumWidth: 320,
        ),
      ),
    );
  }
}

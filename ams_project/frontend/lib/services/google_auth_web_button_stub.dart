import 'package:flutter/material.dart';

import 'google_auth.dart';

class GoogleWebSignInButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

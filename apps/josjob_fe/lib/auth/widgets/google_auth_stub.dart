import 'package:flutter/material.dart';

/// Google renders its own sign-in button on the web. Other platforms keep the
/// email/password form usable without importing browser-only libraries.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({super.key, required this.onIdToken, this.onError});

  final Future<void> Function(String idToken) onIdToken;
  final void Function(Object error)? onError;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

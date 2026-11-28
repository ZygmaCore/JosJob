import 'package:flutter/material.dart';
import '../services/ui_preferences.dart';

String? learningReturnPath(String? value) {
  final safe = AuthContinuation.validate(value);
  if (safe == null) return null;
  final root = Uri.parse(safe).pathSegments.first;
  return {'jobs', 'applications', 'dashboard', 'explore'}.contains(root)
      ? safe
      : null;
}

String learningReturnLabel(String? value) {
  final uri = value == null ? null : Uri.tryParse(value);
  if (uri?.pathSegments.firstOrNull == 'jobs') {
    return uri!.queryParameters['apply'] == '1'
        ? 'Back to application'
        : 'Back to job';
  }
  if (uri?.pathSegments.firstOrNull == 'applications') {
    return 'Back to application';
  }
  return 'Back to learning';
}

void returnFromLearning(BuildContext context, String destination) {
  var found = false;
  final navigator = Navigator.of(context);
  navigator.popUntil((route) {
    if (route.settings.name == destination) {
      found = true;
      return true;
    }
    return route.isFirst;
  });
  if (!found) navigator.pushReplacementNamed(destination);
}

part of '../dashboard_page.dart';

class _JobApplicationsScreen extends StatelessWidget {
  final bool hiring;
  final String initialStatus;
  final void Function(String, String)? onLocationChanged;
  const _JobApplicationsScreen({
    this.hiring = false,
    this.initialStatus = '',
    this.onLocationChanged,
  });
  @override
  Widget build(BuildContext context) => ApplicationsView(
    hiring: hiring,
    initialStatus: initialStatus,
    onLocationChanged: onLocationChanged,
  );
}

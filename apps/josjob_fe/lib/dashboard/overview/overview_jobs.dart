part of '../dashboard_page.dart';

class _OverviewJobs extends StatelessWidget {
  final String? firstName;
  final VoidCallback onBrowseJobs;
  const _OverviewJobs({required this.firstName, required this.onBrowseJobs});
  @override
  Widget build(BuildContext context) =>
      JobsOverviewView(firstName: firstName, onBrowseJobs: onBrowseJobs);
}

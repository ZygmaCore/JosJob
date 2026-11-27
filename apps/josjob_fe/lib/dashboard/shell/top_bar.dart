part of '../dashboard_page.dart';

class _TopBar extends StatelessWidget {
  final String title;
  final bool mobile;
  final VoidCallback? onMenu;
  final bool showDocuments;
  const _TopBar({
    required this.title,
    required this.mobile,
    this.onMenu,
    this.showDocuments = true,
  });
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    child: SafeArea(
      bottom: false,
      child: SizedBox(
        height: 64,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: mobile ? 8 : 24),
          child: Row(
            children: [
              if (mobile)
                IconButton(
                  onPressed: onMenu,
                  tooltip: 'Open menu',
                  icon: const Icon(Icons.menu),
                ),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (mobile)
                IconButton(
                  key: const ValueKey('ask-ai-open'),
                  tooltip: 'Ask AI',
                  onPressed: () => showAskAi(context),
                  icon: const Icon(Icons.auto_awesome_rounded),
                )
              else
                FilledButton.icon(
                  key: const ValueKey('ask-ai-open'),
                  onPressed: () => showAskAi(context),
                  icon: const Icon(Icons.auto_awesome_rounded, size: 17),
                  label: const Text('Ask AI'),
                ),
              if (showDocuments)
                IconButton(
                  onPressed: () => _documents(context),
                  tooltip: 'Documents',
                  icon: const Icon(Icons.folder_shared_outlined),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

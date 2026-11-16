part of '../landing_page_ascent.dart';

class _Sent extends StatelessWidget {
  final String email;
  const _Sent({required this.email});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white54),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: Colors.white),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              "Thanks! We'll be in touch at $email to get you started.",
              style: TextStyle(
                fontFamily: 'General Sans',
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

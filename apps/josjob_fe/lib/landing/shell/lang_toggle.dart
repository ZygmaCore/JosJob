part of '../landing_page_ascent.dart';

class _LangToggle extends StatefulWidget {
  const _LangToggle();
  @override
  State<_LangToggle> createState() => _LangToggleState();
}

class _LangToggleState extends State<_LangToggle> {
  bool _en = true;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _seg('ID', !_en, () => setState(() => _en = false)),
          _seg('EN', _en, () => setState(() => _en = true)),
        ],
      ),
    );
  }

  Widget _seg(String label, bool active, VoidCallback onTap) => Semantics(
    button: true,
    selected: active,
    label: 'Switch to $label',
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: active ? AppColors.brandBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'General Sans',
            fontSize: 13,
            fontWeight: active ? FontWeight.w700 : FontWeight.w600,
            color: active ? Colors.white : AppColors.body,
          ),
        ),
      ),
    ),
  );
}

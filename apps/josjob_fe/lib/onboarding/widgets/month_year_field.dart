part of '../onboarding_page.dart';

// A month + year picker built from two dropdowns. Emits a [_MonthYear] once
// both are chosen, or null while either is empty.
class _MonthYearField extends StatefulWidget {
  final String label;
  final _MonthYear? value;
  final ValueChanged<_MonthYear?> onChanged;
  const _MonthYearField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_MonthYearField> createState() => _MonthYearFieldState();
}

class _MonthYearFieldState extends State<_MonthYearField> {
  int? _m;
  int? _y;

  @override
  void initState() {
    super.initState();
    _m = widget.value?.month;
    _y = widget.value?.year;
  }

  void _emit() {
    final m = _m, y = _y;
    widget.onChanged(m != null && y != null ? _MonthYear(m, y) : null);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: GoogleFonts.poppins(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: _m,
                isExpanded: true,
                icon: const Icon(Icons.expand_more, color: AppColors.body),
                style: GoogleFonts.poppins(fontSize: 15, color: AppColors.ink),
                hint: Text(
                  'Month',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: AppColors.body,
                  ),
                ),
                decoration: _decoration(),
                items: [
                  for (var i = 1; i <= 12; i++)
                    DropdownMenuItem(value: i, child: Text(_months[i - 1])),
                ],
                onChanged: (v) => setState(() {
                  _m = v;
                  _emit();
                }),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: _y,
                isExpanded: true,
                icon: const Icon(Icons.expand_more, color: AppColors.body),
                style: GoogleFonts.poppins(fontSize: 15, color: AppColors.ink),
                hint: Text(
                  'Year',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: AppColors.body,
                  ),
                ),
                decoration: _decoration(),
                items: [
                  for (final y in _years)
                    DropdownMenuItem(value: y, child: Text('$y')),
                ],
                onChanged: (v) => setState(() {
                  _y = v;
                  _emit();
                }),
              ),
            ),
          ],
        ),
      ],
    );
  }

  InputDecoration _decoration() => InputDecoration(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: _border(AppColors.border),
    enabledBorder: _border(AppColors.border),
    focusedBorder: _border(AppColors.brandBlue, width: 1.6),
  );

  OutlineInputBorder _border(Color color, {double width = 1.2}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );
}

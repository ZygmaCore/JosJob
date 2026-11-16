part of '../onboarding_page.dart';

// Phone number input with a country dial-code selector. The compact leading
// button shows the selected E.164 code (e.g. "+62") and opens a searchable
// country picker (backed by [MasterData] dial codes); the field to its right
// takes the local number. Scales to all ~249 dial codes via search rather than
// a long dropdown.
class _PhoneField extends StatelessWidget {
  final String label;
  final String? dialCode;
  final TextEditingController controller;
  final ValueChanged<String> onDialCode;
  const _PhoneField({
    required this.label,
    required this.dialCode,
    required this.controller,
    required this.onDialCode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            _DialButton(
              dialCode: dialCode,
              onTap: () async {
                final picked = await _pickCountryDial(context);
                if (picked != null) onDialCode(picked.dial);
              },
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: controller,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                style: GoogleFonts.poppins(fontSize: 15, color: AppColors.ink),
                cursorColor: AppColors.brandBlue,
                decoration: InputDecoration(
                  hintText: '812 3456 7890',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 15,
                    color: AppColors.body,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  border: _phoneBorder(AppColors.border),
                  enabledBorder: _phoneBorder(AppColors.border),
                  focusedBorder: _phoneBorder(AppColors.brandBlue, width: 1.6),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

OutlineInputBorder _phoneBorder(Color color, {double width = 1.2}) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: width),
    );

class _DialButton extends StatelessWidget {
  final String? dialCode;
  final VoidCallback onTap;
  const _DialButton({required this.dialCode, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final has = dialCode != null && dialCode!.isNotEmpty;
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border, width: 1.2),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          // Vertical padding matches the number field's contentPadding so the
          // two align without CrossAxisAlignment.stretch (which would force an
          // infinite height inside the scrolling step).
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                has ? dialCode! : '+XX',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: has ? AppColors.ink : AppColors.body,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more, size: 20, color: AppColors.body),
            ],
          ),
        ),
      ),
    );
  }
}

// Searchable bottom sheet of country dial codes. Returns the picked (name, dial)
// or null if dismissed.
Future<({String name, String dial})?> _pickCountryDial(BuildContext context) {
  return showModalBottomSheet<({String name, String dial})>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _CountryDialSheet(),
  );
}

class _CountryDialSheet extends StatefulWidget {
  const _CountryDialSheet();

  @override
  State<_CountryDialSheet> createState() => _CountryDialSheetState();
}

class _CountryDialSheetState extends State<_CountryDialSheet> {
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = MasterData.instance.phoneCountries;
    final query = _q.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? all
        : all
              .where(
                (o) =>
                    o.name.toLowerCase().contains(query) ||
                    o.dial.contains(query),
              )
              .toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Select country code',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _q,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                style: GoogleFonts.poppins(fontSize: 15, color: AppColors.ink),
                cursorColor: AppColors.brandBlue,
                decoration: InputDecoration(
                  hintText: 'Search country or code',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 15,
                    color: AppColors.body,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 20,
                    color: AppColors.body,
                  ),
                  filled: true,
                  fillColor: AppColors.bg,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: _phoneBorder(AppColors.border),
                  enabledBorder: _phoneBorder(AppColors.border),
                  focusedBorder: _phoneBorder(AppColors.brandBlue, width: 1.6),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No matches',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: AppColors.body,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final o = filtered[i];
                        return InkWell(
                          onTap: () => Navigator.of(context).pop(o),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    o.name,
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  o.dial,
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.brandBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

part of '../landing_page_ascent.dart';

class _EnquiryForm extends StatelessWidget {
  final TextEditingController controller;
  final String? error;
  final VoidCallback onSubmit;
  final bool mobile;
  const _EnquiryForm({
    required this.controller,
    required this.error,
    required this.onSubmit,
    required this.mobile,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Column(
        children: [
          Flex(
            direction: mobile ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: mobile ? 0 : 1,
                child: SizedBox(
                  width: mobile ? double.infinity : null,
                  child: TextField(
                    controller: controller,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => onSubmit(),
                    style: GoogleFonts.poppins(
                      color: AppColors.ink,
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Your email',
                      hintText: 'you@email.com',
                      filled: true,
                      fillColor: Colors.white,
                      errorText: error,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(100),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(100),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(100),
                        borderSide: const BorderSide(
                          color: AppColors.navy,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: mobile ? 0 : 12, height: mobile ? 12 : 0),
              _PillButton(
                'Get started',
                kind: _BtnKind.white,
                trailing: Icons.arrow_forward,
                onPressed: onSubmit,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'We\'ll only use this to help you get started.',
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

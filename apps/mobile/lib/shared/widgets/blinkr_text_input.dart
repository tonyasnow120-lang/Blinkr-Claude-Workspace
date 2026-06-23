import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Dark recessed input. Surface-inset fill, 2px border that turns acid on
/// focus, sharp 2px corners. Value is Share Tech Mono; placeholder is Barlow
/// Condensed in ink-30.
class BlinkrTextInput extends StatefulWidget {
  final TextEditingController? controller;
  final String? hintText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool autofocus;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const BlinkrTextInput({
    super.key,
    this.controller,
    this.hintText,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autofocus = false,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  State<BlinkrTextInput> createState() => _BlinkrTextInputState();
}

class _BlinkrTextInputState extends State<BlinkrTextInput> {
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceInsetDark,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: focused ? AppColors.acid : AppColors.borderDefault,
          width: 2,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: TextField(
        controller: widget.controller,
        focusNode: _focus,
        autofocus: widget.autofocus,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        textCapitalization: widget.textCapitalization,
        inputFormatters: widget.inputFormatters,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        cursorColor: AppColors.acid,
        style: AppText.mono(size: 16, color: AppColors.chalk),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          border: InputBorder.none,
          hintText: widget.hintText,
          hintStyle: AppText.label(
            size: 14,
            weight: FontWeight.w500,
            color: AppColors.chalkInk(0.30),
          ),
        ),
      ),
    );
  }
}

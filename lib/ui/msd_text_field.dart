import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Arabic-friendly text field (RTL typing + Tajawal-friendly input).
class MsdTextField extends StatelessWidget {
  const MsdTextField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.prefixIcon,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.maxLines = 1,
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
    this.enabled = true,
    this.forceLtr = false,
    this.inputFormatters,
  });

  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final Widget? prefixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onEditingComplete;
  final bool enabled;
  final bool forceLtr;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    final rtl = !forceLtr;
    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      textAlign: rtl ? TextAlign.right : TextAlign.left,
      style: const TextStyle(
        fontFamily: 'Tajawal',
        fontSize: 16,
        height: 1.35,
      ),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: prefixIcon,
        alignLabelWithHint: true,
      ),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      onEditingComplete: onEditingComplete,
    );
  }
}

import 'package:flutter/material.dart';

class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final bool obscureText;
  final bool enabled;
  final TextInputType keyboardType;
  final Widget? suffixIcon;
  final TextInputAction textInputAction;
  final void Function(String)? onFieldSubmitted;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.obscureText = false,
    this.enabled = true,
    this.keyboardType = TextInputType.text,
    this.suffixIcon,
    this.textInputAction = TextInputAction.next,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      enabled: enabled,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      // Border and fill come from the app's inputDecorationTheme so the field
      // follows the active brightness instead of forcing a white background.
      decoration: InputDecoration(labelText: label, suffixIcon: suffixIcon),
    );
  }
}

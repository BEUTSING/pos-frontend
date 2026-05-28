// ─────────────────────────────────────────────────────────────────────────────
// FILE: widgets.dart
// PURPOSE: Reusable UI components shared across all pages
//
// Instead of rebuilding the same button or text field in every page,
// we define them once here and import them wherever needed.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'constants.dart'; // colors and other app-wide constants

// ─────────────────────────────────────────────────────────────────────────────
// StatCard — dashboard KPI card (total sales, profit, etc.)
//
// Example usage:
//   StatCard(
//     title: 'Total Sales',
//     value: '150,000 FCFA',
//     icon: Icons.trending_up,
//     color: kSuccessColor,
//   )
// ─────────────────────────────────────────────────────────────────────────────
class StatCard extends StatelessWidget {
  final String title;    // label above the value (e.g. "Total Sales")
  final String value;    // main number or amount (e.g. "150,000 FCFA")
  final IconData icon;   // icon shown in the top-right corner
  final Color color;     // accent color for the icon background
  final String? subtitle; // optional small text below the value

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Title text (small, secondary color)
              Text(title,
                  style: const TextStyle(
                      color: kTextSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
              // Icon in a colored rounded square
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12), // light tinted background
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Main value (large bold text)
          Text(value,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: kTextPrimary)),
          // Optional subtitle (small text, secondary color)
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!,
                style: const TextStyle(
                    color: kTextSecondary, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PrimaryButton — main green action button with loading state
//
// Example usage:
//   PrimaryButton(
//     label: 'Save',
//     onPressed: _save,
//     isLoading: _saving,   // shows a spinner instead of text when true
//     icon: Icons.save,
//   )
// ─────────────────────────────────────────────────────────────────────────────
class PrimaryButton extends StatelessWidget {
  final String label;          // button text
  final VoidCallback onPressed; // function called when tapped
  final bool isLoading;         // if true, show spinner (disable tap)
  final IconData? icon;         // optional icon before the label
  final double? width;          // optional fixed width (defaults to full width)

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity, // full width by default
      height: 50,
      child: ElevatedButton(
        // Disable the button while loading (prevents double submissions)
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            // Show a small white spinner when the API call is running
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            // Normal state: optional icon + label text
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(label),
                ],
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AppTextField — styled text input field used in all forms
//
// Wraps Flutter's TextFormField with our app's visual style.
// Works inside a Form widget so validation runs automatically.
//
// Example usage:
//   AppTextField(
//     label: 'Email',
//     controller: _emailCtrl,
//     keyboardType: TextInputType.emailAddress,
//     prefixIcon: Icons.email_outlined,
//     validator: (v) => v!.isEmpty ? 'Required' : null,
//   )
// ─────────────────────────────────────────────────────────────────────────────
class AppTextField extends StatelessWidget {
  final String label;                         // floating label text
  final String? hint;                          // placeholder text (shown when empty)
  final TextEditingController controller;      // holds the field's text value
  final bool obscureText;                      // true = password field (hides characters)
  final TextInputType keyboardType;            // controls which keyboard appears
  final String? Function(String?)? validator; // validation function
  final IconData? prefixIcon;                  // icon on the left side
  final Widget? suffixIcon;                    // widget on the right (e.g. eye icon)
  final int maxLines;                          // 1 = single line, >1 = textarea

  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    required this.controller,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller:    controller,
      obscureText:   obscureText,
      keyboardType:  keyboardType,
      validator:     validator,
      maxLines:      maxLines,
      // Style comes from inputDecorationTheme in constants.dart
      // We only override what's specific to this field instance
      decoration: InputDecoration(
        labelText: label,
        hintText:  hint,
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: kTextSecondary, size: 20)
            : null,
        suffixIcon: suffixIcon,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PageHeader — title + optional action button at the top of a page
//
// Example usage:
//   PageHeader(
//     title: 'Products',
//     subtitle: '12 products',
//     action: ElevatedButton(onPressed: _add, child: Text('Add')),
//   )
// ─────────────────────────────────────────────────────────────────────────────
class PageHeader extends StatelessWidget {
  final String title;     // main page title
  final String? subtitle; // small text below the title (e.g. item count)
  final Widget? action;   // button or widget on the right side

  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: kTextPrimary)),
              if (subtitle != null)
                Text(subtitle!,
                    style: const TextStyle(
                        color: kTextSecondary, fontSize: 13)),
            ],
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AppLoader — centered green loading spinner
// Used when data is being fetched from the API
// ─────────────────────────────────────────────────────────────────────────────
class AppLoader extends StatelessWidget {
  const AppLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: kPrimary),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ErrorMessage — centered error state with optional retry button
//
// Example usage:
//   ErrorMessage(
//     message: 'Could not load products',
//     onRetry: _loadProducts,
//   )
// ─────────────────────────────────────────────────────────────────────────────
class ErrorMessage extends StatelessWidget {
  final String message;     // error text to display
  final VoidCallback? onRetry; // if provided, shows a "Retry" button

  const ErrorMessage({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: kErrorColor, size: 48),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: kTextSecondary, fontSize: 14)),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            TextButton(
                onPressed: onRetry,
                child: const Text('Retry',
                    style: TextStyle(color: kPrimary))),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// showConfirmDialog — reusable confirmation dialog (async)
// Returns true if the user confirmed, false if they cancelled, null if dismissed
//
// Example usage:
//   final confirmed = await showConfirmDialog(
//     context,
//     title: 'Delete product',
//     message: 'Are you sure?',
//   );
//   if (confirmed == true) { /* proceed */ }
// ─────────────────────────────────────────────────────────────────────────────
Future<bool?> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmText = 'Confirm',
  Color confirmColor = kErrorColor,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 17)),
      content: Text(message),
      actions: [
        // Cancel button — returns false
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: kTextSecondary))),
        // Confirm button — returns true
        ElevatedButton(
          style:
              ElevatedButton.styleFrom(backgroundColor: confirmColor),
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmText),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// showSuccess / showError — floating snackbar notifications
//
// showSuccess → green background, checkmark icon
// showError   → red background, error icon
//
// Both use ScaffoldMessenger so they work from anywhere in the widget tree
// ─────────────────────────────────────────────────────────────────────────────
void showSuccess(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg)), // Expanded prevents text overflow
      ]),
      backgroundColor: kSuccessColor,
      behavior: SnackBarBehavior.floating, // hovers above the bottom
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}

void showError(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: kErrorColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// StatusBadge — colored pill label (used for roles, order status, etc.)
//
// Example usage:
//   StatusBadge(label: 'Manager', color: kWarningColor)
//   StatusBadge(label: 'Cancelled', color: kErrorColor)
// ─────────────────────────────────────────────────────────────────────────────
class StatusBadge extends StatelessWidget {
  final String label; // text inside the badge
  final Color color;  // accent color (background tint + border + text)

  const StatusBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color:  color.withOpacity(0.12), // very light tinted background
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600)),
    );
  }
}
import 'package:flutter/material.dart';

/// 1250000 -> "1,250,000"
String formatNumber(num v) => v.round().toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (m) => ',',
);

String ugx(num v) => 'UGX ${formatNumber(v)}';

String fmtTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '${h.toString().padLeft(2, '0')}:$m ${d.hour >= 12 ? 'PM' : 'AM'}';
}

String methodLabel(String m) {
  switch (m) {
    case 'Card':
      return 'Credit / Debit Card';
    default:
      return m;
  }
}

IconData methodIcon(String m) {
  switch (m) {
    case 'Cash':
      return Icons.payments_outlined;
    case 'Card':
      return Icons.credit_card;
    case 'Mobile Money':
      return Icons.phone_android;
    default:
      return Icons.account_balance;
  }
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class SearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;

  const SearchField({super.key, required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search, size: 20),
        isDense: true,
      ),
    );
  }
}

/// Rounded selectable pill used for tabs / filters.
class PillChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const PillChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.primary;
    return Material(
      color: selected ? c : Colors.white,
      shape: StadiumBorder(
        side: BorderSide(color: selected ? c : const Color(0xFFDCE4DF)),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF36443C),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

AppBar simpleAppBar(String title, {bool back = true, List<Widget>? actions}) {
  return AppBar(
    title: Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    ),
    automaticallyImplyLeading: back,
    actions: actions,
    foregroundColor: Colors.black87,
    elevation: 0,
    scrolledUnderElevation: 0,
  );
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
}

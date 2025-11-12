import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';

/// Payment screen: choose Cash or Card. Card flow is a placeholder with Stripe notes.
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _method = 'cash';
  String _cardLast4 = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _method = prefs.getString('payment_method') ?? 'cash';
    _cardLast4 = prefs.getString('card_last4') ?? '';
    setState(() {});
  }

  Future<void> _save(String method, {String last4 = ''}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('payment_method', method);
    if (last4.isNotEmpty) await prefs.setString('card_last4', last4);
    setState(() {
      _method = method;
      _cardLast4 = last4;
    });
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Payment method updated')));
    }
  }

  void _onAddCardPressed() async {
    // Placeholder: in a real app use flutter_stripe (https://pub.dev/packages/flutter_stripe)
    // to collect and tokenize card details, and securely create a PaymentMethod on your backend.
    // For prototyping we accept a fake card and store last 4 digits.
    final last4 = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Add card (demo)'),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'Enter last 4 digits'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(ctrl.text),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (last4 != null && last4.trim().length == 4) {
      await _save('card', last4: last4.trim());
    } else if (last4 != null) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please enter 4 digits')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payments'),
        backgroundColor: AppColors.primaryPink,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: const Text('Cash'),
              subtitle: const Text('Pay the driver in cash'),
              leading: Radio<String>(
                value: 'cash',
                groupValue: _method,
                onChanged: (v) => _save('cash'),
              ),
            ),
            const Divider(),
            ListTile(
              title: const Text('Card (Stripe)'),
              subtitle: Text(
                _cardLast4.isEmpty ? 'No card added' : '•••• $_cardLast4',
              ),
              leading: Radio<String>(
                value: 'card',
                groupValue: _method,
                onChanged: (v) async {
                  await _save('card');
                },
              ),
              trailing: ElevatedButton(
                onPressed: _onAddCardPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPink,
                ),
                child: const Text('Add card'),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Stripe integration notes:',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              '• Install and configure `flutter_stripe` per its docs (Android/iOS native setup).',
            ),
            const Text(
              '• Collect card details using stripe elements and send to your backend to create PaymentIntents.',
            ),
            const SizedBox(height: 12),
            const Text(
              'This screen only stores a demo last-4 for prototyping.',
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  Future<void> _launchURL(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
        backgroundColor: AppColors.primaryPink,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Contact Support
          _buildSupportCard(
            context,
            icon: Icons.mail_outline,
            title: 'Email Support',
            subtitle: 'support@deplacetoi.com',
            onTap: () => _launchURL('mailto:support@deplacetoi.com'),
          ),
          const SizedBox(height: 12),

          // Call Support
          _buildSupportCard(
            context,
            icon: Icons.phone_outlined,
            title: 'Call Us',
            subtitle: '+212 5XX XXX XXX',
            onTap: () => _launchURL('tel:+212XXXXXXXXX'),
          ),
          const SizedBox(height: 12),

          // Live Chat
          _buildSupportCard(
            context,
            icon: Icons.chat_bubble_outline,
            title: 'Live Chat',
            subtitle: 'Chat with our support team',
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Live chat coming soon')),
            ),
          ),
          const SizedBox(height: 24),

          // FAQ Section
          Text(
            'Frequently Asked Questions',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),

          _buildFAQItem(
            'How do I book a ride?',
            'Tap the menu button, select your pickup and destination, confirm the fare, and choose your payment method.',
          ),
          const SizedBox(height: 12),

          _buildFAQItem(
            'What payment methods are accepted?',
            'We accept cash and credit/debit card payments through our secure Stripe integration.',
          ),
          const SizedBox(height: 12),

          _buildFAQItem(
            'How can I become a driver?',
            'Tap the "Be a DeplaceToi Driver" button in the menu to join our driver community.',
          ),
          const SizedBox(height: 12),

          _buildFAQItem(
            'What if I have a problem with my ride?',
            'Contact our support team immediately through email, phone, or live chat for assistance.',
          ),
        ],
      ),
    );
  }

  Widget _buildSupportCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.primaryPink.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primaryPink, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey.shade400,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Theme(
      data: ThemeData(useMaterial3: true),
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              answer,
              style: TextStyle(color: Colors.grey.shade700, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

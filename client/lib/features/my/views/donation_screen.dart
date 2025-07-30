import 'package:flutter/material.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';
import 'package:url_launcher/url_launcher.dart';

class DonationScreen extends StatelessWidget {
  const DonationScreen({super.key});

  static const String koFiUrl = 'https://ko-fi.com/oldrev';
  static const String paypalUrl = 'https://www.paypal.com/paypalme/oldrev';

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(context.translate('Back This Project')), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Heart icon
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.38),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.favorite, size: 48, color: colorScheme.primary),
            ),

            const SizedBox(height: 24),

            // Title
            Text(
              context.translate('Support Open Source Aquarium Tech'),
              style: theme.textTheme.headlineSmall?.copyWith(color: colorScheme.onSurface),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            // Description
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.38),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colorScheme.outlineVariant, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.translate('Why Your Support Matters'),
                    style: theme.textTheme.titleMedium?.copyWith(color: colorScheme.onSurface),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.translate(
                      'Your donation helps cover development costs, server expenses, and continuous improvements that benefit the entire aquarium community. Every contribution, no matter how small, helps keep this project alive and thriving. Thank you for being part of this journey!',
                    ),
                    style: theme.textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant, height: 1.6),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Donation buttons
            Text(
              context.translate('Choose Your Support Method'),
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
            ),

            const SizedBox(height: 24),

            // Ko-fi button
            _buildDonationButton(
              context: context,
              icon: Icons.coffee,
              label: 'Ko-fi',
              description: context.translate('Buy me a coffee'),
              color: const Color(0xFF13C3FF),
              onTap: () => _launchUrl(koFiUrl),
            ),

            const SizedBox(height: 16),

            // PayPal button
            _buildDonationButton(
              context: context,
              icon: Icons.account_balance_wallet,
              label: 'PayPal',
              description: context.translate('Support via PayPal'),
              color: const Color(0xFF0070BA),
              onTap: () => _launchUrl(paypalUrl),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDonationButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: color),
                    ),
                    Text(
                      description,
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.38),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

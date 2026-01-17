import 'package:flutter/material.dart';

class TermsConditionsPage extends StatelessWidget {
  const TermsConditionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Terms & Conditions',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Last updated: January 2026',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Acceptance of Terms',
              'By using Indoor Navigation, you agree to these terms and conditions.',
            ),
            _buildSection(
              'License',
              'We grant you a limited, non-exclusive license to use our app for personal purposes.',
            ),
            _buildSection(
              'User Responsibilities',
              'You are responsible for maintaining the confidentiality of your account and for all activities under your account.',
            ),
            _buildSection(
              'Limitation of Liability',
              'Indoor Navigation is provided as-is. We are not liable for indirect damages or data loss.',
            ),
            _buildSection(
              'Changes to Terms',
              'We reserve the right to modify these terms at any time. Changes are effective immediately upon posting.',
            ),
            _buildSection(
              'Contact Us',
              'For questions about these terms, contact us at support@indoornavigation.app',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(content),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

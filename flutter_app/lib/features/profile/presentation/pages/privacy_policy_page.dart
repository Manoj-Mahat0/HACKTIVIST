import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Privacy Policy',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Last updated: January 2026',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Introduction',
              'Indoor Navigation respects your privacy. This privacy policy explains how we collect, use, and protect your data.',
            ),
            _buildSection(
              'Data Collection',
              'We collect location data, device information, and usage patterns to improve navigation accuracy and user experience.',
            ),
            _buildSection(
              'Data Usage',
              'Your data is used solely for service improvement and is never sold to third parties.',
            ),
            _buildSection(
              'Security',
              'We implement industry-standard security measures to protect your information.',
            ),
            _buildSection(
              'Contact Us',
              'For privacy concerns, contact us at privacy@indoornavigation.app',
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

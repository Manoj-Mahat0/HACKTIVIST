import 'package:flutter/material.dart';

class FAQPage extends StatelessWidget {
  const FAQPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FAQs'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: const [
          _FAQItem(
            question: 'How do I use the AR navigation?',
            answer: 'Open a building and tap "Start Navigation". The app will guide you using augmented reality.',
          ),
          _FAQItem(
            question: 'Can I use the app offline?',
            answer: 'Yes! Download building maps in the Offline Downloads section for offline use.',
          ),
          _FAQItem(
            question: 'How accurate is the indoor positioning?',
            answer: 'The accuracy depends on GPS and WiFi signals. PDR (Pedestrian Dead Reckoning) helps improve accuracy indoors.',
          ),
          _FAQItem(
            question: 'How do I report an issue?',
            answer: 'Go to Profile > Send Feedback to report issues or suggestions.',
          ),
        ],
      ),
    );
  }
}

class _FAQItem extends StatefulWidget {
  final String question;
  final String answer;

  const _FAQItem({
    required this.question,
    required this.answer,
  });

  @override
  State<_FAQItem> createState() => _FAQItemState();
}

class _FAQItemState extends State<_FAQItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(widget.question),
        onExpansionChanged: (expanded) {
          setState(() => _isExpanded = expanded);
        },
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(widget.answer),
          ),
        ],
      ),
    );
  }
}

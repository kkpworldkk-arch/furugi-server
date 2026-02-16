import 'package:flutter/material.dart';

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("お問い合わせ")),
      body: const Center(
        child: Text("お問い合わせフォームは準備中です"),
      ),
    );
  }
}
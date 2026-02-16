import 'package:flutter/material.dart';
import 'api_service.dart';

class ReviewSubmissionScreen extends StatefulWidget {
  final int shopId;
  final String shopName;

  const ReviewSubmissionScreen({super.key, required this.shopId, required this.shopName});

  @override
  State<ReviewSubmissionScreen> createState() => _ReviewSubmissionScreenState();
}

class _ReviewSubmissionScreenState extends State<ReviewSubmissionScreen> {
  double _rating = 3.0;
  final _commentController = TextEditingController();

  Future<void> _submit() async {
    await ApiService.postReview(widget.shopId, _rating, _commentController.text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('投稿しました')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.shopName}のレビュー')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text("評価"),
            Slider(
              value: _rating, min: 1, max: 5, divisions: 4, label: "$_rating",
              onChanged: (v) => setState(() => _rating = v),
            ),
            TextField(controller: _commentController, decoration: const InputDecoration(labelText: 'コメント')),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _submit, child: const Text('投稿')),
          ],
        ),
      ),
    );
  }
}
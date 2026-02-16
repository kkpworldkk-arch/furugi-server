import 'package:flutter/material.dart';
import 'base_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // MobileAds.instance.initialize(); // 広告エラー防止のためコメントアウト
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '古着屋マップ',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown),
        useMaterial3: true,
      ),
      // 引数なしでBaseScreenを呼ぶのが正解
      home: const BaseScreen(),
    );
  }
}
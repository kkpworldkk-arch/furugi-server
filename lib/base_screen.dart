import 'package:flutter/material.dart';
import 'map_screen.dart';
import 'search_screen.dart';
import 'dig_timeline_screen.dart';
import 'article_list_screen.dart';
import 'my_page_screen.dart';

class BaseScreen extends StatefulWidget {
  const BaseScreen({super.key});

  @override
  State<BaseScreen> createState() => _BaseScreenState();
}

class _BaseScreenState extends State<BaseScreen> {
  int _selectedIndex = 0;

  // 一度開いたタブのみWidget化してキャッシュ（起動時は0番のみ初期化）
  final Map<int, Widget> _pageCache = {};

  Widget _buildPage(int index) {
    switch (index) {
      case 0: return const MapScreen();
      case 1: return const SearchScreen();
      case 2: return const DigTimelineScreen();
      case 3: return const ArticleListScreen();
      case 4: return const MyPageScreen();
      default: return const SizedBox();
    }
  }

  Widget _getPage(int index) {
    return _pageCache.putIfAbsent(index, () => _buildPage(index));
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: List.generate(5, (i) {
          // 現在のタブ or 一度でも開いたタブだけWidgetを生成
          if (i == _selectedIndex || _pageCache.containsKey(i)) {
            return _getPage(i);
          }
          return const SizedBox.shrink();
        }),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), activeIcon: Icon(Icons.map), label: 'マップ'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: '検索'),
          BottomNavigationBarItem(icon: Icon(Icons.explore_outlined), activeIcon: Icon(Icons.explore), label: 'ディグった'),
          BottomNavigationBarItem(icon: Icon(Icons.article_outlined), activeIcon: Icon(Icons.article), label: 'タイムライン'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'マイページ'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.brown,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }
}

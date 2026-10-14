import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../imap.dart';

class DynamicTabScreen extends StatefulWidget {
  const DynamicTabScreen({super.key});

  @override
  State<DynamicTabScreen> createState() => _DynamicTabScreenState();
}

class _DynamicTabScreenState extends State<DynamicTabScreen>
    with TickerProviderStateMixin {
  // Your tab list can grow or change dynamically
  final List<String> _tabTitles = ['Tab 1', 'Tab 222222222', 'Tab 3', 'Tab 22222224'];
  late TabController _tabController;
  late List<ScrollController> _scrollControllers;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabTitles.length, vsync: this);
    _scrollControllers = List.generate(
      _tabTitles.length,
      (_) => ScrollController(),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (var controller in _scrollControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return [
            SliverAppBar(
              floating: true,
              snap: true,
              elevation: 0,
              // Top Row: Search box + button
              title: Row(
                children: [
                  Expanded(
                    child: CupertinoSearchTextField(
                      // focusNode: _searchFocus,
                      // controller: _searchController,
                      placeholder: 'Search titles or authors...',
                      style: TextStyle(fontFamily: '.osdefault'),
                      onSuffixTap: () {
                        // _searchController.clear();
                        // if (_searchFocus.hasFocus) {
                        //   _searchFocus.unfocus();
                        // }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(onPressed: () {}, child: const Text('Filter')),
                ],
              ),
              // Second Row: Dynamic TabBar + button
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  // color: Colors.white,
                  child: Row(
                    children: [
                      Expanded(
                        child: TabBar(
                          controller: _tabController,
                          isScrollable: true,
                          // labelColor: Colors.blue,
                          // unselectedLabelColor: Colors.grey,
                          tabs: _tabTitles
                              .map((title) => Tab(text: title))
                              .toList(),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.tune),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: _tabTitles.imap((i, title) {
            return ListView.builder(
              key: PageStorageKey<String>(
                'tab$i',
              ), // Preserves scroll position(),
              restorationId: 'lv:$title', //
              controller: _scrollControllers[i],
              itemCount: 50,
              itemBuilder: (context, index) {
                return ListTile(title: Text('$title - Item ${index + 1}'));
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../epub/epub.dart';

const kFontFamily = '.osdefault';

class CupertinoBookApp extends StatelessWidget {
  const CupertinoBookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      theme: CupertinoThemeData(
        textTheme: CupertinoTextThemeData(
          // Base / general text
          textStyle: TextStyle(
            fontFamily: kFontFamily,
            // Keep good defaults for readability (especially large text)
            fontSize: 17.0,
            letterSpacing: -0.41,
            height: 1.25, // comfortable line height for large text
            fontWeight: FontWeight.w400,
          ),
          // Buttons
          actionTextStyle: TextStyle(
            fontFamily: kFontFamily,
            fontSize: 17.0,
            letterSpacing: -0.41,
            height: 1.25,
          ),
          actionSmallTextStyle: TextStyle(
            fontFamily: kFontFamily,
            fontSize: 15.0,
            letterSpacing: -0.24,
            height: 1.25,
          ),
          // Navigation
          navTitleTextStyle: TextStyle(
            fontFamily: kFontFamily,
            fontSize: 17.0,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.41,
            height: 1.2,
          ),
          navLargeTitleTextStyle: TextStyle(
            fontFamily: kFontFamily,
            fontSize: 34.0, // large title
            fontWeight: FontWeight.w700,
            letterSpacing: 0.41,
            height: 1.15, // tighter for big display sizes
          ),
          navActionTextStyle: TextStyle(
            fontFamily: kFontFamily,
            fontSize: 17.0,
            letterSpacing: -0.41,
            height: 1.25,
          ),
          // Tabs & pickers
          tabLabelTextStyle: TextStyle(
            fontFamily: kFontFamily,
            fontSize: 10.0,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.24,
            height: 1.2,
          ),
          pickerTextStyle: TextStyle(
            fontFamily: kFontFamily,
            fontSize: 25.0, // large picker text
            letterSpacing: -0.41,
            height: 1.2,
          ),
          dateTimePickerTextStyle: TextStyle(
            fontFamily: kFontFamily,
            fontSize: 21.0,
            letterSpacing: -0.41,
            height: 1.2,
          ),
        ),
      ),
      builder: (context, child) {
        print(
          'in app default text style: ${CupertinoTheme.of(context).textTheme.textStyle}',
        );
        // DefaultTextStyle not work, Material worked
        return DefaultTextStyle(
          style: CupertinoTheme.of(context).textTheme.textStyle,
          child: ShelfScreen(),
        );
      },
    );
  }
}

class ShelfScreen extends StatefulWidget {
  const ShelfScreen({super.key});

  @override
  State<ShelfScreen> createState() => _ShelfScreenState();
}

class _ShelfScreenState extends State<ShelfScreen> {
  final List<String> _shelves = ['All', 'Reading', 'To Read', 'Finished'];
  int _selectedShelfIndex = 0;
  String _searchQuery = '';

  // Page Controller to sync with PageView
  late PageController _pageController;
  late Map<String, List<Book>> _booksByShelf;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedShelfIndex);
    _booksByShelf = <String, List<Book>>{};
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _showNewShelfDialog() {
    final TextEditingController controller = TextEditingController();
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('New Shelf'),
        content: Padding(
          padding: const EdgeInsets.only(top: 10.0),
          child: CupertinoTextField(
            controller: controller,
            placeholder: 'Shelf Name',
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Create'),
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() {
                  String newShelf = controller.text.trim();
                  if (!_shelves.contains(newShelf)) {
                    _shelves.add(newShelf);
                    _booksByShelf[newShelf] = [];
                  }
                });
              }
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _openBook(Book book) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Material(
        child: CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            middle: Text(book.title),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Text('Done'),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      CupertinoIcons.book_fill,
                      size: 100,
                      color: CupertinoColors.systemOrange,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      book.title,
                      style: CupertinoTheme.of(
                        context,
                      ).textTheme.navTitleTextStyle.copyWith(fontSize: 24),
                    ),
                    Text(
                      'by ${book.author}',
                      style: const TextStyle(
                        color: CupertinoColors.secondaryLabel,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 40),
                    Text('Reading Progress: ${(0.3 * 100).toInt()}%'),
                    const SizedBox(height: 10),
                    CupertinoSlider(value: 1, onChanged: (val) {}),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          CupertinoSliverNavigationBar(
            largeTitle: const Text('My Books'),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _showNewShelfDialog,
              child: const Icon(CupertinoIcons.folder_badge_plus, size: 24),
            ),
          ),
        ],
        body: Column(
          children: [
            // Search Box Block
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: CupertinoSearchTextField(
                placeholder: 'Search title or author...',
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
              ),
            ),

            // Tab / Indicator bar to display available shelves
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: CupertinoSlidingSegmentedControl<int>(
                  groupValue: _selectedShelfIndex,
                  children: {
                    for (int i = 0; i < _shelves.length; i++)
                      i: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 6.0,
                        ),
                        child: Text(
                          _shelves[i],
                          style: TextStyle(
                            fontWeight: _selectedShelfIndex == i
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                  },
                  onValueChanged: (int? index) {
                    if (index != null) {
                      setState(() => _selectedShelfIndex = index);
                      _pageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                ),
              ),
            ),

            // Books Layout using PageView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (int index) {
                  setState(() => _selectedShelfIndex = index);
                },
                itemCount: _shelves.length,
                itemBuilder: (context, shelfIndex) {
                  String currentShelf = _shelves[shelfIndex];

                  // Filter books based on shelf and search string
                  List<Book> displayedBooks =
                      (_booksByShelf[currentShelf] ?? []).where((book) {
                        return book.title.toLowerCase().contains(
                              _searchQuery.toLowerCase(),
                            ) ||
                            book.author.toLowerCase().contains(
                              _searchQuery.toLowerCase(),
                            );
                      }).toList();

                  if (displayedBooks.isEmpty) {
                    return const Center(
                      child: Text(
                        'No books on this shelf',
                        style: TextStyle(color: CupertinoColors.secondaryLabel),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: displayedBooks.length,
                    itemBuilder: (context, index) {
                      final book = displayedBooks[index];

                      return Dismissible(
                        key: Key(book.title + currentShelf),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20.0),
                          color: CupertinoColors.systemRed,
                          child: const Icon(
                            CupertinoIcons.delete,
                            color: CupertinoColors.white,
                          ),
                        ),
                        onDismissed: (direction) {
                          setState(() {
                            // remove by id
                          });
                        },
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _openBook(book),
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    const Icon(
                                      CupertinoIcons.book,
                                      size: 40,
                                      color: CupertinoColors.systemBlue,
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            book.title,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            book.author,
                                            style: const TextStyle(
                                              color: CupertinoColors
                                                  .secondaryLabel,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${(0.2 * 100).toInt()}%',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const Text(
                                          'progress',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: CupertinoColors.inactiveGray,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      CupertinoIcons.chevron_forward,
                                      size: 14,
                                      color:
                                          CupertinoColors.lightBackgroundGray,
                                    ),
                                  ],
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.only(left: 72.0),
                                child: SizedBox(
                                  height: 0.5,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: CupertinoColors.separator,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BookShelfScreen extends StatefulWidget {
  const BookShelfScreen({super.key});

  @override
  State<BookShelfScreen> createState() => _BookShelfScreenState();
}

class _BookShelfScreenState extends State<BookShelfScreen> {
  int _selectedSegment = 0;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // CupertinoTabView manages its own internal navigation context natively
    // CupertinoTabView
    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: <Widget>[
          // 1. Collapsible iOS Navigation Bar with an "Add" Action Button
          CupertinoSliverNavigationBar(
            largeTitle: const Text('Shelf'),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(CupertinoIcons.add, size: 26),
              onPressed: () {
                // TODO: Add Action
              },
            ),
          ),

          // 2. Persistent Header pinning the Search Field and Segmented Control
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Column(
                children: [
                  // Native Search Field
                  CupertinoSearchTextField(
                    controller: _searchController,
                    placeholder: 'Search',
                  ),
                  const SizedBox(height: 12),

                  // Sliding Segmented Tab Switcher
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoSlidingSegmentedControl<int>(
                      groupValue: _selectedSegment,
                      children: const {
                        0: Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Text('All Books'),
                        ),
                        1: Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Text('Reading'),
                        ),
                        2: Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Text('Finished'),
                        ),
                      },
                      onValueChanged: (int? value) {
                        if (value != null) {
                          setState(() {
                            _selectedSegment = value;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. SliverList displaying the list items based on active filters
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12.0),
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemBackground.resolveFrom(
                        context,
                      ),
                      borderRadius: BorderRadius.circular(12.0),
                      boxShadow: [
                        BoxShadow(
                          color: CupertinoColors.systemGrey.withValues(alpha: 0.1),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          CupertinoIcons.book,
                          size: 40,
                          color: CupertinoColors.activeBlue,
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Book Title #$index',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const Text(
                              'Author Name',
                              style: TextStyle(
                                color: CupertinoColors.systemGrey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
                childCount: 15, // Replace with dynamic filtered list sizes
              ),
            ),
          ),
        ],
      ),
    );
  }
}

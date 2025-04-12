import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/news_provider.dart';
import '../providers/theme_provider.dart';
import '../models/article.dart';
import 'profile_screen.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  NewsScreenState createState() => NewsScreenState();
}

class NewsScreenState extends State<NewsScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isNewsFetched = false;

  @override
  void initState() {
    super.initState();
    // Fetching news only if not already fetched
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isNewsFetched) {
        print('Fetching news...');
        Provider.of<NewsProvider>(context, listen: false).fetchNews().then((_) {
          print('News fetched successfully.');
          setState(() {
            _isNewsFetched = true;
          });
        }).catchError((error) {
          print('Error fetching news: $error');
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search() {
    print('Searching news for query: ${_searchController.text}');
    Provider.of<NewsProvider>(context, listen: false)
        .fetchNews(query: _searchController.text);
  }

  Future<void> _refresh() async {
    final query = _searchController.text.trim();
    print('Refreshing news with query: $query');

    await Provider.of<NewsProvider>(context, listen: false)
        .fetchNews(query: query.isNotEmpty ? query : '');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('News refreshed')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('News Feed'),
        actions: [
          IconButton(
            icon: Icon(
              themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: () {
              themeProvider.toggleTheme();
            },
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search News...',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _search(); // Refresh with empty query
                              },
                            )
                          : null,
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Consumer<NewsProvider>(
              builder: (context, newsProvider, child) {
                if (newsProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (newsProvider.error.isNotEmpty) {
                  return Center(
                    child: Text(
                      newsProvider.error,
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                if (newsProvider.articles.isEmpty) {
                  return const Center(
                    child: Text('No articles found'),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    itemCount: newsProvider.articles.length,
                    itemBuilder: (context, index) {
                      final article = newsProvider.articles[index];
                      return NewsCard(article: article);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class NewsCard extends StatelessWidget {
  final Article article;

  const NewsCard({super.key, required this.article});

 
  Future<void> _launchURL(url) async {
    final Uri uri = Uri.parse(url);  
    if (await canLaunch(uri.toString())) { // Check if the URL can be launched
      await launch(uri.toString(), forceWebView: false, forceSafariVC: false);  // Launch the URL
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: InkWell(
        onTap: () {
          // Navigator.push(
          //   context,
          //   MaterialPageRoute(
          //     builder: (context) => ArticleScreen(article: article),
          //   ),
          // );
          _launchURL(article.url);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            article.image.isNotEmpty
                ? Image.network(
                    article.image,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        color: Colors.grey[300],
                        child: const Center(
                          child: Icon(Icons.image_not_supported),
                        ),
                      );
                    },
                  )
                : Container(
                    height: 200,
                    color: Colors.grey[300],
                    width: double.infinity,
                    child: const Center(
                      child: Icon(Icons.image_not_supported),
                    ),
                  ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    article.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        article.source,
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _formatDate(article.publishedAt),
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }
}

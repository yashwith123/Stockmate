import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';

// Add your IPO API key here (FinancialModelingPrep or another provider).
// Leave empty to use sample/mock IPO entries.
const String IPO_API_KEY = 'd84t9phr01qrqbnnha60d84t9phr01qrqbnnha6g';
// News API key (Marketaux). Provided by the user.
const String NEWS_API_KEY = 'hJojN0E6gJkSGtOXk9tkSzXd4FTMUwTyQQ709z9T';

void main() {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF1F1B2E),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const StockMateApp());
}

class IPOListPage extends StatefulWidget {
  const IPOListPage({super.key});

  @override
  State<IPOListPage> createState() => _IPOListPageState();
}

class _IPOListPageState extends State<IPOListPage> {
  List<Map<String, String>> _ipos = [];
  bool _loading = false;
  String? _error;

  static final List<Map<String, String>> _sampleIpos = [
    {
      'company': 'Acme Robotics',
      'date': '2026-06-15',
      'price': '10 - 12',
      'exchange': 'NASDAQ',
    },
    {
      'company': 'Green Energy Co',
      'date': '2026-07-01',
      'price': '18 - 20',
      'exchange': 'NYSE',
    },
    {
      'company': 'FinTech Innovations',
      'date': '2026-07-20',
      'price': '6 - 8',
      'exchange': 'NASDAQ',
    },
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    if (IPO_API_KEY.trim().isEmpty) {
      // No API key provided — show sample data
      await Future.delayed(const Duration(milliseconds: 200));
      setState(() {
        _ipos = List.from(_sampleIpos);
        _loading = false;
      });
      return;
    }

    try {
      final from = DateTime.now().toIso8601String().split('T')[0];
      final to = DateTime.now()
          .add(const Duration(days: 365))
          .toIso8601String()
          .split('T')[0];

      // Try FinancialModelingPrep first
      bool got = false;

      final fmpUrl =
          'https://financialmodelingprep.com/api/v3/ipo_calendar?from=$from&to=$to&apikey=$IPO_API_KEY';
      final fmpResp = await http.get(Uri.parse(fmpUrl));
      if (fmpResp.statusCode == 200) {
        try {
          final data = json.decode(fmpResp.body);
          if (data is List && data.isNotEmpty) {
            final List<Map<String, String>> parsed = [];
            for (var item in data) {
              parsed.add({
                'company': (item['company'] ?? item['companyDescription'] ?? '')
                    .toString(),
                'symbol': (item['symbol'] ?? '').toString(),
                'exchange': (item['exchange'] ?? '').toString(),
                'date': (item['date'] ?? '').toString(),
                'price': (item['price'] ?? '').toString(),
              });
            }
            setState(() {
              _ipos = parsed;
              _loading = false;
            });
            got = true;
          }
        } catch (_) {
          // fallthrough to try other providers
        }
      }

      if (!got) {
        // If FMP failed (401/invalid key) try Finnhub
        final fhUrl =
            'https://finnhub.io/api/v1/calendar/ipo?from=$from&to=$to&token=$IPO_API_KEY';
        final fhResp = await http.get(Uri.parse(fhUrl));
        if (fhResp.statusCode == 200) {
          try {
            final data = json.decode(fhResp.body);
            // Find first list in the response
            List items = [];
            if (data is List)
              items = data;
            else if (data is Map) {
              for (var v in data.values) {
                if (v is List) {
                  items = v;
                  break;
                }
              }
            }

            if (items.isNotEmpty) {
              final List<Map<String, String>> parsed = [];
              for (var item in items) {
                parsed.add({
                  'company': (item['name'] ?? item['company'] ?? '').toString(),
                  'symbol': (item['symbol'] ?? item['ticker'] ?? '').toString(),
                  'exchange': (item['exchange'] ?? item['market'] ?? '')
                      .toString(),
                  'date': (item['date'] ?? item['ipoDate'] ?? '').toString(),
                  'price': (item['price'] ?? item['priceRange'] ?? '')
                      .toString(),
                });
              }
              setState(() {
                _ipos = parsed;
                _loading = false;
              });
              got = true;
            } else {
              setState(() {
                _error = 'No IPO data available.';
                _loading = false;
              });
            }
          } catch (e) {
            setState(() {
              _error = 'Failed to parse IPO data: $e';
              _loading = false;
            });
          }
        } else {
          setState(() {
            _error = 'Failed to fetch IPOs (code ${fhResp.statusCode}).';
            _loading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Network error: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upcoming IPOs')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? ListView(
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _error!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: _ipos.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final ipo = _ipos[index];
                  return Card(
                    color: Theme.of(context).cardColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      title: Text(
                        ipo['company'] ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: Text(
                        '${ipo['exchange']} • ${ipo['date']} • Price: ${ipo['price']}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      trailing: ElevatedButton(
                        onPressed: () => showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            backgroundColor: const Color(0xFF2D2644),
                            title: Text(ipo['company'] ?? ''),
                            content: Text(
                              'Symbol: ${ipo['symbol']}\nExchange: ${ipo['exchange']}\nDate: ${ipo['date']}\nPrice Range: ${ipo['price']}',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text(
                                  'Close',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ),
                            ],
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFBE8BFF),
                        ),
                        child: const Text('Details'),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class WishlistPage extends StatefulWidget {
  final List<Map<String, String>> wishlist;
  final void Function(String symbol) onRemove;

  const WishlistPage({
    super.key,
    required this.wishlist,
    required this.onRemove,
  });

  @override
  State<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends State<WishlistPage> {
  late List<Map<String, String>> _items;

  @override
  void initState() {
    super.initState();
    _items = List<Map<String, String>>.from(widget.wishlist);
  }

  void _remove(String symbol) {
    setState(() {
      _items.removeWhere((e) => e['symbol'] == symbol);
    });
    widget.onRemove(symbol);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wish List')),
      body: _items.isEmpty
          ? Center(
              child: Text(
                'No items in your wish list.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = _items[index];
                final symbol = item['symbol'] ?? '';
                final name = item['name'] ?? '';
                return Card(
                  color: Theme.of(context).cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    title: Text(
                      name.isNotEmpty ? '$name  •  $symbol' : symbol,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.white70,
                      ),
                      onPressed: () {
                        _remove(symbol);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Removed $symbol from wishlist'),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, String>> _articles = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _controller.text.trim();
    setState(() {
      _loading = true;
      _error = null;
      _articles = [];
    });

    if (NEWS_API_KEY.trim().isEmpty) {
      setState(() {
        _error = 'News API key is not set.';
        _loading = false;
      });
      return;
    }

    try {
      // Try Marketaux first
      final base = 'https://api.marketaux.com/v1/news/all';
      final params = <String, String>{
        'api_token': NEWS_API_KEY,
        'language': 'en',
        'limit': '50',
      };
      if (q.isNotEmpty) params['q'] = q;
      final uri = Uri.parse(base).replace(queryParameters: params);
      final resp = await http.get(uri);
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        List items = [];
        if (data is List)
          items = data;
        else if (data is Map && data['data'] is List)
          items = data['data'];

        final parsed = <Map<String, String>>[];
        for (var it in items) {
          parsed.add({
            'title': (it['title'] ?? it['headline'] ?? '').toString(),
            'summary':
                (it['summary'] ?? it['description'] ?? it['excerpt'] ?? '')
                    .toString(),
            'source': (it['source'] ?? it['provider'] ?? '').toString(),
            'date':
                (it['published_at'] ??
                        it['published_at'] ??
                        it['published'] ??
                        '')
                    .toString(),
            'url': (it['url'] ?? it['link'] ?? '').toString(),
          });
        }
        setState(() {
          _articles = parsed;
          _loading = false;
        });
        return;
      }

      setState(() {
        _error = 'Failed to fetch news (code ${resp.statusCode}).';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Network error: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('News')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(hintText: 'Search news'),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _search, child: const Text('Search')),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Text(
                      _error!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                : _articles.isEmpty
                ? Center(
                    child: Text(
                      'No articles. Try a search.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _articles.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final a = _articles[index];
                      return Card(
                        color: Theme.of(context).cardColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          title: Text(
                            a['title'] ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          subtitle: Text(
                            '${a['source'] ?? ''} • ${a['date'] ?? ''}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          onTap: () => showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              backgroundColor: const Color(0xFF2D2644),
                              title: Text(a['title'] ?? ''),
                              content: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      a['summary'] ?? '',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    SelectableText(
                                      a['url'] ?? '',
                                      style: const TextStyle(
                                        color: Colors.white60,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text(
                                    'Close',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                ),
                              ],
                            ),
                          ),
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

class StockMateApp extends StatelessWidget {
  const StockMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'StockMate',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF181525),
        cardColor: const Color(0xFF2D2644),
        textTheme: const TextTheme(
          titleLarge: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          bodyMedium: TextStyle(color: Colors.white70),
          labelLarge: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF3B3454),
          hintStyle: const TextStyle(color: Colors.white54),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF7B1FA2), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16.0,
            horizontal: 16.0,
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

enum TimeRange {
  oneDay('1D', '1h', 24),
  oneWeek('1W', '1day', 7),
  oneMonth('1M', '1day', 30),
  oneYear('1Y', '1month', 12),
  all('ALL', '1month', 60);

  final String label;
  final String interval;
  final int outputsize;
  const TimeRange(this.label, this.interval, this.outputsize);
}

class StockDataPoint {
  final DateTime date;
  final double open;
  final double high;
  final double low;
  final double close;

  StockDataPoint({
    required this.date,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
  });
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  TimeRange _selectedRange = TimeRange.oneDay;
  static const String _apiKey = '21e53b974699442cb2b682c435e89d47';

  final TextEditingController _searchController = TextEditingController();
  List<StockDataPoint> _stockData = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _currentSymbol = '';
  String _currentCompanyName = '';
  List<Map<String, String>> _wishlist = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isLikelySymbol(String input) =>
      input.length <= 6 && input.toUpperCase() == input;

  Future<String?> _fetchCompanyName(String symbol) async {
    if (_apiKey == 'YOUR_TWELVE_DATA_API_KEY_HERE' || _apiKey.isEmpty)
      return null;
    final quoteUrl =
        'https://api.twelvedata.com/quote?symbol=$symbol&apikey=$_apiKey';
    final response = await http.get(Uri.parse(quoteUrl));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['name'] != null && data['name'].isNotEmpty) return data['name'];
    }
    return null;
  }

  Future<String?> _searchSymbolByCompanyName(String name) async {
    if (_apiKey == 'YOUR_TWELVE_DATA_API_KEY_HERE' || _apiKey.isEmpty)
      return null;
    final searchUrl =
        'https://api.twelvedata.com/symbol_search?symbol=$name&apikey=$_apiKey';
    final response = await http.get(Uri.parse(searchUrl));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['data'] != null && data['data'].isNotEmpty)
        return data['data'][0]['symbol'];
    }
    return null;
  }

  Future<void> _fetchStockData(String symbolOrName, {TimeRange? range}) async {
    final cleanInput = symbolOrName.trim();
    final effectiveRange = range ?? _selectedRange;
    if (cleanInput.isEmpty && _currentSymbol.isEmpty) {
      setState(() {
        _stockData = [];
        _errorMessage = null;
        _currentSymbol = '';
        _currentCompanyName = '';
      });
      return;
    }
    if (_apiKey == 'YOUR_TWELVE_DATA_API_KEY_HERE' || _apiKey.isEmpty) {
      setState(() {
        _errorMessage =
            'API Key is missing. Please replace "YOUR_TWELVE_DATA_API_KEY_HERE" with your actual key.';
        _stockData = [];
      });
      return;
    }

    String lookupSymbol = cleanInput.isNotEmpty
        ? cleanInput.toUpperCase()
        : _currentSymbol;
    String officialSymbol = lookupSymbol;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      if (cleanInput.isNotEmpty) {
        _currentSymbol = '';
        _currentCompanyName = cleanInput;
      }
    });

    if (cleanInput.isNotEmpty && !_isLikelySymbol(cleanInput)) {
      String? foundSymbol = await _searchSymbolByCompanyName(cleanInput);
      if (foundSymbol != null) {
        officialSymbol = foundSymbol;
      } else {
        setState(() {
          _stockData = [];
          _errorMessage =
              'Could not find a stock symbol for "$cleanInput". Please try again with the exact ticker.';
          _isLoading = false;
        });
        return;
      }
    }

    String? fetchedCompanyName = await _fetchCompanyName(officialSymbol);
    setState(() {
      _currentSymbol = officialSymbol;
      _currentCompanyName = fetchedCompanyName ?? officialSymbol;
    });

    try {
      final url =
          'https://api.twelvedata.com/time_series?symbol=$officialSymbol&interval=${effectiveRange.interval}&outputsize=${effectiveRange.outputsize}&type=stock&apikey=$_apiKey';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'error' || data['values'] == null) {
          String error =
              data['message'] ??
              'Symbol "$officialSymbol" not found or data unavailable.';
          setState(() {
            _stockData = [];
            _errorMessage = error;
            _isLoading = false;
          });
          return;
        }
        List<StockDataPoint> points = [];
        for (var item in data['values'].reversed) {
          points.add(
            StockDataPoint(
              date: DateTime.parse(item['datetime']),
              open: double.tryParse(item['open'].toString()) ?? 0.0,
              high: double.tryParse(item['high'].toString()) ?? 0.0,
              low: double.tryParse(item['low'].toString()) ?? 0.0,
              close: double.tryParse(item['close'].toString()) ?? 0.0,
            ),
          );
        }
        setState(() {
          _stockData = points;
          _errorMessage = null;
          _selectedRange = effectiveRange;
        });
      } else {
        setState(() {
          _errorMessage =
              'Failed to load data. HTTP Status code: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildMessage(IconData icon, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white38, size: 40),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium!.copyWith(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRangeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Color.fromRGBO(59, 52, 84, 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: TimeRange.values.map((range) {
          final isSelected = _selectedRange == range;
          return TextButton(
            onPressed: () {
              if (_currentSymbol.isNotEmpty && !isSelected)
                _fetchStockData(_currentSymbol, range: range);
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              backgroundColor: isSelected
                  ? const Color(0xFF7B1FA2)
                  : Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              range.label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white60,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                if (_currentSymbol.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No stock selected to add.')),
                  );
                  return;
                }
                final exists = _wishlist.any(
                  (e) => e['symbol'] == _currentSymbol,
                );
                setState(() {
                  if (exists) {
                    _wishlist.removeWhere((e) => e['symbol'] == _currentSymbol);
                  } else {
                    _wishlist.add({
                      'symbol': _currentSymbol,
                      'name': _currentCompanyName,
                    });
                  }
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      exists
                          ? 'Removed $_currentSymbol from Wish List'
                          : 'Added $_currentSymbol to Wish List',
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B3454),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFAD81ED), width: 1.5),
                ),
              ),
              child: const Text(
                'Wish List',
                style: TextStyle(
                  color: Color(0xFFAD81ED),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Navigating to Buy/Order screen...'),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFBE8BFF),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Buy Now',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockChart() {
    if (_stockData.isEmpty) return Container();

    final double firstPrice = _stockData.first.open;
    final double lastPrice = _stockData.last.close;
    final double absoluteChange = lastPrice - firstPrice;
    final double percentageChange = (absoluteChange / firstPrice) * 100;

    final double minY =
        _stockData.map((p) => p.close).reduce((a, b) => a < b ? a : b) * 0.995;
    final double maxY =
        _stockData.map((p) => p.close).reduce((a, b) => a > b ? a : b) * 1.005;

    List<FlSpot> spots = _stockData
        .asMap()
        .entries
        .map((entry) => FlSpot(entry.key.toDouble(), entry.value.close))
        .toList();

    final bool isPriceUp = absoluteChange >= 0;
    final Color chartLineColor = isPriceUp
        ? const Color(0xFF14C6A9)
        : const Color(0xFFF05F5F);
    final Color chartGradientStart = chartLineColor;
    final Color chartGradientEnd = chartLineColor.withAlpha(0);

    return Padding(
      padding: const EdgeInsets.only(
        right: 18.0,
        top: 18.0,
        left: 6.0,
        bottom: 18.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentSymbol,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _currentCompanyName,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '\$${lastPrice.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: chartLineColor,
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${isPriceUp ? '+' : ''}${absoluteChange.toStringAsFixed(2)} (${percentageChange.toStringAsFixed(2)}%)',
                      style: TextStyle(
                        color: chartLineColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AspectRatio(
            aspectRatio: 1.8,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.white12, width: 1),
                ),
                minX: 0,
                maxX: spots.isNotEmpty ? spots.length - 1.toDouble() : 0,
                minY: minY,
                maxY: maxY,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) => touchedSpots
                        .map(
                          (touchedSpot) => LineTooltipItem(
                            '\$${touchedSpot.y.toStringAsFixed(2)}',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: chartLineColor,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          chartGradientStart.withAlpha(77),
                          chartGradientEnd,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: _buildTimeRangeSelector(),
          ),
          const SizedBox(height: 24),
          _buildActionButtons(context),
        ],
      ),
    );
  }

  void _showEducationalInfoModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Color(0xFF2D2644),
            borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white38,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stock Market Basics',
                        style: Theme.of(context).textTheme.titleLarge!.copyWith(
                          fontSize: 26,
                          color: const Color(0xFFBE8BFF),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildSectionTitle('What is the Stock Market?'),
                      const Text(
                        'The stock market is a public marketplace where investors can buy and sell shares of publicly traded companies. It serves two main functions: it allows companies to raise capital for expansion, and it provides investors with an opportunity to share in the companies\' potential growth and profits.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 30),
                      _buildSectionTitle('Key Terms'),
                      _buildTermDefinition(
                        'Stock / Share',
                        'A unit of ownership in a company. When you buy a stock, you become a part-owner of that business.',
                      ),
                      _buildTermDefinition(
                        'Ticker Symbol',
                        'A short, unique, and memorable abbreviation used to identify a publicly traded stock (e.g., AAPL for Apple, GOOGL for Alphabet).',
                      ),
                      _buildTermDefinition(
                        'Market Cap (Market Capitalization)',
                        'The total value of a company\'s outstanding shares. Calculated by multiplying the current stock price by the total number of shares.',
                      ),
                      _buildTermDefinition(
                        'P/E Ratio (Price-to-Earnings Ratio)',
                        'A valuation measure that compares a company\'s current stock price to its earnings per share. A higher ratio generally suggests investors expect higher earnings growth.',
                      ),
                      _buildTermDefinition(
                        'Dividend',
                        'A portion of a company\'s profit paid out to its shareholders. Not all companies pay dividends.',
                      ),
                      _buildTermDefinition(
                        'Volatility',
                        'The degree of variation of a trading price over time. High volatility means the stock price can change rapidly over a short period.',
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(top: 10.0, bottom: 10.0),
    child: Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  Widget _buildTermDefinition(String term, String definition) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          term,
          style: const TextStyle(
            color: Color(0xFFAD81ED),
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          definition,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ],
    ),
  );

  Widget _buildDynamicContent() {
    if (_isLoading && _stockData.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: CircularProgressIndicator(color: Color(0xFFBE8BFF)),
        ),
      );
    }
    if (_errorMessage != null)
      return _buildMessage(Icons.error_outline, _errorMessage!);
    if (_stockData.isNotEmpty) return _buildStockChart();

    return Column(
      children: [
        _buildMessage(Icons.search, 'Search for a company '),
        const SizedBox(height: 10),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const double toolbarHeight = 56.0;
    const double preferredSearchHeight = 80.0;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: toolbarHeight,
        automaticallyImplyLeading: false,
        title: Row(
          children: const [
            Icon(Icons.attach_money, color: Color(0xFFBE8BFF), size: 36),
            SizedBox(width: 8),
            Text('StockMate'),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(preferredSearchHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search company',
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white54),
                  onPressed: () {
                    _searchController.clear();
                    _fetchStockData('');
                  },
                ),
              ),
              onSubmitted: (value) {
                setState(() {
                  _selectedRange = TimeRange.oneDay;
                });
                _fetchStockData(value);
              },
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(width: double.infinity, child: _buildDynamicContent()),
            const SizedBox(height: 24),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.6,
              children: [
                _buildActionButton(
                  context,
                  Icons.lightbulb_outline,
                  'INFO',
                  onTap: () => _showEducationalInfoModal(context),
                ),
                _buildActionButton(
                  context,
                  Icons.star_border,
                  'WISHLIST',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => WishlistPage(
                        wishlist: _wishlist,
                        onRemove: (symbol) {
                          setState(() {
                            _wishlist.removeWhere((e) => e['symbol'] == symbol);
                          });
                        },
                      ),
                    ),
                  ),
                ),
                _buildActionButton(
                  context,
                  Icons.shopping_bag_outlined,
                  'IPOS',
                  onTap: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => IPOListPage())),
                ),
                _buildActionButton(
                  context,
                  Icons.article_outlined,
                  'NEWS',
                  onTap: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const NewsPage())),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    IconData icon,
    String text, {
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: LinearGradient(
          colors: [
            Color.fromRGBO(106, 27, 154, 0.8),
            Color.fromRGBO(173, 129, 237, 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap:
              onTap ??
              () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$text functionality coming soon!')),
              ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 36),
              const SizedBox(height: 8),
              Text(text, style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1F1B2E),
        boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 10)],
      ),
      child: BottomNavigationBar(
        backgroundColor: Colors.transparent,
        selectedItemColor: const Color(0xFFBE8BFF),
        unselectedItemColor: Colors.white54,
        currentIndex: 0,
        onTap: (index) => ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Tapped index: $index'))),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            label: 'Portfolio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

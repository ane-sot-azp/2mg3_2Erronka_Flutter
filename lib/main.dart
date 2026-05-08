import 'dart:convert';
import 'dart:math';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_drawing/path_drawing.dart';
import 'package:xml/xml.dart';

final ValueNotifier<ThemeMode> _themeMode = ValueNotifier<ThemeMode>(
  ThemeMode.dark,
);

enum DishCategory { primeros, segundos, postres }

extension DishCategoryX on DishCategory {
  String get title {
    switch (this) {
      case DishCategory.primeros:
        return 'Lehenak';
      case DishCategory.segundos:
        return 'Bigarrenak';
      case DishCategory.postres:
        return 'Postreak';
    }
  }
}

class MenuDish {
  const MenuDish({
    required this.id,
    required this.name,
    required this.price,
    required this.type,
    required this.stock,
  });

  final int id;
  final String name;
  final double price;
  final String type;
  final int stock;
}

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String? _baseUrl;

  static const List<String> _baseUrlCandidates = <String>[
    'http://192.168.10.5:5005',
  ];

  Future<List<MenuDish>> fetchMenuDishes() async {
    final baseUrl = await _resolveBaseUrl();
    final uri = Uri.parse('$baseUrl/api/karta');
    final response = await _client
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 20));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'API errorea ${response.statusCode}: ${response.body.isEmpty ? 'gorputzik gabe' : response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    final list = _coerceToList(decoded);

    return list
        .map((e) => _parseDish(e))
        .whereType<MenuDish>()
        .toList(growable: false);
  }

  Future<String> _resolveBaseUrl() async {
    final cached = _baseUrl;
    if (cached != null) return cached;

    Object? lastError;
    for (final candidate in _baseUrlCandidates) {
      try {
        final uri = Uri.parse('$candidate/api/karta');
        final response = await _client
            .get(uri, headers: const {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 3));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          _baseUrl = candidate;
          return candidate;
        }
        lastError = 'helbidea=$candidate egoera=${response.statusCode}';
      } catch (e) {
        lastError = 'helbidea=$candidate errorea=$e';
      }
    }

    throw Exception('Ezin izan da APIarekin konektatu ($lastError)');
  }

  List<dynamic> _coerceToList(dynamic root) {
    if (root is List) return root;
    if (root is Map) {
      final data = root['data'];
      if (data is List) return data;
      final values = root[r'$values'];
      if (values is List) return values;
    }
    return const [];
  }

  MenuDish? _parseDish(dynamic raw) {
    if (raw is! Map) return null;

    int? readInt(String a, String b) {
      final v = raw[a] ?? raw[b];
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    double? readDouble(String a, String b) {
      final v = raw[a] ?? raw[b];
      if (v is double) return v;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    String readString(String a, String b) {
      final v = raw[a] ?? raw[b];
      return v?.toString().trim() ?? '';
    }

    final id = readInt('id', 'Id');
    final name = readString('izena', 'Izena');
    final price = readDouble('prezioa', 'Prezioa');
    final type = readString('kategoria', 'Kategoria');
    final stock = readInt('stock', 'Stock') ?? 0;

    if (id == null || price == null || name.isEmpty) return null;
    return MenuDish(id: id, name: name, price: price, type: type, stock: stock);
  }
}

DishCategory? classifyDishCategory(MenuDish dish) {
  final mota = dish.type.trim().toLowerCase();
  final name = dish.name.trim().toLowerCase();

  if (mota.contains('post')) return DishCategory.postres;
  if (mota.contains('bigarren') || mota.contains('segund')) {
    return DishCategory.segundos;
  }
  if (mota.contains('lehen') || mota.contains('primer')) {
    return DishCategory.primeros;
  }
  if (!mota.contains('plat')) return null;

  const secondKeywords = <String>[
    'lubina',
    'txuleta',
    'bakailao',
    'izokin',
    'olagarro',
    'gamba',
    'mejilloi',
    'txerri',
    'oilasko',
    'txipiroi',
  ];

  for (final kw in secondKeywords) {
    if (name.contains(kw)) return DishCategory.segundos;
  }
  return DishCategory.primeros;
}

void main() {
  runApp(const TournamentApp());
}

class TournamentApp extends StatelessWidget {
  const TournamentApp({super.key});

  static const Color _basqueDarkGreen = Color(0xFF0E1410);
  static const Color _basqueGreen = Color(0xFF0A6B3C);
  static const Color _basqueRed = Color(0xFFC8102E);
  static const Color _basqueWhite = Color(0xFFF5F0E6);
  static const Color _basqueNightSurface = Color(0xFF141A15);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Plateren txapelketa',
          themeMode: mode,
          theme: ThemeData(
            useMaterial3: false,
            brightness: Brightness.light,
            fontFamily: 'Inter',
            scaffoldBackgroundColor: _basqueWhite,
            colorScheme:
                ColorScheme.fromSeed(
                  seedColor: _basqueRed,
                  brightness: Brightness.light,
                ).copyWith(
                  primary: _basqueRed,
                  secondary: _basqueGreen,
                  surface: _basqueWhite,
                  onSurface: _basqueDarkGreen,
                  onPrimary: _basqueWhite,
                ),
            textTheme:
                const TextTheme(
                  headlineLarge: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    fontFamily: 'Playfair Display',
                    fontFamilyFallback: <String>['Georgia', 'serif'],
                  ),
                  headlineMedium: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    fontFamily: 'Playfair Display',
                    fontFamilyFallback: <String>['Georgia', 'serif'],
                  ),
                  titleLarge: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    fontFamily: 'Playfair Display',
                    fontFamilyFallback: <String>['Georgia', 'serif'],
                  ),
                  bodyMedium: TextStyle(fontSize: 15, letterSpacing: 0.2),
                ).apply(
                  bodyColor: _basqueDarkGreen,
                  displayColor: _basqueDarkGreen,
                ),
          ),
          darkTheme: ThemeData(
            useMaterial3: false,
            brightness: Brightness.dark,
            fontFamily: 'Inter',
            scaffoldBackgroundColor: _basqueDarkGreen,
            colorScheme:
                ColorScheme.fromSeed(
                  seedColor: _basqueRed,
                  brightness: Brightness.dark,
                ).copyWith(
                  primary: _basqueRed,
                  secondary: _basqueGreen,
                  surface: _basqueNightSurface,
                  onSurface: _basqueWhite,
                  onPrimary: _basqueWhite,
                ),
            textTheme: const TextTheme(
              headlineLarge: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                fontFamily: 'Playfair Display',
                fontFamilyFallback: <String>['Georgia', 'serif'],
              ),
              headlineMedium: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                fontFamily: 'Playfair Display',
                fontFamilyFallback: <String>['Georgia', 'serif'],
              ),
              titleLarge: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                fontFamily: 'Playfair Display',
                fontFamilyFallback: <String>['Georgia', 'serif'],
              ),
              bodyMedium: TextStyle(fontSize: 15, letterSpacing: 0.2),
            ).apply(bodyColor: _basqueWhite, displayColor: _basqueWhite),
          ),
          home: const IntroPage(
            basqueDarkGreen: _basqueDarkGreen,
            basqueGreen: _basqueGreen,
            basqueRed: _basqueRed,
            basqueWhite: _basqueWhite,
          ),
        );
      },
    );
  }
}

class IntroPage extends StatelessWidget {
  const IntroPage({
    super.key,
    required this.basqueDarkGreen,
    required this.basqueGreen,
    required this.basqueRed,
    required this.basqueWhite,
  });

  final Color basqueDarkGreen;
  final Color basqueGreen;
  final Color basqueRed;
  final Color basqueWhite;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = Theme.of(context).scaffoldBackgroundColor;
    final ink = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: _GameBackground(
                base: background,
                accentA: basqueGreen,
                accentB: basqueRed,
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: IconButton(
                onPressed: () {
                  _themeMode.value = isDark ? ThemeMode.light : ThemeMode.dark;
                },
                icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                color: ink,
                tooltip: isDark ? 'Egun modua' : 'Gau modua',
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Plateren txapelketa',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Aukeratu kategoria bat eta konparatu bi plater: sakatu gustukoena eta aurrera egin txapelketan. Azkenean irabazle bakarra geratuko da.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: ink.withValues(alpha: 0.80),
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        height: 54,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => CategorySelectionPage(
                                  basqueDarkGreen: basqueDarkGreen,
                                  basqueGreen: basqueGreen,
                                  basqueRed: basqueRed,
                                  basqueWhite: basqueWhite,
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: basqueRed,
                            foregroundColor: basqueWhite,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Hasi',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.1,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CategorySelectionPage extends StatelessWidget {
  const CategorySelectionPage({
    super.key,
    required this.basqueDarkGreen,
    required this.basqueGreen,
    required this.basqueRed,
    required this.basqueWhite,
  });

  final Color basqueDarkGreen;
  final Color basqueGreen;
  final Color basqueRed;
  final Color basqueWhite;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: _GameBackground(
                base: Theme.of(context).scaffoldBackgroundColor,
                accentA: basqueGreen,
                accentB: basqueRed,
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: IconButton(
                onPressed: () {
                  _themeMode.value = isDark ? ThemeMode.light : ThemeMode.dark;
                },
                icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                color: ink,
                tooltip: isDark ? 'Egun modua' : 'Gau modua',
              ),
            ),
            Column(
              children: [
                Expanded(
                  child: _CategoryBigButton(
                    title: DishCategory.primeros.title,
                    subtitle: 'Hasierakoak',
                    accent: basqueRed,
                    iconAsset: 'assets/android_icons/primero.xml',
                    onTap: () => _openCategory(context, DishCategory.primeros),
                  ),
                ),
                Expanded(
                  child: _CategoryBigButton(
                    title: DishCategory.segundos.title,
                    subtitle: 'Plater nagusiak',
                    accent: basqueGreen,
                    iconAsset: 'assets/android_icons/segundo.xml',
                    onTap: () => _openCategory(context, DishCategory.segundos),
                  ),
                ),
                Expanded(
                  child: _CategoryBigButton(
                    title: DishCategory.postres.title,
                    subtitle: 'Gozoak',
                    accent: basqueRed.withValues(alpha: 0.85),
                    iconAsset: 'assets/android_icons/postre.xml',
                    onTap: () => _openCategory(context, DishCategory.postres),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openCategory(BuildContext context, DishCategory category) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TournamentLoaderPage(
          category: category,
          basqueDarkGreen: basqueDarkGreen,
          basqueGreen: basqueGreen,
          basqueRed: basqueRed,
          basqueWhite: basqueWhite,
        ),
      ),
    );
  }
}

class _CategoryBigButton extends StatelessWidget {
  const _CategoryBigButton({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.iconAsset,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final String iconAsset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(24);
    final surface = Theme.of(context).colorScheme.surface;
    final ink = Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: _InteractiveScale(
        enabled: true,
        child: Material(
          color: surface,
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius,
            side: BorderSide(color: ink.withValues(alpha: 0.22), width: 1.4),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: borderRadius,
            splashColor: accent.withValues(alpha: 0.18),
            highlightColor: accent.withValues(alpha: 0.08),
            child: ClipRRect(
              borderRadius: borderRadius,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            surface,
                            accent.withValues(alpha: 0.10),
                            accent.withValues(alpha: 0.18),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AndroidVectorIcon(
                            assetPath: iconAsset,
                            color: ink.withValues(alpha: 0.92),
                            size: 72,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: ink.withValues(alpha: 0.75),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TournamentLoaderPage extends StatefulWidget {
  const TournamentLoaderPage({
    super.key,
    required this.category,
    required this.basqueDarkGreen,
    required this.basqueGreen,
    required this.basqueRed,
    required this.basqueWhite,
  });

  final DishCategory category;
  final Color basqueDarkGreen;
  final Color basqueGreen;
  final Color basqueRed;
  final Color basqueWhite;

  @override
  State<TournamentLoaderPage> createState() => _TournamentLoaderPageState();
}

class _TournamentLoaderPageState extends State<TournamentLoaderPage> {
  final ApiClient _api = ApiClient();
  List<MenuDish>? _dishes;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _dishes = null;
      _error = null;
    });

    try {
      final all = await _api.fetchMenuDishes();
      final filtered =
          all.where((d) => classifyDishCategory(d) == widget.category).toList()
            ..shuffle(Random());

      if (!mounted) return;
      setState(() {
        _dishes = filtered;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dishes = _dishes;
    final error = _error;

    if (error == null && dishes != null && dishes.length >= 2) {
      return TournamentPage(
        category: widget.category,
        dishes: dishes,
        basqueDarkGreen: widget.basqueDarkGreen,
        basqueGreen: widget.basqueGreen,
        basqueRed: widget.basqueRed,
        basqueWhite: widget.basqueWhite,
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: _GameBackground(
                base: Theme.of(context).scaffoldBackgroundColor,
                accentA: widget.basqueGreen,
                accentB: widget.basqueRed,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AnimatedBuilder(
                    animation: _themeMode,
                    builder: (context, _) {
                      final isDark = _themeMode.value == ThemeMode.dark;
                      return _TopBar(
                        basqueGreen: widget.basqueGreen,
                        basqueRed: widget.basqueRed,
                        title: widget.category.title,
                        onBack: () => Navigator.of(context).pop(),
                        isDarkMode: isDark,
                        onToggleDarkMode: () {
                          _themeMode.value = isDark
                              ? ThemeMode.light
                              : ThemeMode.dark;
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  if (error != null)
                    Expanded(
                      child: _ErrorView(
                        message: error,
                        accent: widget.basqueGreen,
                        onRetry: _load,
                      ),
                    )
                  else if (dishes == null)
                    Expanded(
                      child: _LoadingView(
                        accent: widget.basqueGreen,
                        basqueRed: widget.basqueRed,
                      ),
                    )
                  else if (dishes.length < 2)
                    Expanded(
                      child: _ErrorView(
                        message:
                            'Ez dago nahikoa plater kategoria honetan txapelketa sortzeko.',
                        accent: widget.basqueRed,
                        onRetry: _load,
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.accent, required this.basqueRed});

  final Color accent;
  final Color basqueRed;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final ink = Theme.of(context).colorScheme.onSurface;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.35, end: 0.85),
          duration: const Duration(milliseconds: 1100),
          curve: Curves.easeInOut,
          builder: (context, t, child) {
            final alpha = (0.35 + (sin(t * pi * 2) + 1) * 0.25).clamp(
              0.25,
              0.85,
            );
            return Container(
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: ink.withValues(alpha: 0.18),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: basqueRed.withValues(alpha: 0.08),
                    blurRadius: 26,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: 0.14),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.55),
                        width: 1.2,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          accent.withValues(alpha: 0.95),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Platerak kargatzen...',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SkeletonLine(
                    widthFactor: 0.92,
                    height: 14,
                    color: ink.withValues(alpha: alpha * 0.20),
                  ),
                  const SizedBox(height: 8),
                  _SkeletonLine(
                    widthFactor: 0.78,
                    height: 14,
                    color: ink.withValues(alpha: alpha * 0.18),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: ink.withValues(alpha: 0.06),
                    ),
                    child: Column(
                      children: [
                        _SkeletonLine(
                          widthFactor: 0.96,
                          height: 16,
                          color: ink.withValues(alpha: alpha * 0.18),
                        ),
                        const SizedBox(height: 10),
                        _SkeletonLine(
                          widthFactor: 0.66,
                          height: 16,
                          color: ink.withValues(alpha: alpha * 0.14),
                        ),
                        const SizedBox(height: 12),
                        _SkeletonLine(
                          widthFactor: 0.88,
                          height: 12,
                          color: ink.withValues(alpha: alpha * 0.12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({
    required this.widthFactor,
    required this.height,
    required this.color,
  });

  final double widthFactor;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor.clamp(0.1, 1.0),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.accent,
    required this.onRetry,
  });

  final String message;
  final Color accent;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final ink = Theme.of(context).colorScheme.onSurface;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: ink.withValues(alpha: 0.18), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.10),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.14),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.55),
                    width: 1.2,
                  ),
                ),
                child: Icon(Icons.error_outline, color: accent, size: 36),
              ),
              const SizedBox(height: 14),
              Text(
                'Arazo bat gertatu da',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: ink.withValues(alpha: 0.85),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Saiatu berriro',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InteractiveScale extends StatefulWidget {
  const _InteractiveScale({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  State<_InteractiveScale> createState() => _InteractiveScaleState();
}

class _InteractiveScaleState extends State<_InteractiveScale> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final scale = widget.enabled && _hovering ? 1.02 : 1.0;

    return MouseRegion(
      onEnter: widget.enabled
          ? (_) => setState(() {
              _hovering = true;
            })
          : null,
      onExit: widget.enabled
          ? (_) => setState(() {
              _hovering = false;
            })
          : null,
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

class _GameBackground extends StatelessWidget {
  const _GameBackground({
    required this.base,
    required this.accentA,
    required this.accentB,
  });

  final Color base;
  final Color accentA;
  final Color accentB;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GameBackgroundPainter(
        base: base,
        accentA: accentA,
        accentB: accentB,
      ),
    );
  }
}

class _GameBackgroundPainter extends CustomPainter {
  _GameBackgroundPainter({
    required this.base,
    required this.accentA,
    required this.accentB,
  });

  final Color base;
  final Color accentA;
  final Color accentB;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        base,
        Color.lerp(base, accentA, 0.12) ?? base,
        Color.lerp(base, accentB, 0.10) ?? base,
      ],
      stops: const [0.0, 0.55, 1.0],
    );

    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));

    final glowPaint = Paint()..style = PaintingStyle.fill;
    glowPaint.color = accentA.withValues(alpha: 0.10);
    canvas.drawCircle(
      Offset(size.width * 0.22, size.height * 0.16),
      size.shortestSide * 0.34,
      glowPaint,
    );
    glowPaint.color = accentB.withValues(alpha: 0.10);
    canvas.drawCircle(
      Offset(size.width * 0.86, size.height * 0.18),
      size.shortestSide * 0.30,
      glowPaint,
    );

    final dotPaint = Paint()..style = PaintingStyle.fill;
    dotPaint.color = Colors.white.withValues(alpha: 0.03);
    canvas.drawCircle(
      Offset(size.width * 0.18, size.height * 0.22),
      size.shortestSide * 0.16,
      dotPaint,
    );
    dotPaint.color = Colors.white.withValues(alpha: 0.025);
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.18),
      size.shortestSide * 0.14,
      dotPaint,
    );
    dotPaint.color = Colors.white.withValues(alpha: 0.02);
    canvas.drawCircle(
      Offset(size.width * 0.72, size.height * 0.78),
      size.shortestSide * 0.20,
      dotPaint,
    );

    final stripePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.02)
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.square;

    const step = 42.0;
    for (double x = -size.height; x < size.width + size.height; x += step) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        stripePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GameBackgroundPainter oldDelegate) {
    return oldDelegate.base != base ||
        oldDelegate.accentA != accentA ||
        oldDelegate.accentB != accentB;
  }
}

class TournamentPage extends StatefulWidget {
  const TournamentPage({
    super.key,
    required this.category,
    required this.dishes,
    required this.basqueDarkGreen,
    required this.basqueGreen,
    required this.basqueRed,
    required this.basqueWhite,
  });

  final DishCategory category;
  final List<MenuDish> dishes;
  final Color basqueDarkGreen;
  final Color basqueGreen;
  final Color basqueRed;
  final Color basqueWhite;

  @override
  State<TournamentPage> createState() => _TournamentPageState();
}

class _TournamentPageState extends State<TournamentPage> {
  final Random _rng = Random();
  late final List<MenuDish> _initialDishes;
  late List<MenuDish> _remainingDishes;
  MenuDish? _champion;
  MenuDish? _challenger;
  bool _isFirstRound = true;
  int _currentRound = 1;
  int _totalRounds = 1;

  bool get _isFinished => _champion != null && _challenger == null;

  @override
  void initState() {
    super.initState();
    _initialDishes = List<MenuDish>.from(widget.dishes);
    _resetTournament();
  }

  void _resetTournament() {
    setState(() {
      _isFirstRound = true;
      _currentRound = 1;
      _totalRounds = max(1, _initialDishes.length - 1);
      _remainingDishes = List<MenuDish>.from(_initialDishes)..shuffle(_rng);
      _champion = _remainingDishes.isNotEmpty
          ? _remainingDishes.removeAt(0)
          : null;
      _challenger = _remainingDishes.isNotEmpty
          ? _remainingDishes.removeAt(0)
          : null;
    });
  }

  void _pick({required bool championWins}) {
    final champion = _champion;
    final challenger = _challenger;
    if (champion == null || challenger == null) return;

    final isFinalPick = _remainingDishes.isEmpty;
    setState(() {
      _isFirstRound = false;
      _champion = championWins ? champion : challenger;
      _challenger = _remainingDishes.isNotEmpty
          ? _remainingDishes.removeAt(0)
          : null;
      _currentRound = isFinalPick ? _totalRounds : (_currentRound + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final champion = _champion;
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 450),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: _isFinished
              ? _WinnerView(
                  key: const ValueKey('winner'),
                  winner: champion!,
                  basqueDarkGreen: widget.basqueDarkGreen,
                  basqueGreen: widget.basqueGreen,
                  basqueRed: widget.basqueRed,
                  basqueWhite: widget.basqueWhite,
                  currentRound: _totalRounds,
                  totalRounds: _totalRounds,
                  onRestart: _resetTournament,
                  onBackToCategories: () => Navigator.of(context).pop(),
                )
              : _BattleView(
                  key: const ValueKey('battle'),
                  title: widget.category.title,
                  onBackToCategories: () => Navigator.of(context).pop(),
                  champion: _champion,
                  challenger: _challenger,
                  isFirstRound: _isFirstRound,
                  basqueDarkGreen: widget.basqueDarkGreen,
                  basqueGreen: widget.basqueGreen,
                  basqueRed: widget.basqueRed,
                  currentRound: _currentRound,
                  totalRounds: _totalRounds,
                  onPickChampion: () => _pick(championWins: true),
                  onPickChallenger: () => _pick(championWins: false),
                ),
        ),
      ),
    );
  }
}

class _BattleView extends StatelessWidget {
  const _BattleView({
    super.key,
    required this.title,
    required this.onBackToCategories,
    required this.champion,
    required this.challenger,
    required this.isFirstRound,
    required this.basqueDarkGreen,
    required this.basqueGreen,
    required this.basqueRed,
    required this.currentRound,
    required this.totalRounds,
    required this.onPickChampion,
    required this.onPickChallenger,
  });

  final String title;
  final VoidCallback onBackToCategories;
  final MenuDish? champion;
  final MenuDish? challenger;
  final bool isFirstRound;
  final Color basqueDarkGreen;
  final Color basqueGreen;
  final Color basqueRed;
  final int currentRound;
  final int totalRounds;
  final VoidCallback onPickChampion;
  final VoidCallback onPickChallenger;

  @override
  Widget build(BuildContext context) {
    final championData = champion;
    final challengerData = challenger;
    const foreground = Color(0xFFF5F0E6);
    final progress = totalRounds <= 0 ? 0.0 : (currentRound / totalRounds);

    return ColoredBox(
      color: basqueDarkGreen,
      child: Stack(
        children: [
          Positioned.fill(
            child: _GameBackground(
              base: basqueDarkGreen,
              accentA: basqueGreen,
              accentB: basqueRed,
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 760;

                    final top = _TopBar(
                      basqueGreen: basqueGreen,
                      basqueRed: basqueRed,
                      title: title,
                      onBack: onBackToCategories,
                      foregroundColor: foreground,
                      badgeText: 'TXANDA $currentRound/$totalRounds',
                      isDarkMode: _themeMode.value == ThemeMode.dark,
                      onToggleDarkMode: () {
                        final isDark = _themeMode.value == ThemeMode.dark;
                        _themeMode.value = isDark
                            ? ThemeMode.light
                            : ThemeMode.dark;
                      },
                    );

                    if (!isWide) {
                      return Column(
                        children: [
                          top,
                          const SizedBox(height: 12),
                          _RoundProgressBar(
                            progress: progress.clamp(0.0, 1.0),
                            ink: foreground,
                            accent: basqueRed,
                          ),
                          const SizedBox(height: 14),
                          Expanded(
                            child: _GameCard(
                              title: championData?.name ?? '—',
                              price: championData?.price,
                              accent: basqueRed,
                              subtitle: isFirstRound ? 'AUKERA 1' : 'TXAPELDUN',
                              onTap: championData == null
                                  ? null
                                  : onPickChampion,
                            ),
                          ),
                          _VsSeparator(ink: foreground, basqueRed: basqueRed),
                          Expanded(
                            child: _GameCard(
                              title: challengerData?.name ?? '—',
                              price: challengerData?.price,
                              accent: basqueGreen,
                              subtitle: isFirstRound
                                  ? 'AUKERA 2'
                                  : 'ERRONKARIA',
                              onTap: challengerData == null
                                  ? null
                                  : onPickChallenger,
                            ),
                          ),
                        ],
                      );
                    }

                    return Column(
                      children: [
                        top,
                        const SizedBox(height: 12),
                        _RoundProgressBar(
                          progress: progress.clamp(0.0, 1.0),
                          ink: foreground,
                          accent: basqueRed,
                        ),
                        const SizedBox(height: 18),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: _GameCard(
                                  title: championData?.name ?? '—',
                                  price: championData?.price,
                                  accent: basqueRed,
                                  subtitle: isFirstRound
                                      ? 'AUKERA 1'
                                      : 'TXAPELDUN',
                                  onTap: championData == null
                                      ? null
                                      : onPickChampion,
                                ),
                              ),
                              const SizedBox(width: 16),
                              _VsBadge(ink: foreground, basqueRed: basqueRed),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _GameCard(
                                  title: challengerData?.name ?? '—',
                                  price: challengerData?.price,
                                  accent: basqueGreen,
                                  subtitle: isFirstRound
                                      ? 'AUKERA 2'
                                      : 'ERRONKARIA',
                                  onTap: challengerData == null
                                      ? null
                                      : onPickChallenger,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.basqueGreen,
    required this.basqueRed,
    required this.title,
    this.onBack,
    this.foregroundColor,
    this.badgeText,
    this.isDarkMode,
    this.onToggleDarkMode,
  });

  final Color basqueGreen;
  final Color basqueRed;
  final String title;
  final VoidCallback? onBack;
  final Color? foregroundColor;
  final String? badgeText;
  final bool? isDarkMode;
  final VoidCallback? onToggleDarkMode;

  @override
  Widget build(BuildContext context) {
    final ink = foregroundColor ?? Theme.of(context).colorScheme.onSurface;
    final barColor = ink.withValues(alpha: 0.06);
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: barColor,
            border: Border.all(color: ink.withValues(alpha: 0.16), width: 1),
          ),
          child: Row(
            children: [
              if (onBack != null) ...[
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                  color: ink,
                  tooltip: 'Itzuli',
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: ink,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badgeText != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: ink.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: ink.withValues(alpha: 0.22),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    badgeText!,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: ink,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              if (isDarkMode != null && onToggleDarkMode != null) ...[
                IconButton(
                  onPressed: onToggleDarkMode,
                  icon: Icon(isDarkMode! ? Icons.light_mode : Icons.dark_mode),
                  color: ink,
                  tooltip: isDarkMode! ? 'Egun modua' : 'Gau modua',
                ),
                const SizedBox(width: 2),
              ],
              _FlagMark(basqueGreen: basqueGreen, basqueRed: basqueRed),
            ],
          ),
        ),
      ),
    );
  }
}

class _VsSeparator extends StatelessWidget {
  const _VsSeparator({required this.ink, required this.basqueRed});

  final Color ink;
  final Color basqueRed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(color: ink.withValues(alpha: 0.35)),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'AURKA',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: basqueRed,
              letterSpacing: 2.4,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(color: ink.withValues(alpha: 0.35)),
            ),
          ),
        ],
      ),
    );
  }
}

class _VsBadge extends StatelessWidget {
  const _VsBadge({required this.ink, required this.basqueRed});

  final Color ink;
  final Color basqueRed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              width: 1,
              decoration: BoxDecoration(color: ink.withValues(alpha: 0.25)),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'AURKA',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: basqueRed,
              letterSpacing: 2.6,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              width: 1,
              decoration: BoxDecoration(color: ink.withValues(alpha: 0.25)),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({
    required this.title,
    required this.price,
    required this.accent,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final double? price;
  final Color accent;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final borderRadius = BorderRadius.circular(22);
    final surface = Theme.of(context).colorScheme.surface;
    final ink = Theme.of(context).colorScheme.onSurface;

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: _InteractiveScale(
        enabled: enabled,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.14),
                      blurRadius: 28,
                      offset: const Offset(0, 18),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: surface,
            shape: RoundedRectangleBorder(
              borderRadius: borderRadius,
              side: BorderSide(color: ink.withValues(alpha: 0.25), width: 1.6),
            ),
            child: InkWell(
              onTap: onTap,
              borderRadius: borderRadius,
              splashColor: accent.withValues(alpha: 0.16),
              highlightColor: accent.withValues(alpha: 0.06),
              child: ClipRRect(
                borderRadius: borderRadius,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              surface,
                              accent.withValues(alpha: 0.08),
                              accent.withValues(alpha: 0.16),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: accent.withValues(alpha: 0.55),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  subtitle,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(
                                        color: ink.withValues(alpha: 0.9),
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.0,
                                      ),
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                enabled ? Icons.touch_app : Icons.restaurant,
                                color: accent.withValues(alpha: 0.78),
                                size: 22,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Expanded(
                            child: Center(
                              child: Text(
                                title,
                                textAlign: TextAlign.center,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      color: ink,
                                      letterSpacing: 0.8,
                                      height: 1.10,
                                    ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: ink.withValues(alpha: 0.06),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  'Prezioa',
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(
                                        color: ink.withValues(alpha: 0.65),
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.4,
                                      ),
                                ),
                                const Spacer(),
                                Text(
                                  price == null
                                      ? '—'
                                      : '${price!.toStringAsFixed(2)} €',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        color: ink,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.6,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (enabled)
                            Text(
                              'Sakatu aukeratzeko',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: ink.withValues(alpha: 0.72),
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.2,
                                  ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundProgressBar extends StatelessWidget {
  const _RoundProgressBar({
    required this.progress,
    required this.ink,
    required this.accent,
  });

  final double progress;
  final Color ink;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 12,
      decoration: BoxDecoration(
        color: ink.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ink.withValues(alpha: 0.18), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Align(
        alignment: Alignment.centerLeft,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
          width:
              (MediaQuery.of(context).size.width * 0.78).clamp(180.0, 860.0) *
              progress,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accent.withValues(alpha: 0.85), accent],
            ),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

class _WinnerView extends StatefulWidget {
  const _WinnerView({
    super.key,
    required this.winner,
    required this.basqueDarkGreen,
    required this.basqueGreen,
    required this.basqueRed,
    required this.basqueWhite,
    required this.currentRound,
    required this.totalRounds,
    required this.onRestart,
    required this.onBackToCategories,
  });

  final MenuDish winner;
  final Color basqueDarkGreen;
  final Color basqueGreen;
  final Color basqueRed;
  final Color basqueWhite;
  final int currentRound;
  final int totalRounds;
  final VoidCallback onRestart;
  final VoidCallback onBackToCategories;

  @override
  State<_WinnerView> createState() => _WinnerViewState();
}

class _WinnerViewState extends State<_WinnerView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _confettiController;
  late final List<_ConfettiPiece> _confettiPieces;

  @override
  void initState() {
    super.initState();
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..forward();

    final rng = Random(42);
    _confettiPieces = List<_ConfettiPiece>.generate(110, (i) {
      return _ConfettiPiece(
        x: rng.nextDouble(),
        y0: -0.2 - rng.nextDouble() * 1.2,
        speed: 0.7 + rng.nextDouble() * 1.0,
        size: 6 + rng.nextDouble() * 10,
        rotation0: rng.nextDouble() * pi * 2,
        rotationSpeed: (-1 + rng.nextDouble() * 2) * 6,
        drift: (-1 + rng.nextDouble() * 2) * 0.18,
        colorIndex: rng.nextInt(5),
        isCircle: rng.nextBool(),
      );
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final winnerName = widget.winner.name;
    final winnerPrice = widget.winner.price;
    final ink = Theme.of(context).colorScheme.onSurface;

    final confettiColors = <Color>[
      widget.basqueRed,
      widget.basqueGreen,
      widget.basqueDarkGreen,
      const Color(0xFF171A17),
      widget.basqueWhite,
    ];

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Stack(
        children: [
          Positioned.fill(
            child: _GameBackground(
              base: widget.basqueWhite,
              accentA: widget.basqueGreen,
              accentB: widget.basqueRed,
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final cardMaxWidth = constraints.maxWidth >= 760
                        ? 620.0
                        : 520.0;

                    return Stack(
                      children: [
                        Positioned.fill(
                          child: IgnorePointer(
                            child: AnimatedBuilder(
                              animation: _confettiController,
                              builder: (context, _) {
                                return CustomPaint(
                                  painter: _ConfettiPainter(
                                    progress: _confettiController.value,
                                    pieces: _confettiPieces,
                                    colors: confettiColors,
                                  ),
                                  child: const SizedBox.expand(),
                                );
                              },
                            ),
                          ),
                        ),
                        Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: cardMaxWidth),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(26),
                                border: Border.all(
                                  color: ink.withValues(alpha: 0.25),
                                  width: 1.4,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: widget.basqueRed.withValues(
                                      alpha: 0.10,
                                    ),
                                    blurRadius: 26,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.fromLTRB(
                                18,
                                18,
                                18,
                                18,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _TopBar(
                                    basqueGreen: widget.basqueGreen,
                                    basqueRed: widget.basqueRed,
                                    title: 'IRABAZLEA',
                                    badgeText:
                                        'FINALA ${widget.currentRound}/${widget.totalRounds}',
                                    isDarkMode:
                                        _themeMode.value == ThemeMode.dark,
                                    onToggleDarkMode: () {
                                      final isDark =
                                          _themeMode.value == ThemeMode.dark;
                                      _themeMode.value = isDark
                                          ? ThemeMode.light
                                          : ThemeMode.dark;
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0.90, end: 1),
                                    duration: const Duration(milliseconds: 700),
                                    curve: Curves.easeOutBack,
                                    builder: (context, value, child) {
                                      return Transform.scale(
                                        scale: value,
                                        child: child,
                                      );
                                    },
                                    child: _WinnerImage(
                                      basqueWhite: widget.basqueWhite,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    winnerName,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(
                                          color: const Color.fromARGB(
                                            255,
                                            255,
                                            255,
                                            255,
                                          ),
                                          letterSpacing: 0.9,
                                        ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    '${winnerPrice.toStringAsFixed(2)} €',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          color: ink.withValues(alpha: 0.78),
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.8,
                                        ),
                                  ),
                                  const SizedBox(height: 18),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: ElevatedButton(
                                      onPressed: widget.onRestart,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: widget.basqueGreen,
                                        foregroundColor: widget.basqueWhite,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: const Text(
                                        'Berrabiarazi',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: OutlinedButton(
                                      onPressed: widget.onBackToCategories,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(
                                          0xFF171A17,
                                        ),
                                        side: BorderSide(
                                          color: widget.basqueRed,
                                          width: 1.6,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'Itzuli menura',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.0,
                                          color: const Color.fromARGB(
                                            255,
                                            255,
                                            255,
                                            255,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WinnerImage extends StatelessWidget {
  const _WinnerImage({required this.basqueWhite});

  final Color basqueWhite;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final borderRadius = BorderRadius.circular(26);
        final maxW = constraints.maxWidth.isFinite ? constraints.maxWidth : 420;
        final width = min(
          420.0,
          maxW.toDouble(),
        ).clamp(240.0, 420.0).toDouble();
        final height = width * 0.68;

        return SizedBox(
          width: width,
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              border: Border.all(color: const Color(0xFF232B25), width: 1.2),
            ),
            child: ClipRRect(
              borderRadius: borderRadius,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.03),
                            Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.14),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Icon(
                      Icons.emoji_events,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.85),
                      size: width * 0.28,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FlagMark extends StatelessWidget {
  const _FlagMark({required this.basqueGreen, required this.basqueRed});

  final Color basqueGreen;
  final Color basqueRed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 28,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0E6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF232B25), width: 1.2),
      ),
      padding: const EdgeInsets.all(3),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Row(
          children: [
            Expanded(child: ColoredBox(color: basqueGreen)),
            const Expanded(child: ColoredBox(color: Color(0xFFF5F0E6))),
            Expanded(child: ColoredBox(color: basqueRed)),
          ],
        ),
      ),
    );
  }
}

class AndroidVectorIcon extends StatelessWidget {
  const AndroidVectorIcon({
    super.key,
    required this.assetPath,
    required this.color,
    required this.size,
  });

  final String assetPath;
  final Color color;
  final double size;

  static final Map<String, Future<_AndroidVectorData>> _cache =
      <String, Future<_AndroidVectorData>>{};

  @override
  Widget build(BuildContext context) {
    final future = _cache[assetPath] ??= _AndroidVectorData.load(
      assetPath: assetPath,
    );

    return FutureBuilder<_AndroidVectorData>(
      future: future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) return SizedBox(width: size, height: size);

        return CustomPaint(
          size: Size.square(size),
          painter: _AndroidVectorPainter(data: data, color: color),
        );
      },
    );
  }
}

class _AndroidVectorData {
  const _AndroidVectorData({
    required this.viewportWidth,
    required this.viewportHeight,
    required this.paths,
  });

  final double viewportWidth;
  final double viewportHeight;
  final List<Path> paths;

  static Future<_AndroidVectorData> load({required String assetPath}) async {
    final xmlText = await rootBundle.loadString(assetPath);
    final doc = XmlDocument.parse(xmlText);
    final root = doc.rootElement;

    double readDoubleAttr(XmlElement el, String name, {double fallback = 0}) {
      final attr = el.attributes
          .cast<XmlAttribute?>()
          .firstWhere(
            (a) => a != null && a.name.local == name,
            orElse: () => null,
          )
          ?.value;
      if (attr == null) return fallback;
      return double.tryParse(attr) ?? fallback;
    }

    final viewportWidth = readDoubleAttr(root, 'viewportWidth', fallback: 24);
    final viewportHeight = readDoubleAttr(root, 'viewportHeight', fallback: 24);
    final paths = <Path>[];

    void parseElement(XmlElement el, Matrix4 transform) {
      if (el.name.local == 'group') {
        final next = Matrix4.copy(transform);
        final tx = readDoubleAttr(el, 'translateX', fallback: 0);
        final ty = readDoubleAttr(el, 'translateY', fallback: 0);
        final sx = readDoubleAttr(el, 'scaleX', fallback: 1);
        final sy = readDoubleAttr(el, 'scaleY', fallback: 1);
        next.translate(tx, ty);
        next.scale(sx, sy);
        for (final c in el.childElements) {
          parseElement(c, next);
        }
        return;
      }

      if (el.name.local == 'path') {
        final pathData = el.attributes
            .cast<XmlAttribute?>()
            .firstWhere(
              (a) => a != null && a.name.local == 'pathData',
              orElse: () => null,
            )
            ?.value;
        if (pathData == null || pathData.isEmpty) return;
        final p = parseSvgPathData(pathData);
        final tp = p.transform(transform.storage);
        paths.add(tp);
      }

      for (final c in el.childElements) {
        parseElement(c, transform);
      }
    }

    for (final child in root.childElements) {
      parseElement(child, Matrix4.identity());
    }

    return _AndroidVectorData(
      viewportWidth: viewportWidth,
      viewportHeight: viewportHeight,
      paths: paths,
    );
  }
}

class _AndroidVectorPainter extends CustomPainter {
  _AndroidVectorPainter({required this.data, required this.color});

  final _AndroidVectorData data;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final vw = data.viewportWidth;
    final vh = data.viewportHeight;
    if (vw <= 0 || vh <= 0) return;

    final scale = min(size.width / vw, size.height / vh);
    final dx = (size.width - vw * scale) / 2;
    final dy = (size.height - vh * scale) / 2;

    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale, scale);

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = color;

    for (final p in data.paths) {
      canvas.drawPath(p, paint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AndroidVectorPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.color != color;
  }
}

class _ConfettiPiece {
  const _ConfettiPiece({
    required this.x,
    required this.y0,
    required this.speed,
    required this.size,
    required this.rotation0,
    required this.rotationSpeed,
    required this.drift,
    required this.colorIndex,
    required this.isCircle,
  });

  final double x;
  final double y0;
  final double speed;
  final double size;
  final double rotation0;
  final double rotationSpeed;
  final double drift;
  final int colorIndex;
  final bool isCircle;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({
    required this.progress,
    required this.pieces,
    required this.colors,
  });

  final double progress;
  final List<_ConfettiPiece> pieces;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final t = Curves.easeOutCubic.transform(progress);
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in pieces) {
      final y01 = p.y0 + t * p.speed * 1.6;
      if (y01 < -0.25 || y01 > 1.15) continue;

      final x01 =
          p.x +
          sin((t * 2.2 * pi) + p.rotation0) * p.drift +
          (t * 0.04 * p.drift);

      final x = x01 * size.width;
      final y = y01 * size.height;
      final rot = p.rotation0 + t * p.rotationSpeed;

      paint.color = colors[p.colorIndex % colors.length].withValues(
        alpha: 0.95,
      );

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rot);

      if (p.isCircle) {
        canvas.drawCircle(Offset.zero, p.size * 0.45, paint);
      } else {
        final r = Rect.fromCenter(
          center: Offset.zero,
          width: p.size,
          height: p.size * 0.55,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(r, Radius.circular(p.size * 0.22)),
          paint,
        );
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.pieces != pieces ||
        oldDelegate.colors != colors;
  }
}

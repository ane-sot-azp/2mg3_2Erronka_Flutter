import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

enum DishCategory { primeros, segundos, postres }

extension DishCategoryX on DishCategory {
  String get title {
    switch (this) {
      case DishCategory.primeros:
        return 'Primeros';
      case DishCategory.segundos:
        return 'Segundos';
      case DishCategory.postres:
        return 'Postres';
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
    'http://192.168.10.55:5000/api',
    'http://localhost:5000/api',
    'http://127.0.0.1:5000/api',
  ];

  Future<List<MenuDish>> fetchMenuDishes() async {
    final baseUrl = await _resolveBaseUrl();
    final uri = Uri.parse('$baseUrl/Produktuak');
    final response = await _client
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 10));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'API error ${response.statusCode}: ${response.body.isEmpty ? 'sin cuerpo' : response.body}',
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
        final uri = Uri.parse('$candidate/Produktuak');
        final response = await _client
            .get(uri, headers: const {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 3));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          _baseUrl = candidate;
          return candidate;
        }
        lastError = 'status=${response.statusCode}';
      } catch (e) {
        lastError = e;
      }
    }

    throw Exception('No se pudo conectar a la API ($lastError)');
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
    final type = readString('mota', 'Mota');
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Campeonato de platos',
      builder: (context, child) {
        return _PhoneViewport(child: child ?? const SizedBox.shrink());
      },
      theme: ThemeData(
        useMaterial3: false,
        brightness: Brightness.light,
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
        textTheme: TextTheme(
          headlineLarge: TextStyle(
            color: _basqueDarkGreen,
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
          headlineMedium: TextStyle(
            color: _basqueDarkGreen,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
          titleLarge: TextStyle(
            color: _basqueDarkGreen,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
          bodyMedium: TextStyle(
            color: _basqueDarkGreen,
            fontSize: 15,
            letterSpacing: 0.2,
          ),
        ),
      ),
      home: const CategorySelectionPage(
        basqueDarkGreen: _basqueDarkGreen,
        basqueGreen: _basqueGreen,
        basqueRed: _basqueRed,
        basqueWhite: _basqueWhite,
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
    return Scaffold(
      body: SafeArea(
        child: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TopBar(
                basqueGreen: basqueGreen,
                basqueRed: basqueRed,
                title: 'Campeonato de platos',
              ),
              const SizedBox(height: 24),
              Text(
                'Elige una categoría',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              Text(
                'El torneo se hace entre platos de la misma categoría.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: ListView(
                  children: [
                    SizedBox(
                      height: 116,
                      child: _CategoryCard(
                        title: DishCategory.primeros.title,
                        subtitle: 'Entrantes y platos ligeros',
                        accent: basqueRed,
                        icon: Icons.restaurant_menu,
                        onTap: () =>
                            _openCategory(context, DishCategory.primeros),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 116,
                      child: _CategoryCard(
                        title: DishCategory.segundos.title,
                        subtitle: 'Carnes, pescados y platos fuertes',
                        accent: basqueGreen,
                        icon: Icons.local_fire_department,
                        onTap: () =>
                            _openCategory(context, DishCategory.segundos),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 116,
                      child: _CategoryCard(
                        title: DishCategory.postres.title,
                        subtitle: 'Dulces y postres',
                        accent: basqueWhite,
                        icon: Icons.icecream,
                        onTap: () =>
                            _openCategory(context, DishCategory.postres),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(22);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.25),
            width: 1.6,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Row(
            children: [
              Container(
                width: 6,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 14),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.12),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.25),
                  ),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ],
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
        child: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TopBar(
                basqueGreen: widget.basqueGreen,
                basqueRed: widget.basqueRed,
                title: widget.category.title,
                onBack: () => Navigator.of(context).pop(),
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
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (dishes.length < 2)
                Expanded(
                  child: _ErrorView(
                    message:
                        'No hay suficientes platos en esta categoría para crear un torneo.',
                    accent: widget.basqueRed,
                    onRetry: _load,
                  ),
                )
              else
                const SizedBox.shrink(),
            ],
          ),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: accent, size: 44),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.85),
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: 220,
            height: 46,
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
                'Reintentar',
                style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhoneViewport extends StatelessWidget {
  const _PhoneViewport({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        if (maxWidth < 600) return child;

        const phoneAspect = 9 / 18.5;
        const maxPhoneWidth = 520.0;

        final availableWidth = maxWidth;
        final availableHeight = constraints.maxHeight;

        double targetWidth = availableWidth.clamp(0.0, maxPhoneWidth);
        double targetHeight = targetWidth / phoneAspect;

        if (targetHeight > availableHeight) {
          targetHeight = availableHeight;
          targetWidth = targetHeight * phoneAspect;
        }

        final radius = BorderRadius.circular(30);
        final accent = Theme.of(context).colorScheme.secondary;

        return ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Center(
            child: Container(
              width: targetWidth,
              height: targetHeight,
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(
                  color: accent.withValues(alpha: 0.25),
                  width: 1.4,
                ),
              ),
              child: ClipRRect(borderRadius: radius, child: child),
            ),
          ),
        );
      },
    );
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

    setState(() {
      _isFirstRound = false;
      _champion = championWins ? champion : challenger;
      _challenger = _remainingDishes.isNotEmpty
          ? _remainingDishes.removeAt(0)
          : null;
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
  final VoidCallback onPickChampion;
  final VoidCallback onPickChallenger;

  @override
  Widget build(BuildContext context) {
    final championData = champion;
    final challengerData = challenger;

    return Container(
      color: basqueDarkGreen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: Column(
          children: [
            _TopBar(
              basqueGreen: basqueGreen,
              basqueRed: basqueRed,
              title: title,
              onBack: onBackToCategories,
            ),
            const SizedBox(height: 14),
            Expanded(
              child: _GameCard(
                title: championData?.name ?? '—',
                price: championData?.price,
                accent: basqueRed,
                subtitle: isFirstRound ? 'OPCIÓN 1' : 'CAMPEÓN',
                onTap: championData == null ? null : onPickChampion,
              ),
            ),
            _VsSeparator(basqueGreen: basqueGreen, basqueRed: basqueRed),
            Expanded(
              child: _GameCard(
                title: challengerData?.name ?? '—',
                price: challengerData?.price,
                accent: basqueGreen,
                subtitle: isFirstRound ? 'OPCIÓN 2' : 'RETADOR',
                onTap: challengerData == null ? null : onPickChallenger,
              ),
            ),
          ],
        ),
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
  });

  final Color basqueGreen;
  final Color basqueRed;
  final String title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onBack != null) ...[
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back),
            color: Theme.of(context).colorScheme.onSurface,
            tooltip: 'Volver',
          ),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        _FlagMark(basqueGreen: basqueGreen, basqueRed: basqueRed),
      ],
    );
  }
}

class _VsSeparator extends StatelessWidget {
  const _VsSeparator({required this.basqueGreen, required this.basqueRed});

  final Color basqueGreen;
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
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'VS',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: basqueRed,
              letterSpacing: 2.4,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.3),
              ),
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
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            color: surface,
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.25),
              width: 1.6,
            ),
          ),
          child: ClipRRect(
            borderRadius: borderRadius,
            child: Padding(
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
                        Icons.restaurant,
                        color: accent.withValues(alpha: 0.75),
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
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(color: ink, letterSpacing: 0.8),
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
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.06),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Precio',
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WinnerView extends StatelessWidget {
  const _WinnerView({
    super.key,
    required this.winner,
    required this.basqueDarkGreen,
    required this.basqueGreen,
    required this.basqueRed,
    required this.basqueWhite,
    required this.onRestart,
    required this.onBackToCategories,
  });

  final MenuDish winner;
  final Color basqueDarkGreen;
  final Color basqueGreen;
  final Color basqueRed;
  final Color basqueWhite;
  final VoidCallback onRestart;
  final VoidCallback onBackToCategories;

  @override
  Widget build(BuildContext context) {
    final winnerName = winner.name;
    final winnerPrice = winner.price;

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.25),
                  width: 1.4,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      _FlagMark(basqueGreen: basqueGreen, basqueRed: basqueRed),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'GANADOR',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                                letterSpacing: 2,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.90, end: 1),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutBack,
                    builder: (context, value, child) {
                      return Transform.scale(scale: value, child: child);
                    },
                    child: _WinnerImage(basqueWhite: basqueWhite),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    winnerName,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: const Color(0xFF171A17),
                      letterSpacing: 0.9,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${winnerPrice.toStringAsFixed(2)} €',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: onRestart,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: basqueGreen,
                        foregroundColor: basqueWhite,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Reiniciar',
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
                      onPressed: onBackToCategories,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF171A17),
                        side: BorderSide(color: basqueRed, width: 1.6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Volver al menú',
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
        ),
      ),
    );
  }
}

class _WinnerImage extends StatelessWidget {
  const _WinnerImage({required this.basqueWhite});

  final Color basqueWhite;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(26);

    return Container(
      width: 320,
      height: 220,
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
                      ).colorScheme.onSurface.withValues(alpha: 0.12),
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
                size: 90,
              ),
            ),
          ],
        ),
      ),
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

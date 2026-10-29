import 'package:flutter/material.dart';

import '../core/farm_store.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'climate_screen.dart';
import 'farms_screen.dart';
import 'login_screen.dart';
import 'productivity_screen.dart';
import 'reports_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FarmStore store = FarmStore.instance;

  static const Color _sidebar = Color(0xFF0F3D2A);
  static const Color _sidebarActive = Color(0xFF3F7B3F);
  static const Color _pageBg = Color(0xFFF1F6F0);
  static const Color _darkGreen = Color(0xFF124B30);
  static const Color _mutedText = Color(0xFF7D9684);

  @override
  void initState() {
    super.initState();
    store.load();
  }

  Future<void> _logout() async {
    await Session.instance.signOut();
    store.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _open(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 800;

       
if (isWide) {
  return Scaffold(
    backgroundColor: _pageBg,
    body: SizedBox.expand(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 250,
            height: double.infinity,
            child: _buildSidebar(),
          ),
          Expanded(
            child: _buildDesktopMain(),
          ),
        ],
      ),
    ),
  );
}

        return Scaffold(
          backgroundColor: _pageBg,
          appBar: AppBar(
            backgroundColor: _pageBg,
            foregroundColor: _darkGreen,
            elevation: 0,
            title: const Text(
              'RandomForest',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          drawer: Drawer(
            backgroundColor: _sidebar,
            child: SafeArea(child: _buildSidebar(inDrawer: true)),
          ),
          body: _buildMobileMain(),
        );
      },
    );
  }

  // ========================================
  // SIDEBAR
  // ========================================

  Widget _buildSidebar({bool inDrawer = false}) {
    void go(Widget screen) {
      if (inDrawer) Navigator.pop(context);
      _open(screen);
    }

    return Container(
      decoration: BoxDecoration(
        color: _sidebar,
        borderRadius: inDrawer
            ? null
            : const BorderRadius.only(
                topRight: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
      ),
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                'RandomForest',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.4,
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                'Smart insights for thriving farms',
                style: TextStyle(
                  color: Color(0xFFCFE0D2),
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 56),
            _NavItem(
              label: 'Dashboard',
              active: true,
              activeColor: _sidebarActive,
              onTap: () {
                if (inDrawer) Navigator.pop(context);
              },
            ),
            _NavItem(
              label: 'Climate Monitoring',
              activeColor: _sidebarActive,
              onTap: () => go(const ClimateScreen()),
            ),
            _NavItem(
              label: 'Crop Productivity',
              activeColor: _sidebarActive,
              onTap: () => go(const ProductivityScreen()),
            ),
            _NavItem(
              label: 'Weather & Crop Productivity Records History',
              activeColor: _sidebarActive,
              onTap: () => go(const ReportsScreen()),
            ),
            const SizedBox(height: 10),
            _NavItem(
              label: 'Log Out',
              activeColor: _sidebarActive,
              onTap: _logout,
            ),
          ],
        ),
      ),
    );
  }

  // ========================================
  // DESKTOP MAIN
  // ========================================

  Widget _buildDesktopMain() {
    return Stack(
      children: [
        // Farm field at the bottom
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 190,
          child: _FieldBackdrop(),
        ),

        RefreshIndicator(
          onRefresh: store.load,
          child: ListenableBuilder(
            listenable: store,
            builder: (context, _) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(48, 56, 48, 210),
                children: [
                  _buildHeader(large: true),
                  const SizedBox(height: 28),
                  ..._buildStoreSection(),
                  if (store.farms.isNotEmpty)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < _cards.length; i++) ...[
                          if (i > 0) const SizedBox(width: 22),
                          Expanded(
                            child: _FeatureCard(
                              data: _cards[i],
                              height: 400,
                              titleSize: 30,
                              onTap: () => _open(_cards[i].screen),
                            ),
                          ),
                        ],
                      ],
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // ========================================
  // MOBILE MAIN
  // ========================================

  Widget _buildMobileMain() {
    return RefreshIndicator(
      onRefresh: store.load,
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              _buildHeader(large: false),
              const SizedBox(height: 20),
              ..._buildStoreSection(),
              if (store.farms.isNotEmpty)
                for (final card in _cards) ...[
                  _FeatureCard(
                    data: card,
                    height: 230,
                    titleSize: 24,
                    onTap: () => _open(card.screen),
                  ),
                  const SizedBox(height: 16),
                ],
              const SizedBox(height: 8),
              const ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(20)),
                child: SizedBox(
                  height: 130,
                  child: _FieldBackdrop(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ========================================
  // SHARED PIECES
  // ========================================

  Widget _buildHeader({required bool large}) {
    final name = Session.instance.user?.fullName ?? 'Farmer';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome back, $name!',
          style: TextStyle(
            fontSize: large ? 40 : 26,
            fontWeight: FontWeight.bold,
            color: _darkGreen,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Here\u2019s an overview of your farm insights and tools.',
          style: TextStyle(
            fontSize: large ? 19 : 14,
            fontWeight: FontWeight.w500,
            color: _mutedText,
          ),
        ),
      ],
    );
  }

  // Error / loading / no farm / farm selector (same logic as before)
  List<Widget> _buildStoreSection() {
    return [
      if (store.error != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: ErrorBanner(store.error!, onRetry: store.load),
        ),
      if (store.loading && store.farms.isEmpty)
        const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
        )
      else if (store.farms.isEmpty && store.error == null)
        NoFarmNotice(
  onAdd: () => _open(
    const FarmsScreen(openAddDialogOnLoad: true),
  ),
)
      else if (store.farms.isNotEmpty) ...[
        FarmSelectorBar(store: store),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => _open(const FarmsScreen()),
            icon: const Icon(Icons.edit_location_alt_outlined),
            label: const Text('Manage farms'),
          ),
        ),
        if (store.selected?.areaHectares == null)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Tip: set this farm\'s area in Manage farms to unlock yield forecasts.',
              style: TextStyle(color: statusWarn),
            ),
          ),
        const SizedBox(height: 12),
      ],
    ];
  }

  static const List<_CardData> _cards = [
    _CardData(
      title: 'Climate\nMonitoring',
      description: 'Track weather conditions\nand forecasts for smarter\ndecisions.',
      asset: 'assets/images/card_climate.png',
      variant: 0,
      screen: ClimateScreen(),
    ),
    _CardData(
      title: 'Crop Productivity',
      description: 'Record harvested and sold\nsacks to monitor your farm\nprofit and productivity.',
      asset: 'assets/images/card_productivity.png',
      variant: 1,
      screen: ProductivityScreen(),
    ),
    _CardData(
      title: 'Weather & Crop Productivity Records History',
      description: 'View past weather data\nand crop productivity records\nfor easy monitoring.',
      asset: 'assets/images/card_records.png',
      variant: 2,
      screen: ReportsScreen(),
    ),
  ];
}

// ========================================
// NAV ITEM
// ========================================

class _NavItem extends StatelessWidget {
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  const _NavItem({
    required this.label,
    required this.activeColor,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: active ? activeColor : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
            child: Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : const Color(0xFFDCEBDD),
                fontSize: 16,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ========================================
// FEATURE CARD
// ========================================

class _CardData {
  final String title;
  final String description;
  final String asset;
  final int variant;
  final Widget screen;

  const _CardData({
    required this.title,
    required this.description,
    required this.asset,
    required this.variant,
    required this.screen,
  });
}

class _FeatureCard extends StatelessWidget {
  final _CardData data;
  final double height;
  final double titleSize;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.data,
    required this.height,
    required this.titleSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFDCE9D8),
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: height,
          child: Stack(
            children: [
              // Illustration at the bottom of the card
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: height * 0.42,
                child: Image.asset(
                  data.asset,
                  fit: BoxFit.cover,
                  alignment: Alignment.bottomCenter,
                  errorBuilder: (context, error, stackTrace) => CustomPaint(
                    painter: _HillsPainter(data.variant),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(28, 32, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      style: TextStyle(
                        fontSize: titleSize,
                        height: 1.2,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF124B30),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      data.description,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF86A08D),
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
}

// ========================================
// FIELD BACKDROP (bottom of the page)
// ========================================

class _FieldBackdrop extends StatelessWidget {
  const _FieldBackdrop();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/dashboard_field.png',
      fit: BoxFit.cover,
      alignment: Alignment.bottomCenter,
      width: double.infinity,
      errorBuilder: (context, error, stackTrace) => CustomPaint(
        painter: _FieldPainter(),
        size: Size.infinite,
      ),
    );
  }
}

// ========================================
// FALLBACK PAINTERS (used if the images are missing)
// ========================================

class _HillsPainter extends CustomPainter {
  final int variant;

  _HillsPainter(this.variant);

  void _tree(Canvas canvas, Offset base, double s, Color color) {
    canvas.drawRect(
      Rect.fromCenter(
        center: base.translate(0, -s * 0.15),
        width: s * 0.14,
        height: s * 0.4,
      ),
      Paint()..color = const Color(0xFF6B5B3E),
    );
    canvas.drawCircle(base.translate(0, -s * 0.6), s * 0.38, Paint()..color = color);
    canvas.drawCircle(
      base.translate(-s * 0.25, -s * 0.4),
      s * 0.28,
      Paint()..color = color,
    );
    canvas.drawCircle(
      base.translate(s * 0.25, -s * 0.4),
      s * 0.28,
      Paint()..color = color,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // back hills
    canvas.drawPath(
      Path()
        ..moveTo(0, h * 0.55)
        ..quadraticBezierTo(w * 0.3, h * 0.15, w * 0.6, h * 0.5)
        ..quadraticBezierTo(w * 0.8, h * 0.28, w, h * 0.48)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close(),
      Paint()..color = const Color(0xFFB5CDAE),
    );

    // middle hill
    canvas.drawPath(
      Path()
        ..moveTo(0, h * 0.72)
        ..quadraticBezierTo(w * 0.45, h * 0.4, w, h * 0.68)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close(),
      Paint()..color = const Color(0xFF8DB56F),
    );

    // front hill
    canvas.drawPath(
      Path()
        ..moveTo(0, h * 0.86)
        ..quadraticBezierTo(w * 0.5, h * 0.58, w, h * 0.86)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close(),
      Paint()..color = variant == 0
          ? const Color(0xFF4F8040)
          : const Color(0xFF5E9440),
    );

    switch (variant) {
      case 0:
        _tree(canvas, Offset(w * 0.12, h * 0.62), h * 0.3, const Color(0xFF4F8A45));
        _tree(canvas, Offset(w * 0.2, h * 0.64), h * 0.26, const Color(0xFF4F8A45));
        break;
      case 1:
        // house
        final house = Offset(w * 0.72, h * 0.58);
        canvas.drawRect(
          Rect.fromLTWH(house.dx, house.dy, w * 0.1, h * 0.12),
          Paint()..color = const Color(0xFFC79B5E),
        );
        canvas.drawPath(
          Path()
            ..moveTo(house.dx - w * 0.01, house.dy)
            ..lineTo(house.dx + w * 0.05, house.dy - h * 0.1)
            ..lineTo(house.dx + w * 0.11, house.dy)
            ..close(),
          Paint()..color = const Color(0xFF8B5E34),
        );
        _tree(canvas, Offset(w * 0.64, h * 0.6), h * 0.3, const Color(0xFF5E9A48));
        break;
      default:
        _tree(canvas, Offset(w * 0.82, h * 0.78), h * 0.8, const Color(0xFF5E9A48));
        // fence
        final fence = Paint()
          ..color = const Color(0xFFEFE9D8)
          ..strokeWidth = 3;
        canvas.drawLine(Offset(w * 0.05, h * 0.84), Offset(w * 0.6, h * 0.76), fence);
        for (var i = 0; i < 8; i++) {
          final x = w * (0.06 + i * 0.07);
          canvas.drawLine(
            Offset(x, h * (0.85 - i * 0.012)),
            Offset(x, h * (0.76 - i * 0.012)),
            fence,
          );
        }
    }
  }

  @override
  bool shouldRepaint(covariant _HillsPainter oldDelegate) =>
      oldDelegate.variant != variant;
}

class _FieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // distant mountains
    canvas.drawPath(
      Path()
        ..moveTo(0, h * 0.38)
        ..quadraticBezierTo(w * 0.15, h * 0.05, w * 0.35, h * 0.3)
        ..quadraticBezierTo(w * 0.55, h * 0.1, w * 0.8, h * 0.32)
        ..quadraticBezierTo(w * 0.92, h * 0.2, w, h * 0.3)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close(),
      Paint()..color = const Color(0xFFC3D9BE),
    );

    // tree line
    final bush = Paint()..color = const Color(0xFF6FA255);
    for (var x = 0.0; x < w; x += 26) {
      canvas.drawCircle(Offset(x, h * 0.5 + (x % 52 == 0 ? 0 : 6)), 17, bush);
    }

    // field
    final fieldTop = h * 0.52;
    canvas.drawRect(
      Rect.fromLTWH(0, fieldTop, w, h - fieldTop),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF7DB04F), Color(0xFF4E8A2F)],
        ).createShader(Rect.fromLTWH(0, fieldTop, w, h - fieldTop)),
    );

    // crop rows converging to the center
    final line = Paint()
      ..color = const Color(0xFF3E7A28)
      ..strokeWidth = 3;
    final vanish = Offset(w * 0.5, fieldTop);
    for (var i = -12; i <= 12; i++) {
      canvas.drawLine(vanish, Offset(w * 0.5 + i * (w / 12), h), line);
    }
  }

  @override
  bool shouldRepaint(covariant _FieldPainter oldDelegate) => false;
}

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

  // 0 = Dashboard, 1 = Climate, 2 = Productivity, 3 = Records
  int _selectedIndex = 0;

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

  void _open(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  void _selectPage(int index, {bool inDrawer = false}) {
    if (inDrawer) {
      Navigator.pop(context);
    }

    if (!mounted) return;

    setState(() {
      _selectedIndex = index;
    });
  }

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
                    child: _buildSidebar(),
                  ),
                  Expanded(
                    child: IndexedStack(
                      index: _selectedIndex,
                      children: [
                        _buildDesktopMain(),
                        const ClimateScreen(),
                        const ProductivityScreen(),
                        const ReportsScreen(),
                      ],
                    ),
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
              'CropWise',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          drawer: Drawer(
            backgroundColor: _sidebar,
            child: SafeArea(
              child: _buildSidebar(inDrawer: true),
            ),
          ),
          body: IndexedStack(
            index: _selectedIndex,
            children: [
              _buildMobileMain(),
              const ClimateScreen(),
              const ProductivityScreen(),
              const ReportsScreen(),
            ],
          ),
        );
      },
    );
  }

  // ========================================
  // SIDEBAR
  // ========================================

  Widget _buildSidebar({bool inDrawer = false}) {
    void go(int index) {
      _selectPage(index, inDrawer: inDrawer);
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
                'CropWise',
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
                'Smart Climate Insights, Better Crop Decisions',
                style: TextStyle(
                  color: Color(0xFFCFE0D2),
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 56),

            _NavItem(
              label: 'Dashboard',
              active: _selectedIndex == 0,
              activeColor: _sidebarActive,
              onTap: () => go(0),
            ),

            _NavItem(
              label: 'Climate Monitoring',
              active: _selectedIndex == 1,
              activeColor: _sidebarActive,
              onTap: () => go(1),
            ),

            _NavItem(
              label: 'Crop Productivity',
              active: _selectedIndex == 2,
              activeColor: _sidebarActive,
              onTap: () => go(2),
            ),

            _NavItem(
              label: 'Weather & Crop Productivity Records History',
              active: _selectedIndex == 3,
              activeColor: _sidebarActive,
              onTap: () => go(3),
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
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/images/dashboard_field.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (context, error, stackTrace) {
              return Container(color: _pageBg);
            },
          ),
        ),

        Positioned.fill(
          child: Container(
            color: const Color(0x33F1F6F0),
          ),
        ),

        RefreshIndicator(
          onRefresh: store.load,
          child: ListenableBuilder(
            listenable: store,
            builder: (context, _) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(48, 56, 48, 40),
                children: [
                  _buildHeader(large: true),
                  const SizedBox(height: 28),

                  ..._buildStoreSection(),

                  if (store.farms.isNotEmpty)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final cardWidth =
                            (constraints.maxWidth - 44) / 3;

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var i = 0; i < _cards.length; i++) ...[
                              if (i > 0) const SizedBox(width: 22),
                              SizedBox(
                                width: cardWidth,
                                child: _FeatureCard(
                                  data: _cards[i],
                                  height: 400,
                                  titleSize: 30,
                                  onTap: () => _selectPage(i + 1),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
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
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/images/dashboard_field.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (context, error, stackTrace) {
              return Container(color: _pageBg);
            },
          ),
        ),

        Positioned.fill(
          child: Container(
            color: const Color(0x33F1F6F0),
          ),
        ),

        RefreshIndicator(
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
                    for (var i = 0; i < _cards.length; i++) ...[
                      _FeatureCard(
                        data: _cards[i],
                        height: 230,
                        titleSize: 24,
                        onTap: () => _selectPage(i + 1),
                      ),
                      const SizedBox(height: 16),
                    ],

                  const SizedBox(height: 8),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // ========================================
  // SHARED HEADER
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
          'Here’s an overview of your farm insights and tools.',
          style: TextStyle(
            fontSize: large ? 19 : 14,
            fontWeight: FontWeight.w500,
            color: _mutedText,
          ),
        ),
      ],
    );
  }

  // ========================================
  // FARM SECTION
  // ========================================

  List<Widget> _buildStoreSection() {
    return [
      if (store.error != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: ErrorBanner(
            store.error!,
            onRetry: store.load,
          ),
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
              'Tip: set this farm’s area in Manage farms to unlock yield forecasts.',
              style: TextStyle(color: statusWarn),
            ),
          ),

        const SizedBox(height: 12),
      ],
    ];
  }

  // ========================================
  // FEATURE CARDS
  // ========================================

  static const List<_CardData> _cards = [
    _CardData(
      title: 'Climate\nMonitoring',
      description:
          'Track weather conditions\nand forecasts for smarter\ndecisions.',
      asset: 'assets/images/climate_monitoring.png',
      variant: 0,
      screen: ClimateScreen(),
    ),
    _CardData(
      title: 'Crop Productivity',
      description:
          'Record harvested and sold\nsacks to monitor your farm\nprofit and productivity.',
      asset: 'assets/images/crop_productivity.png',
      variant: 1,
      screen: ProductivityScreen(),
    ),
    _CardData(
      title: 'Weather & Crop Productivity Records History',
      description:
          'View past weather data\nand crop productivity records\nfor easy monitoring.',
      asset:
          'assets/images/weather&crop_productivity_record_history.png',
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
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 17,
            ),
            child: Text(
              label,
              style: TextStyle(
                color: active
                    ? Colors.white
                    : const Color(0xFFDCEBDD),
                fontSize: 16,
                fontWeight:
                    active ? FontWeight.w600 : FontWeight.w500,
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
      color: const Color(0xE6DCE9D8),
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    data.asset,
                    width: double.infinity,
                    height: height * 0.40,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: double.infinity,
                        height: height * 0.40,
                        color: const Color(0xFFB5CDAE),
                        child: Icon(
                          data.variant == 0
                              ? Icons.cloud_outlined
                              : data.variant == 1
                                  ? Icons.agriculture
                                  : Icons.history,
                          size: 50,
                          color: const Color(0xFF124B30),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 18),

                Text(
                  data.title.replaceAll('\n', ' '),
                  style: TextStyle(
                    fontSize: titleSize,
                    height: 1.15,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF124B30),
                  ),
                ),

                const SizedBox(height: 10),

                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      data.description.replaceAll('\n', ' '),
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF52745C),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ========================================
// FIELD BACKDROP
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
// FALLBACK PAINTERS
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

    canvas.drawCircle(
      base.translate(0, -s * 0.6),
      s * 0.38,
      Paint()..color = color,
    );

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

    canvas.drawPath(
      Path()
        ..moveTo(0, h * 0.72)
        ..quadraticBezierTo(w * 0.45, h * 0.4, w, h * 0.68)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close(),
      Paint()..color = const Color(0xFF8DB56F),
    );

    canvas.drawPath(
      Path()
        ..moveTo(0, h * 0.86)
        ..quadraticBezierTo(w * 0.5, h * 0.58, w, h * 0.86)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close(),
      Paint()
        ..color = variant == 0
            ? const Color(0xFF4F8040)
            : const Color(0xFF5E9440),
    );

    switch (variant) {
      case 0:
        _tree(
          canvas,
          Offset(w * 0.12, h * 0.62),
          h * 0.3,
          const Color(0xFF4F8A45),
        );
        _tree(
          canvas,
          Offset(w * 0.2, h * 0.64),
          h * 0.26,
          const Color(0xFF4F8A45),
        );
        break;

      case 1:
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

        _tree(
          canvas,
          Offset(w * 0.64, h * 0.6),
          h * 0.3,
          const Color(0xFF5E9A48),
        );
        break;

      default:
        _tree(
          canvas,
          Offset(w * 0.82, h * 0.78),
          h * 0.8,
          const Color(0xFF5E9A48),
        );

        final fence = Paint()
          ..color = const Color(0xFFEFE9D8)
          ..strokeWidth = 3;

        canvas.drawLine(
          Offset(w * 0.05, h * 0.84),
          Offset(w * 0.6, h * 0.76),
          fence,
        );

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
  bool shouldRepaint(covariant _HillsPainter oldDelegate) {
    return oldDelegate.variant != variant;
  }
}

class _FieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

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

    final bush = Paint()..color = const Color(0xFF6FA255);

    for (var x = 0.0; x < w; x += 26) {
      canvas.drawCircle(
        Offset(x, h * 0.5 + (x % 52 == 0 ? 0 : 6)),
        17,
        bush,
      );
    }

    final fieldTop = h * 0.52;

    canvas.drawRect(
      Rect.fromLTWH(0, fieldTop, w, h - fieldTop),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF7DB04F),
            Color(0xFF4E8A2F),
          ],
        ).createShader(
          Rect.fromLTWH(0, fieldTop, w, h - fieldTop),
        ),
    );

    final line = Paint()
      ..color = const Color(0xFF3E7A28)
      ..strokeWidth = 3;

    final vanish = Offset(w * 0.5, fieldTop);

    for (var i = -12; i <= 12; i++) {
      canvas.drawLine(
        vanish,
        Offset(w * 0.5 + i * (w / 12), h),
        line,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FieldPainter oldDelegate) => false;
}

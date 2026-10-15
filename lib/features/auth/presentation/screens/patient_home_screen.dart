
import 'package:flutter/material.dart';
import '../../../catalog/presentation/screens/service_catalog_screen.dart';
import '../../../patient/presentation/screens/profile_screen.dart';

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  static const navy = Color(0xFF0F2743);
  static const navyLight = Color(0xFF1E1B4B);
  static const blue = Color(0xFF0353E9);
  static const background = Color(0xFFF5F7FB);
  static const muted = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);

  int selectedIndex = 0;

  final List<String> tabs = [
    'Home',
    'Services',
    'Appts',
    'Results',
    'Profile',
  ];

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void onTabSelected(int index) {
    setState(() => selectedIndex = index);

    if (index == 2 || index == 3) {
      showMessage('${tabs[index]} screen đang được phát triển.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: selectedIndex,
          children: [
            buildHomeContent(),
            const ServiceCatalogScreen(),
            buildPlaceholder('My appointments', Icons.calendar_month),
            buildPlaceholder('My results', Icons.description_outlined),
            const ProfileScreen(),
          ],
        ),
      ),
      bottomNavigationBar: buildBottomNavigation(),
    );
  }

  // ==================== HOME CONTENT ====================

  Widget buildHomeContent() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: buildHeroHeader(),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              buildNextAppointment(),
              const SizedBox(height: 14),
              buildQuickActions(),
              const SizedBox(height: 14),
              buildRecentActivity(),
            ]),
          ),
        ),
      ],
    );
  }

  // ==================== HEADER ====================

  Widget buildHeroHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [navy, navyLight],
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'WELCOME BACK',
                      style: TextStyle(
                        color: Color(0xFF94B0CE),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Nguyễn Văn An',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [blue, Color(0xFF002D9C)],
                  ),
                ),
                child: const Text(
                  'NA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: buildStatCard(
                  value: '2',
                  label: 'Upcoming',
                  icon: Icons.calendar_month_outlined,
                  valueColor: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: buildStatCard(
                  value: '1',
                  label: 'New result',
                  icon: Icons.description_outlined,
                  valueColor: const Color(0xFF34D399),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildStatCard({
    required String value,
    required String label,
    required IconData icon,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: valueColor,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Icon(
                icon,
                color: const Color(0xFF94B0CE),
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFB7C8DA),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== NEXT APPOINTMENT ====================

  Widget buildNextAppointment() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Next appointment',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: navy,
                  ),
                ),
              ),
              buildStatusBadge(
                'Confirmed',
                const Color(0xFFDBEAFE),
                const Color(0xFF1D4ED8),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Lipid Profile',
            style: TextStyle(
              color: navy,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 16,
                color: muted,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '10 Oct · 08:00 · Lab Room 02',
                  style: TextStyle(
                    color: muted,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: FilledButton.icon(
              onPressed: () {
                showMessage('Mở mã QR check-in lịch hẹn.');
              },
              icon: const Icon(Icons.qr_code_2, size: 20),
              label: const Text(
                'QR Check-in',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== QUICK ACTIONS ====================

  Widget buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick actions',
            style: TextStyle(
              color: navy,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.65,
            children: [
              buildActionItem(
                icon: Icons.calendar_month_outlined,
                label: 'Book test',
                color: blue,
                backgroundColor: const Color(0xFFEFF6FF),
                onTap: () => onTabSelected(1),
              ),
              buildActionItem(
                icon: Icons.medical_information_outlined,
                label: 'My results',
                color: const Color(0xFF059669),
                backgroundColor: const Color(0xFFECFDF5),
                onTap: () => onTabSelected(3),
              ),
              buildActionItem(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Payments',
                color: const Color(0xFFD97706),
                backgroundColor: const Color(0xFFFFF7ED),
                onTap: () => showMessage('Payments screen chưa được triển khai.'),
              ),
              buildActionItem(
                icon: Icons.person_outline,
                label: 'Profile',
                color: const Color(0xFF7C3AED),
                backgroundColor: const Color(0xFFF5F3FF),
                onTap: () => onTabSelected(4),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildActionItem({
    required IconData icon,
    required String label,
    required Color color,
    required Color backgroundColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 25),
              const SizedBox(height: 7),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== RECENT ACTIVITY ====================

  Widget buildRecentActivity() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent activity',
            style: TextStyle(
              color: navy,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          buildActivityItem(
            icon: Icons.check_circle,
            color: const Color(0xFF059669),
            title: 'Appointment confirmed',
            time: '2 hours ago',
          ),
          buildActivityItem(
            icon: Icons.description_outlined,
            color: blue,
            title: 'CBC results available',
            time: 'Yesterday',
          ),
          buildActivityItem(
            icon: Icons.account_balance_wallet_outlined,
            color: const Color(0xFF059669),
            title: 'Payment 350,000 ₫',
            time: '3 days ago',
            showDivider: false,
          ),
        ],
      ),
    );
  }

  Widget buildActivityItem({
    required IconData icon,
    required Color color,
    required String title,
    required String time,
    bool showDivider = true,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(
          bottom: BorderSide(color: border),
        )
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF334155),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: const TextStyle(
                    color: muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== BOTTOM NAVIGATION ====================

  Widget buildBottomNavigation() {
    const icons = [
      Icons.home_outlined,
      Icons.search,
      Icons.calendar_month_outlined,
      Icons.description_outlined,
      Icons.person_outline,
    ];

    const selectedIcons = [
      Icons.home,
      Icons.search,
      Icons.calendar_month,
      Icons.description,
      Icons.person,
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: border),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: List.generate(tabs.length, (index) {
              final isSelected = selectedIndex == index;

              return Expanded(
                child: InkWell(
                  onTap: () => onTabSelected(index),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isSelected
                            ? selectedIcons[index]
                            : icons[index],
                        color: isSelected ? blue : const Color(0xFF94A3B8),
                        size: 22,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tabs[index],
                        style: TextStyle(
                          color: isSelected
                              ? blue
                              : const Color(0xFF94A3B8),
                          fontSize: 10,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  // ==================== PLACEHOLDER TABS ====================

  Widget buildPlaceholder(String title, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: blue, size: 56),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: navy,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This screen will be implemented later.',
            style: TextStyle(color: muted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => onTabSelected(0),
            icon: const Icon(Icons.home_outlined),
            label: const Text('Back to Home'),
          ),
        ],
      ),
    );
  }

  // ==================== SHARED WIDGETS ====================

  BoxDecoration cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.025),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ],
    );
  }

  Widget buildStatusBadge(
      String label,
      Color backgroundColor,
      Color textColor,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: textColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'student_details.dart';
import 'report_card/screens/report_card_screen.dart';
import 'history_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Student Dashboard',
      themeMode: ThemeMode.system,
      theme: ThemeData(
        primaryColor: const Color(0xFF296FD8),
        scaffoldBackgroundColor: const Color(
          0xFFF1F5F9,
        ), // Light grayish-blue bg
        fontFamily: 'Inter',
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF296FD8),
          brightness: Brightness.light,
          primary: const Color(0xFF296FD8),
          surface: Colors.white,
        ),
      ),
      darkTheme: ThemeData(
        primaryColor: const Color(0xFF296FD8),
        scaffoldBackgroundColor: const Color(0xFF121212),
        fontFamily: 'Inter',
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF296FD8),
          brightness: Brightness.dark,
          primary: const Color(0xFF296FD8),
          surface: const Color(0xFF1E1E1E),
        ),
      ),
      home: const DashboardScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning,';
    } else if (hour < 17) {
      return 'Good Afternoon,';
    } else {
      return 'Good Evening,';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF296FD8),
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        toolbarHeight: 70,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFF296FD8),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Image.asset('assets/icons/SAECO.png', height: 80, width: 80),
                    const SizedBox(height: 4),
                    const Text(
                      'Department of\n Information Technology',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.history, color: Color(0xFF296FD8)),
              title: const Text('History'),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HistoryScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BottomNavigationBar(
            backgroundColor: Theme.of(context).colorScheme.surface,
            type: BottomNavigationBarType.fixed,
            showSelectedLabels: true,
            showUnselectedLabels: true,
            selectedItemColor: const Color(0xFF296FD8),
            unselectedItemColor: const Color(0xFF64748B),
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
            items: [
              BottomNavigationBarItem(
                icon: Container(
                  margin: const EdgeInsets.only(bottom: 4, top: 4),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF296FD8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.home, color: Colors.white, size: 20),
                ),
                label: 'Home',
              ),
              const BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(bottom: 4, top: 4),
                  child: Icon(Icons.calendar_today, size: 20),
                ),
                label: 'Events',
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting Section
            Text(
              _getGreeting(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Text(
                  'Professor',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF296FD8),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('👋', style: TextStyle(fontSize: 20)),
              ],
            ),
            const SizedBox(height: 24),

            // Banner Section
            Container(
              width: double.infinity,
              height: 160,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: Theme.of(context).brightness == Brightness.dark
                      ? [const Color(0xFF1E3A8A), const Color(0xFF1E40AF)]
                      : [const Color(0xFFE6F0FF), const Color(0xFFC4DBFE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 140,
                          height: 12,
                          decoration: BoxDecoration(
                            color: const Color(0xFFA4C4F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 80,
                          height: 12,
                          decoration: BoxDecoration(
                            color: const Color(0xFFA4C4F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          'Dr. Sivanthi Aditanar College of Engineering,\nDepartment of Information \nTechnology.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF296FD8),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: 40,
                          height: 8,
                          decoration: BoxDecoration(
                            color: const Color(0xFFA4C4F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 15,
                    right: 15,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Academic Year',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF296FD8),
                            ),
                          ),
                          Text(
                            '2026 - 2027',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -10,
                    right: -10,
                    child: Icon(
                      Icons.account_balance, // Building placeholder
                      size: 100,
                      color: const Color(0xFF75A5F5).withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Quick Actions Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                GestureDetector(
                  onTap: () {},
                  child: const Row(
                    children: [
                      Text(
                        'View All',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF296FD8),
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: Color(0xFF296FD8),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Grid for Quick Actions (Only showing Students)
            LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount;

                if (constraints.maxWidth > 1200) {
                  crossAxisCount = 8;
                } else if (constraints.maxWidth > 800) {
                  crossAxisCount = 6;
                } else if (constraints.maxWidth > 600) {
                  crossAxisCount = 4;
                } else if (constraints.maxWidth < 350) {
                  crossAxisCount = 2;
                } else {
                  crossAxisCount = 3;
                }

                const double spacing = 12;

                // Calculate actual card width
                final double cardWidth =
                    (constraints.maxWidth - ((crossAxisCount - 1) * spacing)) /
                    crossAxisCount;

                // Calculate height based on card width
                final double cardHeight = (cardWidth * 0.95).clamp(
                  100.0,
                  150.0,
                );

                final actions = [
                  {
                    'name': 'Leave Intimation',
                    'icon': Icons.quick_contacts_mail,
                  },
                  {'name': 'Report Card', 'icon': Icons.credit_card_outlined},
                  //{'name': 'Events', 'icon': Icons.event},
                ];

                return GridView.builder(
                  itemCount: actions.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: spacing,
                    mainAxisSpacing: spacing,
                    mainAxisExtent: cardHeight,
                  ),
                  itemBuilder: (context, index) {
                    final action = actions[index];

                    return _buildActionCard(
                      context,
                      action['name'] as String,
                      action['icon'] as IconData,
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, String title, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[800]!
              : const Color(0xFFF1F5F9),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (title == 'Leave Intimation') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const StudentDetailsScreen(),
                ),
              );
            } else if (title == 'Report Card') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ReportCardExcelScreen(),
                ),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E7FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 24, color: const Color(0xFF296FD8)),
                ),

                const SizedBox(height: 8),

                Flexible(
                  child: Text(
                    title,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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

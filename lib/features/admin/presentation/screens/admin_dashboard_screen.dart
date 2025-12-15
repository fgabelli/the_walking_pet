import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/ads_table_widget.dart';
import 'create_campaign_web_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Row(
          children: [
            // Icon(Icons.pets, color: AppColors.primary),
             SizedBox(width: 8),
             Text('The Walking Pet', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
             SizedBox(width: 8),
             Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
              child: Text('ADMIN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
               Navigator.of(context).pushReplacementNamed('/'); // Back to login
            },
          ),
        ],
      ),
      body: Row(
        children: [
          // Sidebar
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.campaign_outlined),
                selectedIcon: Icon(Icons.campaign),
                label: Text('Campagne'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.analytics_outlined),
                selectedIcon: Icon(Icons.analytics),
                label: Text('Stats'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedIndex == 0 ? 'Gestione Pubblicità' : 'Statistiche',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (_selectedIndex == 0)
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const CreateCampaignScreen()),
                            );
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Nuova Campagna'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Expanded(
                    child: _selectedIndex == 0
                        ? const AdsTableWidget()
                        : const Center(child: Text('Statistiche avanzate in arrivo...')),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

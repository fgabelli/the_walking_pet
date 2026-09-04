import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/ads_table_widget.dart';
import '../widgets/business_claims_widget.dart';
import '../widgets/ad_inquiries_widget.dart';
import '../widgets/users_table_widget.dart';
import '../widgets/admob_stats_widget.dart';
import '../widgets/moderation_widget.dart';
import '../widgets/activities_events_widget.dart';
import '../widgets/broadcast_templates_widget.dart';
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
             Text('DOGZN', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
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
          // Sidebar scrollabile
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: NavigationRail(
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: (int index) {
                      setState(() {
                        _selectedIndex = index;
                      });
                    },
                    labelType: NavigationRailLabelType.all,
                    destinations: [
                      NavigationRailDestination(
                        icon: Icon(Icons.campaign_outlined),
                        selectedIcon: Icon(Icons.campaign),
                        label: Text('Campagne'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.storefront_outlined),
                        selectedIcon: Icon(Icons.storefront),
                        label: Text('Riscatti'),
                      ),
                      NavigationRailDestination(
                        icon: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('ad_inquiries')
                              .where('status', isEqualTo: 'pending')
                              .snapshots(),
                          builder: (context, snapshot) {
                            final count = snapshot.data?.docs.length ?? 0;
                            if (count > 0) {
                              return Badge(
                                label: Text('$count'),
                                child: const Icon(Icons.mail_outlined),
                              );
                            }
                            return const Icon(Icons.mail_outlined);
                          },
                        ),
                        selectedIcon: const Icon(Icons.mail),
                        label: const Text('Richieste'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.analytics_outlined),
                        selectedIcon: Icon(Icons.analytics),
                        label: Text('Stats AdMob'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.group_outlined),
                        selectedIcon: Icon(Icons.group),
                        label: Text('Utenti/Pet'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.gavel_outlined),
                        selectedIcon: Icon(Icons.gavel),
                        label: Text('Moderazione Post'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.event_outlined),
                        selectedIcon: Icon(Icons.event),
                        label: Text('Attività/Eventi'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.forum_outlined),
                        selectedIcon: Icon(Icons.forum),
                        label: Text('Messaggi'),
                      ),
                    ],
                  ),
                ),
              );
            },
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
                        _selectedIndex == 0
                            ? 'Gestione Pubblicità'
                            : _selectedIndex == 1
                                ? 'Riscatti Attività'
                                : _selectedIndex == 2
                                    ? 'Richieste Pubblicitarie'
                                    : _selectedIndex == 3
                                        ? 'Statistiche AdMob'
                                        : _selectedIndex == 4
                                            ? 'Gestione Utenti'
                                            : _selectedIndex == 5
                                                 ? 'Moderazione Social'
                                                 : _selectedIndex == 6
                                                    ? 'Attività, Passeggiate ed Eventi'
                                                    : 'Template & Broadcast Messaggi',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (_selectedIndex == 0)
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
            settings: const RouteSettings(name: 'create_campaign'),builder: (_) => const CreateCampaignScreen()),
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
                        : _selectedIndex == 1
                            ? const BusinessClaimsWidget()
                            : _selectedIndex == 2
                                ? const AdInquiriesWidget()
                                : _selectedIndex == 3 
                                    ? const AdMobStatsWidget()
                                    : _selectedIndex == 4
                                         ? const UsersTableWidget()
                                         : _selectedIndex == 5
                                             ? const ModerationWidget()
                                             : _selectedIndex == 6
                                                 ? const ActivitiesEventsWidget()
                                                 : const BroadcastTemplatesWidget(),
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

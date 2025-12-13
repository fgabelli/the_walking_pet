import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/user_model.dart';
import '../../../profile/presentation/screens/business_profile_screen.dart';

class BusinessShowcaseWidget extends ConsumerWidget {
  const BusinessShowcaseWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              const Icon(Icons.star, color: AppColors.secondary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Negozi Consigliati',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 160,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('accountType', isEqualTo: 'business')
                .limit(10) // Limit to 10 for now
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const SizedBox();
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                 return Center(
                   child: Padding(
                     padding: const EdgeInsets.all(16.0),
                     child: Text(
                       'Nessuna attività in evidenza',
                       style: TextStyle(color: Colors.grey[400]),
                     ),
                   ),
                 );
              }

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final user = UserModel.fromFirestore(docs[index]);
                  return _BusinessCard(user: user);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BusinessCard extends StatelessWidget {
  final UserModel user;
  const _BusinessCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BusinessProfileScreen(businessUser: user),
          ),
        );
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Image / Header
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: SizedBox(
                height: 80,
                width: double.infinity,
                child: user.coverImageUrl != null
                    ? Image.network(user.coverImageUrl!, fit: BoxFit.cover)
                    : Container(
                        color: AppColors.primary.withOpacity(0.1),
                        child: Icon(Icons.store, color: AppColors.primary.withOpacity(0.5)),
                      ),
              ),
            ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.businessCategory ?? user.firstName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    if (user.address != null)
                      Text(
                        user.address!, // Simplified zone/address
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

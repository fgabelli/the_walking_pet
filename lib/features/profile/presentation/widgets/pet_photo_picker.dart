import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/storage_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Result returned by PetPhotoPicker
class PetPhotoPickerResult {
  final List<String> selectedUrls;
  final List<File> newFiles;

  PetPhotoPickerResult({required this.selectedUrls, required this.newFiles});
}

/// Bottom sheet that shows the user's existing post photos
/// and allows selecting up to [maxPhotos] for a pet profile.
class PetPhotoPicker extends ConsumerStatefulWidget {
  final List<String> alreadySelected;
  final int maxPhotos;

  const PetPhotoPicker({
    super.key,
    this.alreadySelected = const [],
    this.maxPhotos = 9,
  });

  @override
  ConsumerState<PetPhotoPicker> createState() => _PetPhotoPickerState();
}

class _PetPhotoPickerState extends ConsumerState<PetPhotoPicker> {
  late Set<String> _selectedUrls;
  final List<File> _newFiles = [];
  final List<String> _newFilePreviewUrls = [];
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _selectedUrls = Set<String>.from(widget.alreadySelected);
  }

  int get _totalSelected => _selectedUrls.length + _newFiles.length;
  bool get _canAddMore => _totalSelected < widget.maxPhotos;

  Future<void> _pickNewPhoto(ImageSource source) async {
    if (!_canAddMore) return;
    final picked = await _picker.pickImage(source: source, maxWidth: 1080, imageQuality: 85);
    if (picked != null) {
      setState(() {
        _newFiles.add(File(picked.path));
      });
    }
  }

  void _toggleSelection(String url) {
    setState(() {
      if (_selectedUrls.contains(url)) {
        _selectedUrls.remove(url);
      } else if (_canAddMore) {
        _selectedUrls.add(url);
      }
    });
  }

  void _removeNewFile(int index) {
    setState(() {
      _newFiles.removeAt(index);
    });
  }

  void _confirm() {
    Navigator.pop(
      context,
      PetPhotoPickerResult(
        selectedUrls: _selectedUrls.toList(),
        newFiles: _newFiles,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authServiceProvider).currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Scegli le foto',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$_totalSelected di ${widget.maxPhotos} selezionate',
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _totalSelected > 0 ? _confirm : null,
                      child: Text(
                        'Conferma',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: _totalSelected > 0 ? AppColors.primary : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // New files preview (if any)
              if (_newFiles.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.only(left: 20, top: 8, bottom: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Nuove foto', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
                  ),
                ),
                SizedBox(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _newFiles.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(_newFiles[index], width: 76, height: 76, fit: BoxFit.cover),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: GestureDetector(
                                onTap: () => _removeNewFile(index),
                                child: Container(
                                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                  padding: const EdgeInsets.all(3),
                                  child: const Icon(Icons.close, color: Colors.white, size: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],

              // Add new photo buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _canAddMore ? () => _pickNewPhoto(ImageSource.gallery) : null,
                        icon: const Icon(Icons.photo_library, size: 18),
                        label: const Text('Galleria', style: TextStyle(fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(color: _canAddMore ? AppColors.primary : Colors.grey.shade300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _canAddMore ? () => _pickNewPhoto(ImageSource.camera) : null,
                        icon: const Icon(Icons.camera_alt, size: 18),
                        label: const Text('Fotocamera', style: TextStyle(fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(color: _canAddMore ? AppColors.primary : Colors.grey.shade300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Divider
              const Divider(height: 1),

              // Label
              const Padding(
                padding: EdgeInsets.only(left: 20, top: 12, bottom: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Le tue foto dai post', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
                ),
              ),

              // Post photos grid
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('social_posts')
                      .where('authorId', isEqualTo: currentUser.uid)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                    }

                    final docs = snapshot.data?.docs ?? [];
                    final photoUrls = docs
                        .map((doc) => (doc.data() as Map<String, dynamic>)['imageUrl'] as String?)
                        .where((url) => url != null && url.isNotEmpty)
                        .cast<String>()
                        .toList();

                    if (photoUrls.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.photo_library_outlined, size: 56, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text(
                              'Nessuna foto nei tuoi post.\nUsa i bottoni sopra per aggiungerne.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      );
                    }

                    return GridView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(4),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 3,
                        mainAxisSpacing: 3,
                      ),
                      itemCount: photoUrls.length,
                      itemBuilder: (context, index) {
                        final url = photoUrls[index];
                        final isSelected = _selectedUrls.contains(url);
                        final selectionOrder = isSelected
                            ? _selectedUrls.toList().indexOf(url) + 1
                            : 0;

                        return GestureDetector(
                          onTap: () => _toggleSelection(url),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: CachedNetworkImage(
                                  imageUrl: url,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(color: Colors.grey.shade200),
                                  errorWidget: (_, __, ___) => Container(
                                    color: Colors.grey.shade200,
                                    child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                                  ),
                                ),
                              ),

                              // Selection overlay
                              if (isSelected)
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    color: AppColors.primary.withOpacity(0.25),
                                    border: Border.all(color: AppColors.primary, width: 3),
                                  ),
                                ),

                              // Selection badge
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected ? AppColors.primary : Colors.white.withOpacity(0.7),
                                    border: Border.all(
                                      color: isSelected ? AppColors.primary : Colors.grey.shade400,
                                      width: 2,
                                    ),
                                  ),
                                  child: isSelected
                                      ? Center(
                                          child: Text(
                                            '$selectionOrder',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

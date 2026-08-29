import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/dog_model.dart';

class SwipeCardController {
  void Function(bool isLike)? _swipeTrigger;

  void swipe(bool isLike) {
    _swipeTrigger?.call(isLike);
  }
}

class SwipeCard extends StatefulWidget {
  final DogModel? pet;
  final double? distanceKm;
  final Function(bool isLike) onSwipe;
  final SwipeCardController? controller;
  final bool isAd;
  final Widget? adWidget;

  const SwipeCard({
    super.key,
    this.pet,
    this.distanceKm,
    required this.onSwipe,
    this.controller,
    this.isAd = false,
    this.adWidget,
  });

  @override
  State<SwipeCard> createState() => _SwipeCardState();
}

class _SwipeCardState extends State<SwipeCard> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _swipeAnimation;
  late Animation<double> _rotateAnimation;

  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;
  double _swipeThreshold = 120.0;

  // Photo gallery state
  int _currentPage = 0;

  List<String> get _photos {
    if (widget.isAd || widget.pet == null) return [];
    if (widget.pet!.mediaUrls.isNotEmpty) return widget.pet!.mediaUrls;
    if (widget.pet!.photoUrl != null && widget.pet!.photoUrl!.isNotEmpty) return [widget.pet!.photoUrl!];
    return [];
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _swipeAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));

    _rotateAnimation = Tween<double>(
      begin: 0.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));

    if (widget.controller != null) {
      widget.controller!._swipeTrigger = _triggerSwipeProgrammatically;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _triggerSwipeProgrammatically(bool isLike) {
    if (_isDragging) return;
    
    final screenWidth = MediaQuery.of(context).size.width;
    final endOffset = Offset(isLike ? screenWidth * 1.5 : -screenWidth * 1.5, 0);

    setState(() {
      _swipeAnimation = Tween<Offset>(
        begin: Offset.zero,
        end: endOffset,
      ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));

      _rotateAnimation = Tween<double>(
        begin: 0.0,
        end: isLike ? 0.4 : -0.4,
      ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
    });

    _animationController.forward().then((_) {
      widget.onSwipe(isLike);
    });
  }

  void _onPanStart(DragStartDetails details) {
    if (_animationController.isAnimating) return;
    setState(() {
      _isDragging = true;
      _dragOffset = Offset.zero;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_animationController.isAnimating) return;
    setState(() {
      _dragOffset += details.delta;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_animationController.isAnimating) return;
    
    final screenWidth = MediaQuery.of(context).size.width;

    if (_dragOffset.dx.abs() > _swipeThreshold) {
      // Swipe detected
      final isLike = _dragOffset.dx > 0;
      final endOffset = Offset(isLike ? screenWidth * 1.5 : -screenWidth * 1.5, _dragOffset.dy);

      setState(() {
        _isDragging = false;
        _swipeAnimation = Tween<Offset>(
          begin: _dragOffset,
          end: endOffset,
        ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));

        _rotateAnimation = Tween<double>(
          begin: _getRotationAngle(),
          end: isLike ? 0.4 : -0.4,
        ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));
      });

      _animationController.forward().then((_) {
        widget.onSwipe(isLike);
      });
    } else {
      // Return to center
      setState(() {
        _isDragging = false;
        _swipeAnimation = Tween<Offset>(
          begin: _dragOffset,
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _animationController, curve: Curves.elasticOut));

        _rotateAnimation = Tween<double>(
          begin: _getRotationAngle(),
          end: 0.0,
        ).animate(CurvedAnimation(parent: _animationController, curve: Curves.elasticOut));
      });

      _animationController.forward(from: 0.0);
    }
  }

  double _getRotationAngle() {
    // 1 radian is approx 57 degrees. Max rotation around 15 degrees (0.26 rad) at threshold
    final maxRotate = 0.25;
    final progress = (_dragOffset.dx / _swipeThreshold).clamp(-1.0, 1.0);
    return progress * maxRotate;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final offset = _isDragging ? _dragOffset : _swipeAnimation.value;
        final rotation = _isDragging ? _getRotationAngle() : _rotateAnimation.value;

        return Transform.translate(
          offset: offset,
          child: Transform.rotate(
            angle: rotation,
            child: _buildCardContent(),
          ),
        );
      },
    );
  }

  Widget _buildCardContent() {
    final likeOpacity = (_dragOffset.dx / _swipeThreshold).clamp(0.0, 1.0);
    final nopeOpacity = (-_dragOffset.dx / _swipeThreshold).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            spreadRadius: 4,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.isAd)
              widget.adWidget ?? const SizedBox.shrink()
            else ...[
              // Photo gallery or placeholder
              if (_photos.isEmpty)
                _buildPlaceholderImage()
              else if (_photos.length == 1)
                CachedNetworkImage(
                  imageUrl: _photos.first,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: AppColors.surfaceVariant,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => _buildPlaceholderImage(),
                )
              else
                _buildPhotoGallery(),

              // Photo segment indicators (top bar, Tinder-style)
              if (_photos.length > 1)
                Positioned(
                  top: 8,
                  left: 12,
                  right: 12,
                  child: Row(
                    children: List.generate(_photos.length, (i) {
                      return Expanded(
                        child: Container(
                          height: 3,
                          margin: EdgeInsets.symmetric(horizontal: _photos.length > 6 ? 1 : 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            color: i == _currentPage
                                ? Colors.white
                                : Colors.white.withOpacity(0.35),
                          ),
                        ),
                      );
                    }),
                  ),
                ),

              // Gradient Overlay for text readability
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black87],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.6, 1.0],
                  ),
                ),
              ),
            ],

            // Gestures Detector Overlay
            LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onPanStart: _onPanStart,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  onTapUp: (details) {
                    if (widget.isAd || _photos.length <= 1) return;
                    final cardWidth = constraints.maxWidth;
                    final tapX = details.localPosition.dx;
                    
                    if (tapX < cardWidth / 2) {
                      // Left side tap -> previous photo
                      if (_currentPage > 0) {
                        setState(() {
                          _currentPage--;
                        });
                      }
                    } else {
                      // Right side tap -> next photo
                      if (_currentPage < _photos.length - 1) {
                        setState(() {
                          _currentPage++;
                        });
                      }
                    }
                  },
                  behavior: HitTestBehavior.translucent,
                );
              },
            ),

            // Profile info (bottom)
            if (!widget.isAd)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.pet!.name,
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${widget.pet!.age} ${widget.pet!.age == 1 ? "anno" : "anni"}',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w500,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            widget.pet!.species == PetSpecies.dog ? FontAwesomeIcons.dog : FontAwesomeIcons.cat,
                            size: 16,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${widget.pet!.breed} • ${widget.distanceKm!.toStringAsFixed(1)} km da te',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      if (widget.pet!.notes != null && widget.pet!.notes!.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          widget.pet!.notes!,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.white70,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (widget.pet!.character.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: widget.pet!.character.take(3).map((trait) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                trait,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

            // LIKE Overlay indicator
            if (likeOpacity > 0)
              Positioned(
                top: 40,
                left: 30,
                child: Transform.rotate(
                  angle: -0.15,
                  child: Opacity(
                    opacity: likeOpacity,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.green, width: 4),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.black12,
                      ),
                      child: const Text(
                        'LIKE',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // NOPE Overlay indicator
            if (nopeOpacity > 0)
              Positioned(
                top: 40,
                right: 30,
                child: Transform.rotate(
                  angle: 0.15,
                  child: Opacity(
                    opacity: nopeOpacity,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.red, width: 4),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.black12,
                      ),
                      child: const Text(
                        'NOPE',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoGallery() {
    final photos = _photos;
    return CachedNetworkImage(
      key: ValueKey('photo_${_currentPage}_${photos[_currentPage]}'),
      imageUrl: photos[_currentPage],
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: AppColors.surfaceVariant,
        child: const Center(child: CircularProgressIndicator()),
      ),
      errorWidget: (context, url, error) => _buildPlaceholderImage(),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: AppColors.surfaceVariant,
      child: Center(
        child: Icon(
          widget.pet?.species == PetSpecies.cat ? FontAwesomeIcons.cat : FontAwesomeIcons.dog,
          size: 80,
          color: AppColors.textSecondary.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}

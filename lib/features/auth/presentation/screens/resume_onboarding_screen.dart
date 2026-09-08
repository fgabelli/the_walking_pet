import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/analytics_service.dart';
import '../providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../profile/presentation/screens/create_profile_screen.dart';
import '../../../home/presentation/screens/main_screen.dart';
import 'login_screen.dart';

/// Dedicated recovery landing screen opened when tapping a push notification
/// while the user is logged out. Provides a frictionless resume flow without
/// triggering "account already exists" errors on Apple / Google re-auth.
class ResumeOnboardingScreen extends ConsumerStatefulWidget {
  final String? campaignId;

  const ResumeOnboardingScreen({super.key, this.campaignId});

  @override
  ConsumerState<ResumeOnboardingScreen> createState() => _ResumeOnboardingScreenState();
}

class _ResumeOnboardingScreenState extends ConsumerState<ResumeOnboardingScreen> {
  bool _isProcessing = false;

  Future<void> _handlePostLoginNavigation(User user) async {
    try {
      final profile = await ref.read(userServiceProvider).getUserById(user.uid);
      if (!mounted) return;

      if (profile == null || profile.firstName.trim().isEmpty) {
        // Direct to profile completion onboarding
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            settings: const RouteSettings(name: 'create_profile'),
            builder: (_) => const CreateProfileScreen(),
          ),
          (route) => false,
        );
      } else {
        // Profile already exists and complete
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            settings: const RouteSettings(name: 'main'),
            builder: (_) => const MainScreen(),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      // Fallback: send to CreateProfileScreen
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          settings: const RouteSettings(name: 'create_profile'),
          builder: (_) => const CreateProfileScreen(),
        ),
        (route) => false,
      );
    }
  }

  Future<void> _continueWithApple() async {
    setState(() => _isProcessing = true);
    try {
      await ref.read(authControllerProvider.notifier).signInWithApple();
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        if (widget.campaignId != null) {
          await AnalyticsService.logEvent(
            'campaign_auth_resumed',
            {'campaign_id': widget.campaignId!, 'provider': 'apple'},
          );
        }
        await _handlePostLoginNavigation(user);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Accesso con Apple non completato: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _continueWithGoogle() async {
    setState(() => _isProcessing = true);
    try {
      await ref.read(authControllerProvider.notifier).signInWithGoogle();
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        if (widget.campaignId != null) {
          await AnalyticsService.logEvent(
            'campaign_auth_resumed',
            {'campaign_id': widget.campaignId!, 'provider': 'google'},
          );
        }
        await _handlePostLoginNavigation(user);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Accesso con Google non completato: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = _isProcessing || authState.isLoading;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              // Logo
              Center(
                child: Image.asset(
                  'assets/images/dogzn/dogzn_logo.png',
                  width: 190,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 36),

              // Title
              Text(
                'Bentornato su DOGZN!',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Completa la configurazione del tuo profilo per iniziare subito a trovare nuovi compagni di passeggiata e accedere alla community.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Hero Button: Continue with Apple
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Colors.black87, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: isLoading ? null : _continueWithApple,
                icon: const FaIcon(FontAwesomeIcons.apple, size: 24, color: Colors.black),
                label: const Text(
                  'Continua con Apple',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Secondary Button: Continue with Google
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: isLoading ? null : _continueWithGoogle,
                icon: const FaIcon(FontAwesomeIcons.google, size: 20),
                label: const Text(
                  'Continua con Google',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              if (isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                ),

              // Divider
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'oppure',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 24),

              // Email login fallback
              TextButton(
                onPressed: isLoading
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            settings: const RouteSettings(name: 'login'),
                            builder: (_) => const LoginScreen(),
                          ),
                        );
                      },
                child: const Text(
                  'Hai effettuato l\'accesso con email e password? Accedi qui',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

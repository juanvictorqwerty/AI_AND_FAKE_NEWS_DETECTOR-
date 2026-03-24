import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ai_fake_news_detector/services/notification_service.dart';
import 'package:ai_fake_news_detector/services/auth_controller.dart';

class PermanentFactCheck extends StatefulWidget {
  const PermanentFactCheck({super.key});

  @override
  State<PermanentFactCheck> createState() => _PermanentFactCheckState();
}

class _PermanentFactCheckState extends State<PermanentFactCheck>
    with SingleTickerProviderStateMixin {
  final NotificationService _notificationService = Get.find<NotificationService>();
  final AuthController _authController = Get.find<AuthController>();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Obx(() {
      final isRunning = _notificationService.isServiceRunning.value;
      final isLoggedIn = _authController.isLoggedIn;

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1C1C1E)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isRunning
                  ? const Color(0xFF34C759).withOpacity(0.15)
                  : Colors.black.withOpacity(isDark ? 0.3 : 0.07),
              blurRadius: isRunning ? 16 : 10,
              offset: const Offset(0, 4),
              spreadRadius: isRunning ? 2 : 0,
            ),
          ],
          border: Border.all(
            color: isRunning
                ? const Color(0xFF34C759).withOpacity(0.3)
                : (isDark
                    ? Colors.white.withOpacity(0.06)
                    : Colors.black.withOpacity(0.06)),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Status dot with pulse
              SizedBox(
                width: 28,
                height: 28,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (isRunning)
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (_, __) => Container(
                          width: 28 * _pulseAnimation.value,
                          height: 28 * _pulseAnimation.value,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF34C759)
                                .withOpacity(0.15 * _pulseAnimation.value),
                          ),
                        ),
                      ),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: !isLoggedIn
                            ? const Color(0xFFFF9500)
                            : isRunning
                                ? const Color(0xFF34C759)
                                : (isDark
                                    ? Colors.white24
                                    : Colors.black26),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // Label
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Quick Fact Check',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      !isLoggedIn
                          ? 'Login required'
                          : isRunning
                              ? 'Active in notification shade'
                              : 'Tap to enable',
                      style: TextStyle(
                        fontSize: 11,
                        color: !isLoggedIn
                            ? const Color(0xFFFF9500)
                            : isRunning
                                ? const Color(0xFF34C759)
                                : (isDark
                                    ? Colors.white38
                                    : Colors.black38),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),

              // Toggle button
              if (isLoggedIn)
                GestureDetector(
                  onTap: () async {
                    if (isRunning) {
                      await _notificationService.stopNotificationService();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Fact check notification stopped'),
                            backgroundColor: Colors.black87,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      }
                    } else {
                      final success =
                          await _notificationService.startNotificationService();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? 'Notification service started'
                                  : 'Failed to start service',
                            ),
                            backgroundColor:
                                success ? const Color(0xFF34C759) : Colors.red,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      }
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    width: 44,
                    height: 26,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(13),
                      color: isRunning
                          ? const Color(0xFF34C759)
                          : (isDark
                              ? Colors.white12
                              : Colors.black12),
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      alignment: isRunning
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.all(3),
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}
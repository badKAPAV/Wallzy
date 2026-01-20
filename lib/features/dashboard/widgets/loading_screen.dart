import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/svg.dart';
import 'package:lottie/lottie.dart';

class LoadingScreen extends StatelessWidget {
  final bool isAutoRecording;
  final ValueNotifier<int>? autoRecordTotal;
  final ValueNotifier<int>? autoRecordProgress;

  const LoadingScreen({
    super.key,
    this.isAutoRecording = false,
    this.autoRecordTotal,
    this.autoRecordProgress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      key: const ValueKey('loading_screen'),
      // Explicit background color prevents GPU blending jank during transitions
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
          // 1. BACKGROUND LAYER
          Positioned(
            top: -230,
            right: -100,
            left: -100,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: SvgPicture.asset(
                'assets/vectors/landing_vector.svg',
                width: 500,
                height: 500,
                colorFilter: ColorFilter.mode(
                  theme.colorScheme.primary.withValues(alpha: 0.6),
                  BlendMode.srcIn,
                ),
              ),
            ),
          ).animate().fadeIn(duration: 1200.ms, curve: Curves.easeOutQuad),

          // 2. MAIN CONTENT LAYER
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children:
                    [
                          const Spacer(),

                          // --- LOTTIE ANIMATION ---
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Lottie.asset(
                              'assets/json/cubes_animation.json',
                              width: 200,
                              height: 200,
                              fit: BoxFit.contain,
                              delegates: LottieDelegates(
                                values: [
                                  ValueDelegate.strokeColor(
                                    const ['**'],
                                    value:
                                        theme.colorScheme.surfaceContainerHigh,
                                  ),
                                  ValueDelegate.color(const [
                                    '**',
                                  ], value: theme.colorScheme.primary),
                                ],
                              ),
                            ),
                          ),

                          // --- BRAND TEXT ---
                          Text(
                            'ledgr',
                            style: TextStyle(
                              fontFamily: 'momo',
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.5,
                              color: colorScheme.primary,
                            ),
                          ),

                          const SizedBox(height: 12),

                          Text(
                            'Your money, mastered.',
                            style: TextStyle(
                              fontFamily: 'momo',
                              fontSize: 16,
                              fontWeight: FontWeight.normal,
                              color: colorScheme.primary.withValues(alpha: 0.6),
                            ),
                          ),

                          const SizedBox(height: 48),

                          // --- PROGRESS INDICATOR ---
                          if (isAutoRecording &&
                              autoRecordTotal != null &&
                              autoRecordProgress != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 48,
                              ),
                              child: ValueListenableBuilder<int>(
                                valueListenable: autoRecordTotal!,
                                builder: (context, total, _) {
                                  return ValueListenableBuilder<int>(
                                    valueListenable: autoRecordProgress!,
                                    builder: (context, progress, _) {
                                      final percentage = total > 0
                                          ? progress / total
                                          : 0.0;

                                      if (total <= 0)
                                        return const SizedBox.shrink();

                                      return Column(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            child: LinearProgressIndicator(
                                              value: percentage,
                                              minHeight: 6,
                                              backgroundColor: colorScheme
                                                  .surfaceContainerHighest,
                                              valueColor:
                                                  AlwaysStoppedAnimation(
                                                    colorScheme.primary,
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            "Syncing transactions ($progress/$total)...",
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                                  color: colorScheme.outline,
                                                  letterSpacing: 0.5,
                                                ),
                                          ),
                                        ],
                                      ).animate().fadeIn();
                                    },
                                  );
                                },
                              ),
                            ),

                          const Spacer(),
                        ]
                        .animate(interval: 150.ms) // Smoother stagger
                        // ENTRANCE
                        .fadeIn(duration: 800.ms, curve: Curves.easeOutQuad)
                        .moveY(
                          begin: 40,
                          end: 0,
                          duration: 800.ms,
                          curve: Curves.easeOutQuad,
                        )
                        // STAY ALIVE
                        // We add a subtle breathing effect so if loading is slow,
                        // the screen doesn't look frozen.
                        .then()
                        .shimmer(
                          duration: 2000.ms,
                          color: Colors.white12,
                          delay: 500.ms,
                        ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

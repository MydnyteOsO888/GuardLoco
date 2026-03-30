import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import 'live_screen.dart';
import 'clips_screen.dart';
import 'status_screen.dart';
import 'config_screen.dart';

final _navIndexProvider = StateProvider<int>((ref) => 0);

class ShellScreen extends ConsumerWidget {
  const ShellScreen({super.key});

  static const _screens = [
    LiveScreen(),
    ClipsScreen(),
    StatusScreen(),
    ConfigScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(_navIndexProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: IndexedStack(
        index: index,
        children: _screens,
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: index,
        onTap: (i) => ref.read(_navIndexProvider.notifier).state = i,
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.bgColor,
        border: Border(top: BorderSide(color: AppTheme.borderColor)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(icon: '📡', label: 'LIVE',   index: 0, current: currentIndex, onTap: onTap),
              _NavItem(icon: '🎞',  label: 'CLIPS',  index: 1, current: currentIndex, onTap: onTap),
              _NavItem(icon: '📊', label: 'STATUS', index: 2, current: currentIndex, onTap: onTap),
              _NavItem(icon: '⚙️', label: 'CONFIG', index: 3, current: currentIndex, onTap: onTap),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String icon;
  final String label;
  final int index;
  final int current;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.icon, required this.label,
    required this.index, required this.current, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = index == current;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Syne',
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: active ? AppTheme.accentColor : AppTheme.mutedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

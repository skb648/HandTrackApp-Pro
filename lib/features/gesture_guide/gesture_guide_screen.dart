import 'package:flutter/material.dart';
import 'package:airtouch_ultimate/core/constants/app_theme.dart';
import 'package:airtouch_ultimate/core/constants/app_typography.dart';
import 'package:airtouch_ultimate/core/constants/gesture_constants.dart';

/// Gesture Guide Screen - 5-Step Tutorial
class GestureGuideScreen extends StatefulWidget {
  const GestureGuideScreen({super.key});

  @override
  State<GestureGuideScreen> createState() => _GestureGuideScreenState();
}

class _GestureGuideScreenState extends State<GestureGuideScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildPaginationDots(),
              const SizedBox(height: 24),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) => setState(() => _currentPage = index),
                  itemCount: GestureTutorials.all.length,
                  itemBuilder: (context, index) => _buildGestureCard(GestureTutorials.all[index]),
                ),
              ),
              const SizedBox(height: 24),
              _buildNavigationButtons(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Gesture Guide', style: AppTypography.heading2),
              const SizedBox(height: 4),
              Text('${_currentPage + 1} of ${GestureTutorials.all.length} gestures', style: AppTypography.caption),
            ],
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primary800,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.glassBorder),
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(GestureTutorials.all.length, (index) {
        final isActive = index == _currentPage;
        final color = GestureTutorials.all[index].color;
        return GestureDetector(
          onTap: () => _pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive ? color : AppTheme.textMuted.withOpacity(0.3),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildGestureCard(GestureTutorialData gesture) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.primary800,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: gesture.color.withOpacity(0.3)),
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: gesture.color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Center(child: Text(gesture.icon, style: AppTypography.emojiIcon)),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: gesture.color, borderRadius: BorderRadius.circular(20)),
              child: Text(gesture.badge, style: AppTypography.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 16),
            Text(gesture.name, style: AppTypography.heading1),
            const SizedBox(height: 12),
            Text(gesture.description, style: AppTypography.bodyMedium.copyWith(color: AppTheme.textSecondary), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppTheme.primary900, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: gesture.steps.asMap().entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(color: gesture.color, shape: BoxShape.circle),
                          child: Center(child: Text('${entry.key + 1}', style: AppTypography.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w700))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(entry.value, style: AppTypography.bodyMedium)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: gesture.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border(left: BorderSide(color: gesture.color, width: 4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('💡', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Text('Pro Tip', style: AppTypography.label.copyWith(color: gesture.color)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(gesture.proTip, style: AppTypography.bodySmall.copyWith(color: AppTheme.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    final isFirstPage = _currentPage == 0;
    final isLastPage = _currentPage == GestureTutorials.all.length - 1;
    final currentColor = GestureTutorials.all[_currentPage].color;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: isFirstPage ? null : () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
              child: Container(
                height: 52,
                decoration: BoxDecoration(color: AppTheme.primary800, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.glassBorder)),
                child: Center(
                  child: Opacity(
                    opacity: isFirstPage ? 0.3 : 1.0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.arrow_back, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text('Previous', style: AppTypography.button),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: () {
                if (isLastPage) {
                  Navigator.pop(context);
                } else {
                  _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                }
              },
              child: Container(
                height: 52,
                decoration: BoxDecoration(color: currentColor, borderRadius: BorderRadius.circular(12)),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(isLastPage ? 'Got it! ✓' : 'Next', style: AppTypography.button),
                      if (!isLastPage) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

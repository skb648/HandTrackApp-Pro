import 'package:flutter/material.dart';
import 'package:airtouch_ultimate/core/constants/app_theme.dart';
import 'package:airtouch_ultimate/core/constants/app_typography.dart';

/// Air Keyboard Screen - Dual Mode
class AirKeyboardScreen extends StatefulWidget {
  const AirKeyboardScreen({super.key});

  @override
  State<AirKeyboardScreen> createState() => _AirKeyboardScreenState();
}

class _AirKeyboardScreenState extends State<AirKeyboardScreen> with TickerProviderStateMixin {
  String _typedText = '';
  bool _isShiftActive = false;
  bool _isNumberMode = false;
  bool _isTabletMode = false;

  late AnimationController _laserLeftController;
  late AnimationController _laserRightController;

  final List<List<String>> _letterRows = [
    ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'],
    ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'],
    ['⇧', 'z', 'x', 'c', 'v', 'b', 'n', 'm', '⌫'],
    ['123', ',', '␣', '.', '↵'],
  ];

  final List<List<String>> _numberRows = [
    ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
    ['-', '/', ':', ';', '(', ')', '\$', '&', '@'],
    ['#', '=', '+', '%', '*', '"', '\'', '?', '⌫'],
    ['ABC', ',', '␣', '.', '↵'],
  ];

  @override
  void initState() {
    super.initState();
    _laserLeftController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat(reverse: true);
    _laserRightController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _laserRightController.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _laserLeftController.dispose();
    _laserRightController.dispose();
    super.dispose();
  }

  void _onKeyTap(String key) {
    setState(() {
      switch (key) {
        case '⌫':
          if (_typedText.isNotEmpty) _typedText = _typedText.substring(0, _typedText.length - 1);
          break;
        case '↵':
          _typedText += '\n';
          break;
        case '␣':
          _typedText += ' ';
          break;
        case '⇧':
          _isShiftActive = !_isShiftActive;
          break;
        case '123':
        case 'ABC':
          _isNumberMode = !_isNumberMode;
          break;
        default:
          _typedText += _isShiftActive ? key.toUpperCase() : key;
          _isShiftActive = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient)),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                _buildModeToggle(),
                const SizedBox(height: 16),
                _buildOutputPreview(),
                const Spacer(),
                _isTabletMode ? _buildTabletKeyboard() : _buildMobileKeyboard(),
              ],
            ),
          ),
          if (!_isTabletMode) _buildLaserPointers(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: AppTheme.accent, borderRadius: BorderRadius.circular(12)),
                child: const Center(child: Text('⌨️', style: TextStyle(fontSize: 20))),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Air Keyboard', style: AppTypography.heading3),
                  Text(_isTabletMode ? '🖐 Spatial Mode (Tablet)' : '☝️ Laser Mode (Mobile)', style: AppTypography.caption),
                ],
              ),
            ],
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: AppTheme.primary800, shape: BoxShape.circle, border: Border.all(color: AppTheme.glassBorder)),
              child: const Icon(Icons.close, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildModeButton('Mobile', !_isTabletMode, () => setState(() => _isTabletMode = false)),
        const SizedBox(width: 12),
        _buildModeButton('Tablet', _isTabletMode, () => setState(() => _isTabletMode = true)),
      ],
    );
  }

  Widget _buildModeButton(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.accent : AppTheme.primary800,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? AppTheme.accent : AppTheme.glassBorder),
        ),
        child: Text(label, style: AppTypography.label.copyWith(color: isActive ? Colors.white : AppTheme.textSecondary)),
      ),
    );
  }

  Widget _buildOutputPreview() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.primary800, borderRadius: BorderRadius.circular(16)),
      child: Text(
        _typedText.isEmpty ? 'Type using air gestures...' : _typedText,
        style: AppTypography.bodyMedium.copyWith(color: _typedText.isEmpty ? AppTheme.textMuted : Colors.white),
      ),
    );
  }

  Widget _buildMobileKeyboard() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primary800,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.textMuted.withOpacity(0.5), borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 12),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: AppTheme.primary900, borderRadius: BorderRadius.circular(12)),
            child: Text(
              _typedText.isEmpty ? 'Tap keys to type...' : _typedText,
              style: AppTypography.bodySmall.copyWith(color: _typedText.isEmpty ? AppTheme.textMuted : Colors.white),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _buildKeyboardLayout(_isNumberMode ? _numberRows : _letterRows),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTabletKeyboard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppTheme.primary800, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.glassBorder)),
      child: _buildKeyboardLayout(_isNumberMode ? _numberRows : _letterRows),
    );
  }

  Widget _buildKeyboardLayout(List<List<String>> rows) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: rows.map((row) => _buildKeyboardRow(row)).toList(),
    );
  }

  Widget _buildKeyboardRow(List<String> row) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: row.map((key) => _buildKey(key)).toList(),
      ),
    );
  }

  Widget _buildKey(String key) {
    final isSpecial = ['⇧', '⌫', '123', 'ABC', '↵'].contains(key);
    final isSpace = key == '␣';
    final isEnter = key == '↵';
    double flex = 1;
    if (isSpace) flex = 4;
    if (isEnter) flex = 1.6;
    if (isSpecial && !isSpace && !isEnter) flex = 1.4;

    return Expanded(
      flex: flex.toInt(),
      child: GestureDetector(
        onTap: () => _onKeyTap(key),
        child: Container(
          height: 44,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isEnter ? AppTheme.accent.withOpacity(0.2) : AppTheme.primary900,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isEnter ? AppTheme.accent.withOpacity(0.5) : AppTheme.glassBorder),
          ),
          child: Center(
            child: Text(
              isSpace ? 'SPACE' : _isShiftActive && key.length == 1 ? key.toUpperCase() : key,
              style: TextStyle(
                color: isEnter ? AppTheme.accent : isSpecial ? AppTheme.textSecondary : Colors.white,
                fontSize: 14,
                fontWeight: _isShiftActive && key == '⇧' ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLaserPointers() {
    return Stack(
      children: [
        AnimatedBuilder(
          animation: _laserLeftController,
          builder: (context, child) {
            final offset = Tween<double>(begin: -12, end: 0).chain(CurveTween(curve: Curves.easeInOut)).evaluate(_laserLeftController);
            return Positioned(
              left: 60,
              bottom: 200 + offset,
              child: _buildLaserDot('L', AppTheme.laserLeft),
            );
          },
        ),
        AnimatedBuilder(
          animation: _laserRightController,
          builder: (context, child) {
            final offset = Tween<double>(begin: 0, end: -12).chain(CurveTween(curve: Curves.easeInOut)).evaluate(_laserRightController);
            return Positioned(
              right: 60,
              bottom: 180 + offset,
              child: _buildLaserDot('R', AppTheme.laserRight),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLaserDot(String label, Color color) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.2),
        border: Border.all(color: color, width: 2),
      ),
      child: Center(child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900))),
    );
  }
}

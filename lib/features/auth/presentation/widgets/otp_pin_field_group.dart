import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';

/// Production-grade 6-digit independent PIN input group for mobile medical workflows.
/// Features: auto-advancing focus, backspace backward step, clipboard paste distribution,
/// tactile Haptic Feedback, and horizontal Shake Animation upon verification error.
/// Conforms to: AGENTS-DESIGN.md Rule 19 (Touch Target) & Rule 26 (Micro-animation).
class OtpPinFieldGroup extends StatefulWidget {
  final int length;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onCompleted;
  final bool hasError;
  final bool enabled;

  const OtpPinFieldGroup({
    super.key,
    this.length = 6,
    required this.onChanged,
    this.onCompleted,
    this.hasError = false,
    this.enabled = true,
  });

  @override
  State<OtpPinFieldGroup> createState() => _OtpPinFieldGroupState();
}

class _OtpPinFieldGroupState extends State<OtpPinFieldGroup>
    with SingleTickerProviderStateMixin {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      widget.length,
      (_) => TextEditingController(),
    );
    _focusNodes = List.generate(
      widget.length,
      (_) => FocusNode(),
    );

    // Initialize Shake Animation Controller
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _shakeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _shakeController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant OtpPinFieldGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasError && !oldWidget.hasError) {
      // Trigger heavy tactile haptic feedback and shake animation upon error
      HapticFeedback.heavyImpact();
      _shakeController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _shakeController.dispose();
    super.dispose();
  }

  String _getCombinedOtp() {
    return _controllers.map((c) => c.text).join();
  }

  void _onDigitChanged(int index, String value) {
    if (value.isNotEmpty) {
      // Light tactile haptic feedback on digit press
      HapticFeedback.lightImpact();

      // If user pasted multiple characters
      if (value.length > 1) {
        final digits = value.replaceAll(RegExp(r'\D'), '');
        for (int i = 0; i < widget.length; i++) {
          if (i < digits.length) {
            _controllers[i].text = digits[i];
          }
        }
        final finalOtp = _getCombinedOtp();
        widget.onChanged(finalOtp);
        if (finalOtp.length == widget.length) {
          widget.onCompleted?.call(finalOtp);
        }
        return;
      }

      // Single digit entry: move focus to next box
      if (index < widget.length - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    }

    final currentOtp = _getCombinedOtp();
    widget.onChanged(currentOtp);

    if (currentOtp.length == widget.length) {
      widget.onCompleted?.call(currentOtp);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        // Compute 4-cycle sine wave shake offset
        final offset = sin(_shakeAnimation.value * pi * 4) * 8.0;
        return Transform.translate(
          offset: Offset(offset, 0),
          child: child,
        );
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(widget.length, (index) {
          final isFilled = _controllers[index].text.isNotEmpty;

          return Container(
            width: 48,
            height: 56,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: widget.enabled
                  ? (isFilled ? AppColors.primaryLight : AppColors.surface)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.hasError
                    ? AppColors.danger
                    : (_focusNodes[index].hasFocus
                        ? AppColors.primary
                        : (isFilled ? AppColors.primary : AppColors.border)),
                width: (_focusNodes[index].hasFocus || widget.hasError) ? 2.0 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: RawKeyboardListener(
              focusNode: FocusNode(), // Auxiliary node capturing Backspace key on empty boxes
              onKey: (event) {
                if (event is RawKeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.backspace) {
                  if (_controllers[index].text.isEmpty && index > 0) {
                    _controllers[index - 1].clear();
                    _focusNodes[index - 1].requestFocus();
                    widget.onChanged(_getCombinedOtp());
                  }
                }
              },
              child: TextField(
                controller: _controllers[index],
                focusNode: _focusNodes[index],
                enabled: widget.enabled,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  color: widget.hasError
                      ? AppColors.danger
                      : AppColors.textPrimary,
                ),
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                onChanged: (val) => _onDigitChanged(index, val),
              ),
            ),
          );
        }),
      ),
    );
  }
}

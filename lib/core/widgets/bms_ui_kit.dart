import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';

/// Shared Vietnamese clinical formatting utilities.
class BmsFormatters {
  BmsFormatters._();

  static String currency(num? value) {
    if (value == null) return '0 đ';
    final rounded = value.round();
    final formatted = NumberFormat('#,###', 'vi_VN').format(rounded);
    return '${formatted.replaceAll(',', '.')} đ';
  }

  static String date(dynamic raw) {
    final dt = _parseDateTime(raw);
    if (dt == null) return 'Chưa ghi nhận';
    return DateFormat('dd/MM/yyyy').format(dt);
  }

  static String dateTime(dynamic raw) {
    final dt = _parseDateTime(raw);
    if (dt == null) return 'Chưa ghi nhận';
    return DateFormat('dd/MM/yyyy HH:mm').format(dt);
  }

  static String time(dynamic raw) {
    final dt = _parseDateTime(raw);
    if (dt == null) return raw?.toString() ?? '—';
    return DateFormat('HH:mm').format(dt);
  }

  static String isoDate(DateTime dt) {
    return DateFormat('yyyy-MM-dd').format(dt);
  }

  static DateTime? _parseDateTime(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw.toLocal();
    final str = raw.toString().trim();
    if (str.isEmpty) return null;
    final parsed = DateTime.tryParse(str);
    if (parsed != null) return parsed.toLocal();
    for (final fmt in const ['dd/MM/yyyy HH:mm', 'dd/MM/yyyy']) {
      try {
        return DateFormat(fmt).parseStrict(str);
      } catch (_) {}
    }
    return null;
  }

  static String genderVi(String? raw) {
    final g = (raw ?? '').trim().toLowerCase();
    switch (g) {
      case 'male':
      case 'nam':
      case 'm':
        return 'Nam';
      case 'female':
      case 'nữ':
      case 'nu':
      case 'f':
        return 'Nữ';
      case 'other':
      case 'khác':
        return 'Khác';
      default:
        return 'Chưa cập nhật';
    }
  }

  static String shiftTypeVi(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'morning':
        return 'Ca sáng (07:00 - 11:30)';
      case 'afternoon':
        return 'Ca chiều (13:00 - 17:00)';
      case 'evening':
        return 'Ca tối (17:00 - 21:00)';
      case 'night':
        return 'Ca đêm';
      case 'fullday':
        return 'Cả ngày (07:00 - 17:00)';
      default:
        return raw?.toString().isNotEmpty == true ? raw.toString() : 'Ca trực';
    }
  }

  static String paymentMethodVi(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'cash':
      case '1':
        return 'Tiền mặt tại quầy';
      case 'vnpay':
      case '2':
        return 'Cổng VNPay';
      case 'banktransfer':
      case '3':
        return 'Chuyển khoản ngân hàng';
      case 'creditcard':
      case '4':
        return 'Thẻ POS / Tín dụng';
      case 'momo':
      case '5':
        return 'Ví MoMo';
      case 'bankingqr':
      case 'sepay':
      case 'vietqr':
      case '6':
        return 'Chuyển khoản SePay VietQR';
      case 'reception':
      case '7':
        return 'Thu tại quầy tiếp đón';
      default:
        return raw?.toString().isNotEmpty == true
            ? raw.toString()
            : 'Chuyển khoản SePay VietQR';
    }
  }
}

/// Pure flat SaaS card surface with subtle 1px border and zero heavy shadows.
class BmsSoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderRadius;
  final VoidCallback? onTap;

  const BmsSoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius = 18,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Material(
      color: backgroundColor ?? AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        side: BorderSide(color: borderColor ?? AppColors.cardBorder, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap != null
          ? InkWell(
              borderRadius: BorderRadius.circular(borderRadius),
              onTap: onTap,
              child: Padding(padding: padding, child: child),
            )
          : Padding(padding: padding, child: child),
    );
    if (margin != null) {
      return Padding(padding: margin!, child: card);
    }
    return card;
  }
}

/// Top page header card matching BMS Web Workstation flat banner style.
class BmsPageHeaderCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final Widget? bottom;
  final String? badgeText;

  const BmsPageHeaderCard({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.bottom,
    this.badgeText,
  });

  @override
  Widget build(BuildContext context) {
    return BmsSoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (badgeText != null && badgeText!.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          badgeText!,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                    ],
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
          if (bottom != null) ...[
            const SizedBox(height: 14),
            bottom!,
          ],
        ],
      ),
    );
  }
}

/// Tabular-figure KPI metric card matching BMS Web dashboard tiles.
class BmsKpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color accentColor;
  final Color? softBgColor;
  final VoidCallback? onTap;

  const BmsKpiCard({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    required this.icon,
    this.accentColor = AppColors.primary,
    this.softBgColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = softBgColor ?? accentColor.withValues(alpha: 0.10);
    return BmsSoftCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Responsive 2-column KPI grid without fixed overflow issues.
class BmsKpiGrid extends StatelessWidget {
  final List<BmsKpiCard> cards;

  const BmsKpiGrid({super.key, required this.cards});

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();
    final rows = <Widget>[];
    for (var i = 0; i < cards.length; i += 2) {
      final left = cards[i];
      final right = i + 1 < cards.length ? cards[i + 1] : null;
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: left),
              const SizedBox(width: 10),
              Expanded(child: right ?? const SizedBox.shrink()),
            ],
          ),
        ),
      );
      if (i + 2 < cards.length) {
        rows.add(const SizedBox(height: 10));
      }
    }
    return Column(children: rows);
  }
}

/// Filter chip descriptor for [BmsSearchFilterBar].
class BmsFilterChipItem {
  final String key;
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const BmsFilterChipItem({
    required this.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });
}

/// Single-line pill search + horizontal scrollable filter chips.
class BmsSearchFilterBar extends StatelessWidget {
  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final List<BmsFilterChipItem> filterChips;
  final Widget? trailing;

  const BmsSearchFilterBar({
    super.key,
    this.controller,
    this.hintText = 'Tìm kiếm...',
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.filterChips = const [],
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (controller != null || onChanged != null)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  onSubmitted: onSubmitted,
                  decoration: InputDecoration(
                    hintText: hintText,
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    suffixIcon:
                        controller != null && controller!.text.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              controller!.clear();
                              onClear?.call();
                              onChanged?.call('');
                            },
                            icon: const Icon(Icons.close_rounded, size: 18),
                          )
                        : null,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: const BorderSide(color: AppColors.cardBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
        if (filterChips.isNotEmpty) ...[
          if (controller != null || onChanged != null)
            const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: filterChips.map((chip) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(chip.label),
                    selected: chip.selected,
                    showCheckmark: false,
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surface,
                    side: BorderSide(
                      color: chip.selected
                          ? AppColors.primary
                          : AppColors.cardBorder,
                    ),
                    labelStyle: TextStyle(
                      fontSize: 12.5,
                      fontWeight: chip.selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: chip.selected
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                    onSelected: (_) => chip.onSelected(),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }
}

/// Clean segmented pill switcher for sub-tabs.
class BmsSegmentedTabs extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const BmsSegmentedTabs({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: List.generate(tabs.length, (idx) {
          final active = idx == selectedIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(idx),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(
                  vertical: 9,
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  color: active ? AppColors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: active
                      ? Border.all(color: AppColors.cardBorder)
                      : null,
                ),
                child: Text(
                  tabs[idx],
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    color: active ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Clinical status & priority badge mapping backend codes to clean Vietnamese labels & pastel colors.
class BmsStatusPill extends StatelessWidget {
  final String status;
  final String? customLabel;

  const BmsStatusPill({super.key, required this.status, this.customLabel});

  static ({String label, Color bg, Color fg}) resolve(String rawStatus) {
    final key = rawStatus.trim().toLowerCase().replaceAll('_', '');
    switch (key) {
      case 'confirmed':
      case 'scheduled':
        return (
          label: 'Đã xác nhận',
          bg: AppColors.primaryLight,
          fg: AppColors.primaryDark,
        );
      case 'pending':
      case 'pendingentry':
      case 'awaitingpayment':
        return (
          label: 'Chờ xử lý',
          bg: AppColors.warningLight,
          fg: AppColors.warningText,
        );
      case 'checkedin':
        return (
          label: 'Đã check-in',
          bg: AppColors.tealLight,
          fg: AppColors.tealText,
        );
      case 'inprogress':
      case 'inanalysis':
      case 'processing':
      case 'testing':
      case 'collecting':
      case 'samplecollected':
        return (
          label: 'Đang thực hiện',
          bg: AppColors.primaryLight,
          fg: AppColors.primaryDark,
        );
      case 'called':
        return (
          label: 'Đang gọi số',
          bg: AppColors.warningLight,
          fg: AppColors.warningText,
        );
      case 'waiting':
        return (
          label: 'Đang chờ',
          bg: AppColors.surfaceMuted,
          fg: AppColors.textSecondary,
        );
      case 'completed':
      case 'approved':
      case 'doctorapproved':
      case 'finalized':
        return (
          label: key == 'finalized'
              ? 'Đã khóa bệnh án'
              : (key == 'approved' || key == 'doctorapproved')
              ? 'Đã duyệt'
              : 'Hoàn thành',
          bg: AppColors.successLight,
          fg: AppColors.successText,
        );
      case 'paid':
        return (
          label: 'Đã thanh toán',
          bg: AppColors.successLight,
          fg: AppColors.successText,
        );
      case 'unpaid':
        return (
          label: 'Chờ thanh toán',
          bg: AppColors.warningLight,
          fg: AppColors.warningText,
        );
      case 'partiallyrefunded':
        return (
          label: 'Hoàn phí một phần',
          bg: AppColors.warningLight,
          fg: AppColors.warningText,
        );
      case 'refunded':
        return (
          label: 'Đã hoàn phí',
          bg: AppColors.surfaceMuted,
          fg: AppColors.textSecondary,
        );
      case 'cancelled':
      case 'voided':
      case 'rejected':
        return (
          label: 'Đã hủy',
          bg: AppColors.dangerLight,
          fg: AppColors.dangerText,
        );
      case 'noshow':
      case 'skipped':
        return (
          label: 'Vắng mặt',
          bg: AppColors.dangerLight,
          fg: AppColors.dangerText,
        );
      case 'rescheduled':
        return (
          label: 'Đã dời lịch',
          bg: AppColors.warningLight,
          fg: AppColors.warningText,
        );
      case 'stat':
      case 'critical':
      case 'criticalpanic':
      case 'panic':
      case 'hh':
      case 'll':
        return (
          label: key == 'stat' ? 'Cấp cứu (STAT)' : 'Nguy kịch',
          bg: AppColors.dangerLight,
          fg: AppColors.dangerText,
        );
      case 'urgent':
      case 'high':
      case 'h':
      case 'severe':
        return (
          label: key == 'urgent'
              ? 'Khẩn'
              : (key == 'severe' ? 'Nặng' : 'Cao (H)'),
          bg: AppColors.warningLight,
          fg: AppColors.warningText,
        );
      case 'low':
      case 'l':
      case 'moderate':
        return (
          label: key == 'moderate' ? 'Trung bình' : 'Thấp (L)',
          bg: AppColors.warningLight,
          fg: AppColors.warningText,
        );
      case 'routine':
      case 'normal':
      case 'n':
      case 'mild':
        return (
          label: key == 'mild'
              ? 'Nhẹ'
              : (key == 'routine' ? 'Thường quy' : 'Bình thường'),
          bg: AppColors.successLight,
          fg: AppColors.successText,
        );
      case 'draft':
        return (
          label: 'Bản nháp',
          bg: AppColors.surfaceMuted,
          fg: AppColors.textSecondary,
        );
      case 'ordered':
        return (
          label: 'Đã chỉ định',
          bg: AppColors.primaryLight,
          fg: AppColors.primaryDark,
        );
      case 'active':
        return (
          label: 'Đang hoạt động',
          bg: AppColors.successLight,
          fg: AppColors.successText,
        );
      default:
        return (
          label: rawStatus.isEmpty ? 'Chưa ghi nhận' : rawStatus,
          bg: AppColors.surfaceMuted,
          fg: AppColors.textSecondary,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final resolved = resolve(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: resolved.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        customLabel ?? resolved.label,
        style: TextStyle(
          color: resolved.fg,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Section header row with optional action button.
class BmsSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const BmsSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Key-value metadata row inside cards and bottom sheets.
class BmsInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isMono;
  final bool isBold;
  final Color? valueColor;

  const BmsInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.isMono = false,
    this.isBold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontFamily: isMono ? 'monospace' : null,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
                color: valueColor ?? AppColors.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Clean empty state card.
class BmsEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const BmsEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return BmsSoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 28, color: AppColors.primary),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

/// Clean error state card with retry trigger.
class BmsErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const BmsErrorState({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return BmsSoftCard(
      backgroundColor: AppColors.dangerLight,
      borderColor: AppColors.dangerBorder,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 36,
            color: AppColors.danger,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.dangerText,
              height: 1.4,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Thử lại'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Clean loading indicator state.
class BmsLoadingState extends StatelessWidget {
  final String? message;

  const BmsLoadingState({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                strokeWidth: 2.6,
                color: AppColors.primary,
              ),
            ),
            if (message != null && message!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

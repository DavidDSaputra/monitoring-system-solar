import 'package:flutter/material.dart';

class PlantSyncTime {
  const PlantSyncTime._();

  static String format(String? raw, {DateTime? fallback, DateTime? now}) {
    final parsed = _parse(raw) ?? fallback;
    if (parsed == null) {
      final text = raw?.trim();
      return text == null || text.isEmpty ? 'belum tersedia' : text;
    }

    final local = parsed.toLocal();
    final current = (now ?? DateTime.now()).toLocal();
    final difference = current.difference(local);

    if (!difference.isNegative) {
      if (difference.inSeconds < 60) {
        return 'baru saja';
      }
      if (difference.inMinutes < 60) {
        return '${difference.inMinutes} menit lalu';
      }
      if (difference.inHours < 24) {
        return '${difference.inHours} jam lalu';
      }
      if (difference.inDays < 7) {
        return '${difference.inDays} hari lalu';
      }
    }

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day ${months[local.month - 1]}, $hour:$minute';
  }

  static DateTime? _parse(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty || value == '-') return null;

    final epoch = int.tryParse(value);
    if (epoch != null && epoch > 0) {
      var milliseconds = epoch;
      if (milliseconds < 100000000000) milliseconds *= 1000;
      if (milliseconds > 100000000000000) milliseconds ~/= 1000;
      return DateTime.fromMillisecondsSinceEpoch(milliseconds);
    }

    final iso = DateTime.tryParse(value);
    if (iso != null) return iso;

    final normalized = value.replaceAll(RegExp(r'\s*\(UTC[^)]*\)\s*$'), '');
    final match = RegExp(
      r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})[ ,T]+(\d{1,2}):(\d{2})(?::(\d{2}))?',
    ).firstMatch(normalized);
    if (match == null) return null;

    return DateTime(
      int.parse(match.group(3)!),
      int.parse(match.group(2)!),
      int.parse(match.group(1)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
      int.tryParse(match.group(6) ?? '') ?? 0,
    );
  }
}

class PlantHealthBanner extends StatelessWidget {
  final String providerName;
  final bool isOnline;
  final String statusLabel;
  final String? updatedAt;
  final DateTime? fallbackSyncTime;
  final int offlineDevices;
  final int totalDevices;
  final bool isRefreshing;
  final Color accentColor;
  final VoidCallback? onRefresh;

  const PlantHealthBanner({
    super.key,
    required this.providerName,
    required this.isOnline,
    required this.statusLabel,
    required this.accentColor,
    this.updatedAt,
    this.fallbackSyncTime,
    this.offlineDevices = 0,
    this.totalDevices = 0,
    this.isRefreshing = false,
    this.onRefresh,
  });

  bool get _statusUnknown {
    final status = statusLabel.trim().toLowerCase();
    return status.isEmpty || status == 'unknown' || status == '-';
  }

  bool get _hasDeviceIssue => offlineDevices > 0;

  Color get _tone {
    if (!isOnline && !_statusUnknown) return const Color(0xFFE95D5D);
    if (!isOnline || _hasDeviceIssue) return const Color(0xFFF59E0B);
    return accentColor;
  }

  String get _title {
    if (isRefreshing) return 'Menyinkronkan data $providerName';
    if (!isOnline) {
      if (_statusUnknown) return 'Status plant belum tersedia';
      final status = statusLabel.toLowerCase();
      if (status.contains('alarm') ||
          status.contains('warning') ||
          status.contains('fault') ||
          status.contains('error')) {
        return 'Gangguan plant terdeteksi';
      }
      return 'Plant sedang offline';
    }
    if (_hasDeviceIssue) return '$offlineDevices perangkat perlu diperiksa';
    return 'Data plant tersinkron';
  }

  String get _description {
    if (!isOnline) {
      if (_statusUnknown) {
        return 'Tarik layar atau tekan refresh untuk mengambil status terbaru.';
      }
      return 'Periksa koneksi inverter dan datalogger, lalu refresh data.';
    }
    if (_hasDeviceIssue) {
      final total = totalDevices > 0 ? ' dari $totalDevices' : '';
      return '$offlineDevices$total perangkat tidak berstatus online.';
    }
    return 'Produksi dan status perangkat berhasil diperbarui.';
  }

  @override
  Widget build(BuildContext context) {
    final tone = _tone;
    final syncText = PlantSyncTime.format(
      updatedAt,
      fallback: fallbackSyncTime,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tone.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isOnline && !_hasDeviceIssue
                  ? Icons.cloud_done_rounded
                  : Icons.notification_important_rounded,
              color: tone,
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  style: const TextStyle(
                    color: Color(0xFF1F2937),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _description,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 10,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 12, color: tone),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Terakhir diperbarui $syncText',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tone,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 36,
            height: 36,
            child: isRefreshing
                ? Padding(
                    padding: const EdgeInsets.all(9),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: tone,
                    ),
                  )
                : IconButton(
                    onPressed: onRefresh,
                    tooltip: 'Refresh data',
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.refresh_rounded, color: tone, size: 20),
                  ),
          ),
        ],
      ),
    );
  }
}

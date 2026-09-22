import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_theme.dart';
import '../models/alarm.dart';
import '../models/station_detail.dart';
import '../repositories/monitoring_repository.dart';

class AlarmDetailScreen extends StatefulWidget {
  final Alarm alarm;

  const AlarmDetailScreen({super.key, required this.alarm});

  @override
  State<AlarmDetailScreen> createState() => _AlarmDetailScreenState();
}

class _AlarmDetailScreenState extends State<AlarmDetailScreen> {
  late final MonitoringRepository _repository;
  late final Future<StationDetail?>? _plantDetailFuture;

  Alarm get alarm => widget.alarm;

  Color get _levelColor {
    if (alarm.isRecovered) return AppColors.textSecondary;
    switch (alarm.alarmLevel) {
      case 1:
        return const Color(0xFFEAB308);
      case 2:
        return AppColors.warning;
      case 3:
        return AppColors.alarm;
      default:
        return AppColors.primary;
    }
  }

  @override
  void initState() {
    super.initState();
    _repository = MonitoringRepository();
    final stationId = alarm.stationId?.trim();
    _plantDetailFuture = stationId == null || stationId.isEmpty
        ? null
        : _loadPlantDetail(stationId);
  }

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }

  Future<StationDetail?> _loadPlantDetail(String stationId) async {
    try {
      return await _repository.getPlantDetail(stationId);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context)),
            SliverToBoxAdapter(child: _buildSummaryCard()),
            SliverToBoxAdapter(child: _buildMapCard()),
            SliverToBoxAdapter(child: _buildDetailCard()),
            SliverToBoxAdapter(child: _buildSolutionCard()),
            SliverToBoxAdapter(child: _buildPlantCard()),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Row(
        children: [
          _roundButton(Icons.arrow_back_rounded, () => Navigator.pop(context)),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Alarm Details',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          _statusChip(
            alarm.statusText,
            alarm.isRecovered ? AppColors.online : AppColors.alarm,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _levelColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.notification_important_rounded,
                  color: _levelColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _statusChip(alarm.levelText, _levelColor),
                        const SizedBox(width: 8),
                        if ((alarm.alarmCode ?? '').isNotEmpty)
                          Text(
                            alarm.alarmCode!,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      alarm.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      alarm.stationName?.isNotEmpty == true
                          ? alarm.stationName!
                          : 'Unknown plant',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _miniMetric('Device', alarm.deviceTypeText)),
              const SizedBox(width: 10),
              Expanded(child: _miniMetric('Duration', alarm.durationText)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMapCard() {
    if (_plantDetailFuture == null) {
      return _mapCardContent(_resolveLocation(null));
    }

    return FutureBuilder<StationDetail?>(
      future: _plantDetailFuture,
      builder: (context, snapshot) {
        final location = _resolveLocation(snapshot.data);
        return _card(
          title: 'Plant Location',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Loading plant location...',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              _mapPreview(location),
              const SizedBox(height: 12),
              _locationFooter(location),
            ],
          ),
        );
      },
    );
  }

  Widget _mapCardContent(_PlantLocation location) {
    return _card(
      title: 'Plant Location',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _mapPreview(location),
          const SizedBox(height: 12),
          _locationFooter(location),
        ],
      ),
    );
  }

  Widget _buildDetailCard() {
    return _card(
      title: 'Alarm Information',
      child: Column(
        children: [
          _infoRow('Device SN', alarm.alarmDeviceSn),
          _infoRow('Device Type', alarm.deviceTypeText),
          _infoRow('Device Model', alarm.machine ?? alarm.model ?? '-'),
          _infoRow('Alarm Code', alarm.alarmCode ?? '-'),
          _infoRow('Alarm Grade', alarm.levelText),
          _infoRow('Alarm Status', alarm.statusText),
          _infoRow('Start Time', alarm.alarmBeginTimeStr ?? '-'),
          _infoRow(
            'Recovery Time',
            alarm.alarmRecoverTimeStr ?? alarm.alarmEndTimeStr ?? '--',
          ),
        ],
      ),
    );
  }

  Widget _buildSolutionCard() {
    final advice = alarm.advice?.trim();
    return _card(
      title: 'Recommended Action',
      child: Text(
        advice == null || advice.isEmpty ? 'No action required.' : advice,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
          height: 1.45,
        ),
      ),
    );
  }

  Widget _buildPlantCard() {
    final address = alarm.plantAddress;
    return _card(
      title: 'Plant',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow('Plant Name', alarm.stationName ?? '-'),
          _infoRow('Plant ID', alarm.stationId ?? '-'),
          _infoRow('Contact', '--'),
          _infoRow('Owner', '--'),
          const SizedBox(height: 8),
          const Text(
            'Plant Address',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            address.isEmpty ? '--' : address,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  _PlantLocation _resolveLocation(StationDetail? detail) {
    final detailAddress = detail?.addr?.trim();
    final alarmAddress = alarm.plantAddress.trim();

    return _PlantLocation(
      plantName: _firstText([detail?.stationName, alarm.stationName]),
      address: _firstText([
        detailAddress,
        alarmAddress,
        alarm.countyStr,
        alarm.cityStr,
        alarm.regionStr,
        alarm.countryStr,
      ]),
      latitude: detail?.latitude ?? alarm.latitude,
      longitude: detail?.longitude ?? alarm.longitude,
    );
  }

  Widget _mapPreview(_PlantLocation location) {
    final mapUrl = location.staticMapUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 178,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Stack(
          children: [
            if (mapUrl != null)
              Positioned.fill(
                child: Image.network(
                  mapUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _mapPlaceholder(location),
                ),
              )
            else
              Positioned.fill(child: _mapPlaceholder(location)),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.2),
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.alarm,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.alarm.withValues(alpha: 0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  onTap: () => _openMaps(location),
                  borderRadius: BorderRadius.circular(999),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.map_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Open Maps',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
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
  }

  Widget _mapPlaceholder(_PlantLocation location) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEFF6FF), Color(0xFFF8FAFC), Color(0xFFFFF7ED)],
        ),
      ),
      child: Stack(
        children: [
          _roadLine(
            top: 30,
            left: -24,
            width: 220,
            rotation: -0.28,
            color: Colors.white,
          ),
          _roadLine(
            top: 94,
            right: -28,
            width: 240,
            rotation: -0.42,
            color: Colors.white,
          ),
          _roadLine(
            bottom: 30,
            left: 22,
            width: 260,
            rotation: 0.22,
            color: const Color(0xFFBFDBFE),
          ),
          _roadLine(
            top: 16,
            right: 38,
            width: 160,
            rotation: 0.85,
            color: const Color(0xFFFFEDD5),
          ),
          Positioned(
            left: 16,
            top: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.86),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                location.hasCoordinates ? 'Map preview' : 'Address preview',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roadLine({
    double? top,
    double? left,
    double? right,
    double? bottom,
    required double width,
    required double rotation,
    required Color color,
  }) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: Transform.rotate(
        angle: rotation,
        child: Container(
          width: width,
          height: 14,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
          ),
        ),
      ),
    );
  }

  Widget _locationFooter(_PlantLocation location) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.place_rounded,
            size: 18,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                location.plantName.isEmpty
                    ? 'Unknown plant'
                    : location.plantName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                location.address.isEmpty
                    ? 'Location detail is not available.'
                    : location.address,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
              if (location.hasCoordinates) ...[
                const SizedBox(height: 4),
                Text(
                  '${location.latitude!.toStringAsFixed(5)}, ${location.longitude!.toStringAsFixed(5)}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openMaps(_PlantLocation location) async {
    final query = location.mapQuery;
    if (query.isEmpty) return;

    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': query,
    });
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _card({String? title, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.surfaceBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
            ],
            child,
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniMetric(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }

  Widget _roundButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Icon(icon, size: 20, color: AppColors.textPrimary),
      ),
    );
  }

  String _firstText(List<String?> values) {
    for (final value in values) {
      final text = value?.trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return '';
  }
}

class _PlantLocation {
  final String plantName;
  final String address;
  final double? latitude;
  final double? longitude;

  const _PlantLocation({
    required this.plantName,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  bool get hasCoordinates => latitude != null && longitude != null;

  String get mapQuery {
    if (hasCoordinates) return '$latitude,$longitude';
    return [
      plantName,
      address,
    ].where((part) => part.trim().isNotEmpty).join(', ');
  }

  String? get staticMapUrl {
    if (!hasCoordinates) return null;
    final coordinate =
        '${latitude!.toStringAsFixed(6)},${longitude!.toStringAsFixed(6)}';
    return Uri.https('staticmap.openstreetmap.de', '/staticmap.php', {
      'center': coordinate,
      'zoom': '15',
      'size': '640x320',
      'markers': '$coordinate,red-pushpin',
    }).toString();
  }
}

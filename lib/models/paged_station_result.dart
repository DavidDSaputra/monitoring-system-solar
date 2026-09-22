import 'station.dart';

class PagedStationResult {
  final List<Station> records;
  final int total;
  final int pageNo;
  final int pageSize;

  const PagedStationResult({
    required this.records,
    required this.total,
    required this.pageNo,
    required this.pageSize,
  });

  bool get hasMore => pageNo * pageSize < total;
}

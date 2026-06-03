<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/services/huawei/huaweiStationService.php';
require_once dirname(__DIR__) . '/services/huawei/huaweiKpiService.php';
require_once dirname(__DIR__) . '/adapters/huawei/huaweiAdapter.php';

$cacheKey = 'huawei:normalized-plants';
$cached = api_cache_get($cacheKey, 30);
if ($cached !== null) {
    $cached['cached'] = true;
    api_json($cached);
}

try {
    $stations = huawei_get_stations();
    $plants = [];
    $stationRecords = array_values(array_filter($stations['records'] ?? [], 'is_array'));
    $plantCodes = array_values(array_filter(array_map(
        static fn (array $station): string => (string) huawei_pick($station, ['plantCode', 'stationCode', 'dn', 'id'], ''),
        $stationRecords
    )));
    $kpiByStation = [];

    foreach (array_chunk($plantCodes, 50) as $chunk) {
        $kpis = huawei_get_station_realtime_kpis($chunk);
        foreach (($kpis['records'] ?? []) as $kpiRecord) {
            if (!is_array($kpiRecord)) {
                continue;
            }
            $code = (string) huawei_pick($kpiRecord, ['stationCode', 'plantCode', 'dn', 'id'], '');
            if ($code !== '') {
                $kpiByStation[$code] = $kpiRecord;
            }
        }
    }

    foreach ($stationRecords as $station) {
        if (!is_array($station)) {
            continue;
        }

        $plantCode = (string) huawei_pick($station, ['plantCode', 'stationCode', 'dn', 'id'], '');
        if ($plantCode === '') {
            $plants[] = huawei_normalize_station($station);
            continue;
        }

        $plants[] = huawei_merge_station_with_kpi($station, $kpiByStation[$plantCode] ?? []);
    }

    $payload = [
        'success' => true,
        'source' => 'huawei',
        'cached' => false,
        'data' => $plants,
    ];

    api_cache_put($cacheKey, $payload);
    api_json($payload);
} catch (Throwable $e) {
    $stale = api_cache_get_stale($cacheKey, 86400);
    if ($stale !== null) {
        $stale['cached'] = true;
        $stale['stale'] = true;
        api_json($stale);
    }

    api_fail(503, 'Huawei data unavailable', [
        'detail' => $e->getMessage(),
    ]);
}

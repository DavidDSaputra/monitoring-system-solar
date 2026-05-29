<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/providers/provider_factory.php';
require_once dirname(__DIR__) . '/providers/solis/normalizer.php';
require_once dirname(__DIR__) . '/services/huawei/huaweiStationService.php';
require_once dirname(__DIR__) . '/services/huawei/huaweiKpiService.php';
require_once dirname(__DIR__) . '/adapters/huawei/huaweiAdapter.php';

$source = strtolower(trim((string) ($_GET['source'] ?? 'all')));
$records = [];
$errors = [];

if ($source === 'all' || $source === 'solis') {
    $solisCacheKey = 'monitoring:plants:solis';
    $solisCache = api_cache_get($solisCacheKey, 60);
    if ($solisCache !== null && isset($solisCache['data']) && is_array($solisCache['data'])) {
        $records = array_merge($records, $solisCache['data']);
    } elseif ($source === 'all') {
        $staleSolis = api_cache_get_stale($solisCacheKey, 86400);
        if ($staleSolis !== null && isset($staleSolis['data']) && is_array($staleSolis['data'])) {
            $records = array_merge($records, $staleSolis['data']);
        } else {
            $errors[] = 'Solis data unavailable';
        }
    } else {
        $solis = monitoring_provider('solis')->plants();
        $solisRecords = normalize_records($solis['records'] ?? [], 'normalize_plant');
        api_cache_put($solisCacheKey, [
            'success' => true,
            'source' => 'solis',
            'data' => $solisRecords,
        ]);
        $records = array_merge($records, $solisRecords);
    }
}

if ($source === 'all' || $source === 'huawei') {
    $huaweiCache = api_cache_get('huawei:normalized-plants', 30);
    if ($huaweiCache !== null && isset($huaweiCache['data']) && is_array($huaweiCache['data'])) {
        $records = array_merge($records, $huaweiCache['data']);
    } else {
        $stations = huawei_get_stations();
        $huaweiPlants = [];
        $stationRecords = array_values(array_filter($stations['records'] ?? [], 'is_array'));
        $plantCodes = array_values(array_filter(array_map(
            static fn (array $station): string => (string) huawei_pick($station, ['plantCode', 'stationCode', 'dn', 'id'], ''),
            $stationRecords
        )));
        $kpiByStation = [];
        try {
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
        } catch (Throwable) {
            $kpiByStation = [];
        }

        foreach ($stationRecords as $station) {
            if (!is_array($station)) {
                continue;
            }
            $plantCode = (string) huawei_pick($station, ['plantCode', 'stationCode', 'dn', 'id'], '');
            $huaweiPlants[] = huawei_merge_station_with_kpi($station, $kpiByStation[$plantCode] ?? []);
        }
        api_cache_put('huawei:normalized-plants', [
            'success' => true,
            'source' => 'huawei',
            'cached' => false,
            'data' => $huaweiPlants,
        ]);
        $records = array_merge($records, $huaweiPlants);
    }
}

if (!in_array($source, ['all', 'solis', 'huawei'], true)) {
    api_fail(400, 'Unsupported source filter');
}

api_json([
    'success' => true,
    'source' => $source,
    'errors' => $errors,
    'data' => $records,
]);

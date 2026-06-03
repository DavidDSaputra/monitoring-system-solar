<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/providers/provider_factory.php';
require_once dirname(__DIR__) . '/providers/solis/normalizer.php';
require_once dirname(__DIR__) . '/services/huawei/huaweiStationService.php';
require_once dirname(__DIR__) . '/services/huawei/huaweiKpiService.php';
require_once dirname(__DIR__) . '/adapters/huawei/huaweiAdapter.php';
require_once dirname(__DIR__) . '/services/growatt/growattPlantService.php';
require_once dirname(__DIR__) . '/adapters/growatt/growattAdapter.php';

$source = strtolower(trim((string) ($_GET['source'] ?? 'all')));
$records = [];
$errors = [];

if ($source === 'all' || $source === 'solis') {
    $solisCacheKey = 'monitoring:plants:solis';
    $solisCache = api_cache_get($solisCacheKey, 60);
    if ($solisCache !== null && isset($solisCache['data']) && is_array($solisCache['data'])) {
        $records = array_merge($records, $solisCache['data']);
    } else {
        $staleSolis = api_cache_get_stale($solisCacheKey, 86400);
        if ($source === 'all' && $staleSolis !== null && isset($staleSolis['data']) && is_array($staleSolis['data'])) {
            $records = array_merge($records, $staleSolis['data']);
            api_run_background_php(dirname(__DIR__) . '/warm_cache.php', ['overview']);
        } else {
        try {
            $solis = monitoring_provider('solis')->plants();
            $solisRecords = normalize_records($solis['records'] ?? [], 'normalize_plant');
            api_cache_put($solisCacheKey, [
                'success' => true,
                'source' => 'solis',
                'data' => $solisRecords,
            ]);
            $records = array_merge($records, $solisRecords);
        } catch (Throwable) {
            if ($staleSolis !== null && isset($staleSolis['data']) && is_array($staleSolis['data'])) {
                $records = array_merge($records, $staleSolis['data']);
            } else {
                $errors[] = 'Solis data unavailable';
            }
        }
        }
    }
}

if ($source === 'all' || $source === 'huawei') {
    $huaweiCacheKey = 'huawei:normalized-plants';
    $huaweiCache = api_cache_get($huaweiCacheKey, 30);
    if ($huaweiCache !== null && isset($huaweiCache['data']) && is_array($huaweiCache['data'])) {
        $records = array_merge($records, $huaweiCache['data']);
    } else {
        $staleHuawei = api_cache_get_stale($huaweiCacheKey, 86400);
        if ($source === 'all' && $staleHuawei !== null && isset($staleHuawei['data']) && is_array($staleHuawei['data'])) {
            $records = array_merge($records, $staleHuawei['data']);
        } else {
        try {
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
            api_cache_put($huaweiCacheKey, [
                'success' => true,
                'source' => 'huawei',
                'cached' => false,
                'data' => $huaweiPlants,
            ]);
            $records = array_merge($records, $huaweiPlants);
        } catch (Throwable) {
            if ($staleHuawei !== null && isset($staleHuawei['data']) && is_array($staleHuawei['data'])) {
                $records = array_merge($records, $staleHuawei['data']);
            } else {
                $errors[] = 'Huawei data unavailable';
            }
        }
        }
    }
}

if ($source === 'all' || $source === 'growatt') {
    $growattCacheKey = 'growatt:normalized-plants:fast';
    $growattCache = api_cache_get($growattCacheKey, 300);
    if ($growattCache !== null && isset($growattCache['data']) && is_array($growattCache['data'])) {
        $records = array_merge($records, $growattCache['data']);
    } else {
        $staleGrowatt = api_cache_get_stale($growattCacheKey, 86400);
        if ($source === 'all' && $staleGrowatt !== null && isset($staleGrowatt['data']) && is_array($staleGrowatt['data'])) {
            $records = array_merge($records, $staleGrowatt['data']);
        } else {
        try {
            $plantList = growatt_get_plants();
            $growattPlants = [];
            foreach (($plantList['records'] ?? []) as $station) {
                if (!is_array($station)) {
                    continue;
                }

                $growattPlants[] = growatt_normalize_station($station);
            }

            api_cache_put($growattCacheKey, [
                'success' => true,
                'source' => 'growatt',
                'cached' => false,
                'hydrated' => false,
                'data' => $growattPlants,
            ]);
            $records = array_merge($records, $growattPlants);
        } catch (Throwable) {
            if ($staleGrowatt !== null && isset($staleGrowatt['data']) && is_array($staleGrowatt['data'])) {
                $records = array_merge($records, $staleGrowatt['data']);
            } else {
                $errors[] = 'Growatt data unavailable';
            }
        }
        }
    }
}

if (!in_array($source, ['all', 'solis', 'huawei', 'growatt'], true)) {
    api_fail(400, 'Unsupported source filter');
}

api_json([
    'success' => true,
    'source' => $source,
    'errors' => $errors,
    'data' => $records,
]);

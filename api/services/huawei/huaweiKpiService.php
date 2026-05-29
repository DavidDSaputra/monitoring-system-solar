<?php
declare(strict_types=1);

require_once __DIR__ . '/huaweiApiClient.php';

function huawei_get_station_realtime_kpi(string $plantCode, bool $forceRefresh = false): array
{
    $cacheKey = 'huawei:station-kpi:' . $plantCode;
    if (!$forceRefresh) {
        $cached = api_cache_get($cacheKey, 30);
        if ($cached !== null) {
            $cached['cached'] = true;
            return $cached;
        }
    }

    $response = huawei_request('/thirdData/getStationRealKpi', [
        'stationCodes' => $plantCode,
    ]);
    $records = huawei_records_from_response($response);
    $record = $records[0] ?? ($response['data'] ?? $response);
    $payload = [
        'record' => is_array($record) ? $record : [],
        'records' => $records,
        'cached' => false,
    ];
    api_cache_put($cacheKey, $payload);
    return $payload;
}

function huawei_get_station_realtime_kpis(array $plantCodes, bool $forceRefresh = false): array
{
    $plantCodes = array_values(array_filter(array_map('trim', $plantCodes)));
    if (count($plantCodes) === 0) {
        return ['records' => [], 'cached' => false];
    }

    $stationCodes = implode(',', $plantCodes);
    $cacheKey = 'huawei:station-kpis:' . sha1($stationCodes);
    if (!$forceRefresh) {
        $cached = api_cache_get($cacheKey, 30);
        if ($cached !== null) {
            $cached['cached'] = true;
            return $cached;
        }
    }

    $response = huawei_request('/thirdData/getStationRealKpi', [
        'stationCodes' => $stationCodes,
    ]);
    $records = huawei_records_from_response($response);
    if (count($records) === 0 && isset($response['data']) && is_array($response['data'])) {
        $records = [$response['data']];
    }

    $payload = [
        'records' => $records,
        'cached' => false,
    ];
    api_cache_put($cacheKey, $payload);
    return $payload;
}

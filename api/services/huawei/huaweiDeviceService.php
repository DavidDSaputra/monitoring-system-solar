<?php
declare(strict_types=1);

require_once __DIR__ . '/huaweiApiClient.php';

function huawei_get_dev_list(string $plantCode, bool $forceRefresh = false): array
{
    $cacheKey = 'huawei:dev-list:' . $plantCode;
    if (!$forceRefresh) {
        $cached = api_cache_get($cacheKey, 60);
        if ($cached !== null) {
            $cached['cached'] = true;
            return $cached;
        }
    }

    $response = huawei_request('/thirdData/getDevList', [
        'stationCodes' => $plantCode,
    ]);
    $records = huawei_records_from_response($response);
    $payload = [
        'records' => $records,
        'total' => count($records),
        'cached' => false,
    ];
    api_cache_put($cacheKey, $payload);
    return $payload;
}

function huawei_get_dev_real_kpi(array|string $deviceIds, bool $forceRefresh = false): array
{
    $ids = is_array($deviceIds) ? implode(',', $deviceIds) : $deviceIds;
    $cacheKey = 'huawei:dev-real-kpi:' . $ids;
    if (!$forceRefresh) {
        $cached = api_cache_get($cacheKey, 30);
        if ($cached !== null) {
            $cached['cached'] = true;
            return $cached;
        }
    }

    $response = huawei_request('/thirdData/getDevRealKpi', [
        'devIds' => $ids,
    ]);
    $records = huawei_records_from_response($response);
    $payload = [
        'records' => $records,
        'total' => count($records),
        'cached' => false,
    ];
    api_cache_put($cacheKey, $payload);
    return $payload;
}

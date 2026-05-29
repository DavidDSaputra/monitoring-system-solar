<?php
declare(strict_types=1);

require_once __DIR__ . '/huaweiApiClient.php';

function huawei_get_stations(bool $forceRefresh = false): array
{
    $cacheKey = 'huawei:stations';
    if (!$forceRefresh) {
        $cached = api_cache_get($cacheKey, 60);
        if ($cached !== null) {
            $cached['cached'] = true;
            return $cached;
        }
    }

    $records = [];
    $total = 0;
    $pageNo = 1;
    $pageSize = 100;

    do {
        $response = huawei_request('/thirdData/stations', [
            'pageNo' => $pageNo,
            'pageSize' => $pageSize,
        ]);
        $pageRecords = huawei_records_from_response($response);
        $records = array_merge($records, $pageRecords);
        $total = huawei_total_from_response($response, count($records));
        $pageNo++;
    } while ($total > count($records) && count($pageRecords) > 0 && $pageNo <= 50);

    $payload = [
        'records' => $records,
        'total' => $total > 0 ? $total : count($records),
        'cached' => false,
    ];
    api_cache_put($cacheKey, $payload);
    return $payload;
}

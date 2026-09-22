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

    try {
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
    } catch (Throwable $e) {
        $stale = api_cache_get_stale($cacheKey, 86400);
        if ($stale !== null) {
            $stale['cached'] = true;
            $stale['stale'] = true;
            $stale['staleReason'] = $e->getMessage();
            return $stale;
        }

        throw $e;
    }

    $payload = [
        'records' => $records,
        'total' => $total > 0 ? $total : count($records),
        'cached' => false,
    ];
    api_cache_put($cacheKey, $payload);
    return $payload;
}

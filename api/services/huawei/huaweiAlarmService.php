<?php
declare(strict_types=1);

require_once __DIR__ . '/huaweiApiClient.php';

function huawei_get_alarm_list(
    array|string $plantCodes,
    bool $historical = false,
    bool $forceRefresh = false
): array {
    $codes = is_array($plantCodes) ? implode(',', array_filter($plantCodes)) : $plantCodes;
    $codes = trim($codes);
    if ($codes === '') {
        return ['records' => [], 'total' => 0, 'cached' => false];
    }

    $cacheKey = 'huawei:alarm-list:' . sha1($codes . ':' . ($historical ? 'history' : 'active'));
    if (!$forceRefresh) {
        $cached = api_cache_get($cacheKey, 60);
        if ($cached !== null) {
            $cached['cached'] = true;
            return $cached;
        }
    }

    $body = [
        'stationCodes' => $codes,
        'sns' => '',
        'language' => 'en_US',
        'levels' => '1,2,3,4',
        'devTypes' => '1,2,38,46,62',
    ];

    if ($historical) {
        $body['beginTime'] = (string) ((time() - 30 * 86400) * 1000);
        $body['endTime'] = (string) (time() * 1000);
    }

    $response = huawei_request('/thirdData/getAlarmList', $body);
    $records = huawei_records_from_response($response);
    $payload = [
        'records' => $records,
        'total' => count($records),
        'cached' => false,
    ];
    api_cache_put($cacheKey, $payload);
    return $payload;
}

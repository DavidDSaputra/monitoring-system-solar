<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/services/huawei/huaweiAlarmService.php';
require_once dirname(__DIR__) . '/services/huawei/huaweiStationService.php';
require_once dirname(__DIR__) . '/adapters/huawei/huaweiAdapter.php';

$plantCode = urldecode(trim((string) ($_GET['plantCode'] ?? '')));
$historical = filter_var($_GET['historical'] ?? false, FILTER_VALIDATE_BOOLEAN);

if ($plantCode === '') {
    $stations = huawei_get_stations();
    $plantCodes = array_values(array_filter(array_map(
        static fn (array $station): string => (string) huawei_pick($station, ['plantCode', 'stationCode', 'dn', 'id'], ''),
        array_values(array_filter($stations['records'] ?? [], 'is_array'))
    )));
    $plantCode = implode(',', array_slice($plantCodes, 0, 100));
}

$cacheKey = 'huawei:alarms-route:' . sha1($plantCode . ':' . ($historical ? '1' : '0'));
$cached = api_cache_get($cacheKey, 60);
if ($cached !== null) {
    $cached['cached'] = true;
    api_json($cached);
}

try {
    $result = huawei_get_alarm_list($plantCode, $historical);
    $payload = [
        'success' => true,
        'source' => 'huawei',
        'cached' => $result['cached'] ?? false,
        'data' => array_map('huawei_normalize_alarm', $result['records'] ?? []),
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

    api_fail(503, 'Huawei alarm data unavailable', [
        'detail' => $e->getMessage(),
    ]);
}

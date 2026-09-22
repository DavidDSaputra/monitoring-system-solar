<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/services/huawei/huaweiKpiService.php';
require_once dirname(__DIR__) . '/adapters/huawei/huaweiAdapter.php';

$plantCode = urldecode(trim((string) ($_GET['plantCode'] ?? '')));
$forceRefresh = filter_var($_GET['refresh'] ?? $_GET['forceRefresh'] ?? false, FILTER_VALIDATE_BOOLEAN);
if ($plantCode === '') {
    api_fail(400, 'Huawei plantCode is required');
}

$cacheKey = 'huawei:station-realtime:' . sha1($plantCode);
$cached = $forceRefresh ? null : api_cache_get($cacheKey, 30);
if ($cached !== null) {
    $cached['cached'] = true;
    api_json($cached);
}

try {
    $result = huawei_get_station_realtime_kpi($plantCode, $forceRefresh);
    $payload = [
        'success' => true,
        'source' => 'huawei',
        'cached' => $result['cached'] ?? false,
        'data' => huawei_normalize_realtime_kpi($result['record'] ?? []),
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

    api_fail(503, 'Huawei realtime data unavailable', [
        'detail' => $e->getMessage(),
    ]);
}

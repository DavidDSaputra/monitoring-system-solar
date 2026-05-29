<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/services/huawei/huaweiKpiService.php';
require_once dirname(__DIR__) . '/adapters/huawei/huaweiAdapter.php';

$plantCode = urldecode(trim((string) ($_GET['plantCode'] ?? '')));
if ($plantCode === '') {
    api_fail(400, 'Huawei plantCode is required');
}

$result = huawei_get_station_realtime_kpi($plantCode);
api_json([
    'success' => true,
    'source' => 'huawei',
    'cached' => $result['cached'] ?? false,
    'data' => huawei_normalize_realtime_kpi($result['record'] ?? []),
]);

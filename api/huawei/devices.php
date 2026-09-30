<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/services/huawei/huaweiDeviceService.php';
require_once dirname(__DIR__) . '/adapters/huawei/huaweiAdapter.php';
require_once dirname(__DIR__) . '/lib/device_snapshot.php';

$plantCode = urldecode(trim((string) ($_GET['plantCode'] ?? '')));
$forceRefresh = filter_var($_GET['refresh'] ?? $_GET['forceRefresh'] ?? false, FILTER_VALIDATE_BOOLEAN);
if ($plantCode === '') {
    api_fail(400, 'Huawei plantCode is required');
}

$result = huawei_get_dev_list($plantCode, $forceRefresh);
$devices = array_map('huawei_normalize_device', $result['records'] ?? []);
monitoring_merge_device_snapshot('huawei', $plantCode, $devices);
api_json([
    'success' => true,
    'source' => 'huawei',
    'cached' => $result['cached'] ?? false,
    'data' => $devices,
]);

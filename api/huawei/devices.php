<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/services/huawei/huaweiDeviceService.php';
require_once dirname(__DIR__) . '/adapters/huawei/huaweiAdapter.php';

$plantCode = urldecode(trim((string) ($_GET['plantCode'] ?? '')));
$forceRefresh = filter_var($_GET['refresh'] ?? $_GET['forceRefresh'] ?? false, FILTER_VALIDATE_BOOLEAN);
if ($plantCode === '') {
    api_fail(400, 'Huawei plantCode is required');
}

$result = huawei_get_dev_list($plantCode, $forceRefresh);
api_json([
    'success' => true,
    'source' => 'huawei',
    'cached' => $result['cached'] ?? false,
    'data' => array_map('huawei_normalize_device', $result['records'] ?? []),
]);

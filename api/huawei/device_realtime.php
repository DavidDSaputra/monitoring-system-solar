<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/services/huawei/huaweiDeviceService.php';

$deviceIds = trim((string) ($_GET['deviceIds'] ?? $_GET['deviceId'] ?? ''));
if ($deviceIds === '') {
    api_fail(400, 'Huawei deviceId/deviceIds is required');
}

$result = huawei_get_dev_real_kpi($deviceIds);
api_json([
    'success' => true,
    'source' => 'huawei',
    'cached' => $result['cached'] ?? false,
    'data' => $result['records'] ?? [],
]);

<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/services/huawei/huaweiStationService.php';

$result = huawei_get_stations();
api_json([
    'success' => true,
    'source' => 'huawei',
    'cached' => $result['cached'] ?? false,
    'data' => $result['records'] ?? [],
]);

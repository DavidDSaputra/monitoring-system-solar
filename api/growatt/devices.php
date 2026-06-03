<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/services/growatt/growattDeviceService.php';
require_once dirname(__DIR__) . '/adapters/growatt/growattAdapter.php';

$plantCode = urldecode(trim((string) ($_GET['plantCode'] ?? '')));
if ($plantCode === '') {
    api_fail(400, 'Growatt plantCode is required');
}

$result = growatt_get_devices($plantCode);
api_json([
    'success' => true,
    'source' => 'growatt',
    'cached' => $result['cached'] ?? false,
    'data' => array_map('growatt_normalize_device', $result['records'] ?? []),
]);

<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/services/growatt/growattDeviceService.php';
require_once dirname(__DIR__) . '/adapters/growatt/growattAdapter.php';
require_once dirname(__DIR__) . '/lib/device_snapshot.php';

$plantCode = urldecode(trim((string) ($_GET['plantCode'] ?? '')));
$forceRefresh = filter_var($_GET['refresh'] ?? $_GET['forceRefresh'] ?? false, FILTER_VALIDATE_BOOLEAN);
if ($plantCode === '') {
    api_fail(400, 'Growatt plantCode is required');
}

$result = growatt_get_devices($plantCode, $forceRefresh);
$devices = array_map('growatt_normalize_device', $result['records'] ?? []);
monitoring_merge_device_snapshot('growatt', $plantCode, $devices);
api_json([
    'success' => true,
    'source' => 'growatt',
    'cached' => $result['cached'] ?? false,
    'data' => $devices,
]);

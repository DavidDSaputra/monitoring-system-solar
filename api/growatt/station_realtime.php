<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/services/growatt/growattPlantService.php';
require_once dirname(__DIR__) . '/adapters/growatt/growattAdapter.php';

$plantCode = urldecode(trim((string) ($_GET['plantCode'] ?? '')));
$forceRefresh = filter_var($_GET['refresh'] ?? $_GET['forceRefresh'] ?? false, FILTER_VALIDATE_BOOLEAN);
if ($plantCode === '') {
    api_fail(400, 'Growatt plantCode is required');
}

$station = [];
$plantList = growatt_get_plants($forceRefresh);
foreach (($plantList['records'] ?? []) as $record) {
    if (!is_array($record)) {
        continue;
    }
    if (growatt_text(growatt_pick($record, ['plant_id', 'plantId', 'id'])) === $plantCode) {
        $station = $record;
        break;
    }
}

$kpi = growatt_get_plant_data($plantCode, $forceRefresh);
$normalized = growatt_merge_station_with_kpi($station, $kpi['record'] ?? []);

api_json([
    'success' => true,
    'source' => 'growatt',
    'cached' => ($plantList['cached'] ?? false) || ($kpi['cached'] ?? false),
    'data' => $normalized,
]);

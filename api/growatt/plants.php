<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/services/growatt/growattPlantService.php';
require_once dirname(__DIR__) . '/adapters/growatt/growattAdapter.php';

$cacheKey = 'growatt:normalized-plants';
$hydrate = filter_var($_GET['hydrate'] ?? false, FILTER_VALIDATE_BOOLEAN);
$cacheKey .= $hydrate ? ':hydrated' : ':fast';
$cached = api_cache_get($cacheKey, $hydrate ? 60 : 300);
if ($cached !== null) {
    $cached['cached'] = true;
    api_json($cached);
}

$plants = [];
$plantList = growatt_get_plants();
foreach (($plantList['records'] ?? []) as $station) {
    if (!is_array($station)) {
        continue;
    }

    $plantId = growatt_text(growatt_pick($station, ['plant_id', 'plantId', 'id']));
    $kpi = [];
    if ($hydrate && $plantId !== '') {
        try {
            $kpi = growatt_get_plant_data($plantId)['record'] ?? [];
        } catch (Throwable) {
            $kpi = [];
        }
    }
    $plants[] = $hydrate
        ? growatt_merge_station_with_kpi($station, is_array($kpi) ? $kpi : [])
        : growatt_normalize_station($station);
}

$payload = [
    'success' => true,
    'source' => 'growatt',
    'cached' => false,
    'hydrated' => $hydrate,
    'data' => $plants,
];

api_cache_put($cacheKey, $payload);
api_json($payload);

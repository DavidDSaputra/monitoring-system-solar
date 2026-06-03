<?php
declare(strict_types=1);

require_once __DIR__ . '/providers/provider_factory.php';
require_once __DIR__ . '/providers/solis/normalizer.php';
require_once __DIR__ . '/services/growatt/growattPlantService.php';
require_once __DIR__ . '/adapters/growatt/growattAdapter.php';

$target = PHP_SAPI === 'cli'
    ? (string) ($argv[1] ?? 'overview')
    : trim((string) ($_GET['target'] ?? 'overview'));

$lock = api_lock_acquire('warm-cache:' . $target, 300);
if ($lock === false) {
    api_json([
        'success' => true,
        'message' => 'Cache warm already running',
        'target' => $target,
    ]);
}

try {
    $provider = monitoring_provider();
    $startedAt = microtime(true);

    switch ($target) {
        case 'overview':
            $overview = $provider->overview(true);
            $solisPlants = $overview['plants']['records'] ?? [];
            $payload = [
                'success' => true,
                'provider' => $provider->id(),
                'cached' => false,
                'stale' => false,
                'data' => $overview,
            ];
            api_cache_put('app:overview:v1', $payload);
            api_cache_put('app:normalized:overview:v1', normalized_overview_payload($provider->id(), $overview));
            api_cache_put('monitoring:plants:solis', [
                'success' => true,
                'source' => 'solis',
                'data' => normalize_records($solisPlants, 'normalize_plant'),
            ]);
            break;

        case 'solis-plants':
            $solisPlantsResult = $provider->plants(true);
            api_cache_put('app:plants:v1', [
                'success' => true,
                'provider' => $provider->id(),
                'cached' => false,
                'stale' => false,
                'data' => [
                    'records' => $solisPlantsResult['records'] ?? [],
                    'total' => $solisPlantsResult['total'] ?? count($solisPlantsResult['records'] ?? []),
                ],
            ]);
            api_cache_put('monitoring:plants:solis', [
                'success' => true,
                'source' => 'solis',
                'data' => normalize_records($solisPlantsResult['records'] ?? [], 'normalize_plant'),
            ]);
            break;

        case 'all':
            $solisPlantsResult = $provider->plants(true);
            $provider->inverters(null, true);
            $provider->batteries(true);
            $provider->collectors(true);
            $provider->alarms(true);
            warm_growatt_plants(false);
            $overview = $provider->overview(true);
            api_cache_put('app:overview:v1', [
                'success' => true,
                'provider' => $provider->id(),
                'cached' => false,
                'stale' => false,
                'data' => $overview,
            ]);
            api_cache_put('app:normalized:overview:v1', normalized_overview_payload($provider->id(), $overview));
            api_cache_put('monitoring:plants:solis', [
                'success' => true,
                'source' => 'solis',
                'data' => normalize_records($solisPlantsResult['records'] ?? [], 'normalize_plant'),
            ]);
            break;

        case 'growatt':
            warm_growatt_plants(true);
            break;

        default:
            api_fail(400, "Unsupported warm target: {$target}");
    }

    api_json([
        'success' => true,
        'target' => $target,
        'elapsedMs' => (int) round((microtime(true) - $startedAt) * 1000),
    ]);
} finally {
    api_lock_release($lock);
}

function warm_growatt_plants(bool $forceRefresh = false): void
{
    $plantList = growatt_get_plants($forceRefresh);
    $fastPlants = [];
    $plants = [];
    foreach (($plantList['records'] ?? []) as $station) {
        if (!is_array($station)) {
            continue;
        }

        $fastPlants[] = growatt_normalize_station($station);
        $plantId = growatt_text(growatt_pick($station, ['plant_id', 'plantId', 'id']));
        $kpi = [];
        if ($plantId !== '') {
            try {
                $kpi = growatt_get_plant_data($plantId, $forceRefresh)['record'] ?? [];
            } catch (Throwable) {
                $kpi = [];
            }
        }

        $plants[] = growatt_merge_station_with_kpi($station, is_array($kpi) ? $kpi : []);
    }

    api_cache_put('growatt:normalized-plants:fast', [
        'success' => true,
        'source' => 'growatt',
        'cached' => false,
        'hydrated' => false,
        'data' => $fastPlants,
    ]);

    api_cache_put('growatt:normalized-plants:hydrated', [
        'success' => true,
        'source' => 'growatt',
        'cached' => false,
        'hydrated' => true,
        'data' => $plants,
    ]);
}

function normalized_overview_payload(string $providerId, array $overview): array
{
    return [
        'success' => true,
        'provider' => $providerId,
        'normalized' => true,
        'cached' => false,
        'stale' => false,
        'data' => [
            'plants' => [
                'records' => normalize_records($overview['plants']['records'] ?? [], 'normalize_plant'),
                'total' => $overview['plants']['total'] ?? count($overview['plants']['records'] ?? []),
            ],
            'inverters' => [
                'records' => normalize_records($overview['inverters']['records'] ?? [], 'normalize_inverter'),
                'total' => $overview['inverters']['total'] ?? count($overview['inverters']['records'] ?? []),
            ],
            'batteries' => [
                'records' => normalize_records($overview['batteries']['records'] ?? [], 'normalize_battery'),
                'total' => $overview['batteries']['total'] ?? count($overview['batteries']['records'] ?? []),
            ],
            'collectors' => [
                'records' => normalize_records($overview['collectors']['records'] ?? [], 'normalize_collector'),
                'total' => $overview['collectors']['total'] ?? count($overview['collectors']['records'] ?? []),
            ],
        ],
    ];
}

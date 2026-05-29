<?php
declare(strict_types=1);

require_once __DIR__ . '/providers/provider_factory.php';
require_once __DIR__ . '/providers/solis/normalizer.php';

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
            $payload = [
                'success' => true,
                'provider' => $provider->id(),
                'cached' => false,
                'stale' => false,
                'data' => $overview,
            ];
            api_cache_put('app:overview:v1', $payload);
            api_cache_put('app:normalized:overview:v1', normalized_overview_payload($provider->id(), $overview));
            break;

        case 'all':
            $provider->plants(true);
            $provider->inverters(null, true);
            $provider->batteries(true);
            $provider->collectors(true);
            $provider->alarms(true);
            $overview = $provider->overview(true);
            api_cache_put('app:overview:v1', [
                'success' => true,
                'provider' => $provider->id(),
                'cached' => false,
                'stale' => false,
                'data' => $overview,
            ]);
            api_cache_put('app:normalized:overview:v1', normalized_overview_payload($provider->id(), $overview));
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

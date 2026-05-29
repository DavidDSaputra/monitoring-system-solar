<?php
declare(strict_types=1);

require_once __DIR__ . '/solis/SolisProvider.php';

function monitoring_provider(?string $providerId = null): MonitoringProviderAdapter
{
    $providerId = strtolower(trim((string) ($providerId ?? api_env('MONITORING_PROVIDER', 'solis'))));

    return match ($providerId) {
        'solis' => new SolisProvider(),
        default => api_fail(400, "Unsupported monitoring provider: {$providerId}"),
    };
}

<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/providers/provider_factory.php';
require_once dirname(__DIR__) . '/providers/solis/normalizer.php';

function normalized_list_response(string $resource, array $result, callable $normalizer): never
{
    $records = normalize_records($result['records'] ?? [], $normalizer);
    api_json([
        'success' => true,
        'provider' => monitoring_provider()->id(),
        'normalized' => true,
        'resource' => $resource,
        'cached' => $result['cached'] ?? false,
        'data' => [
            'records' => $records,
            'total' => $result['total'] ?? count($records),
        ],
    ]);
}

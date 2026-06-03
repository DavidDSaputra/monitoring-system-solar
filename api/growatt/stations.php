<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/services/growatt/growattPlantService.php';

$result = growatt_get_plants();
api_json([
    'success' => true,
    'source' => 'growatt',
    'cached' => $result['cached'] ?? false,
    'data' => [
        'records' => $result['records'] ?? [],
        'total' => $result['total'] ?? 0,
    ],
]);

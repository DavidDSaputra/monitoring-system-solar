<?php
declare(strict_types=1);

require_once __DIR__ . '/_helpers.php';

$stationId = trim((string) ($_GET['stationId'] ?? ''));
normalized_list_response(
    'inverters',
    monitoring_provider()->inverters($stationId !== '' ? $stationId : null),
    'normalize_inverter'
);

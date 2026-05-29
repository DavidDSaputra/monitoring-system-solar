<?php
declare(strict_types=1);

require_once __DIR__ . '/_helpers.php';

$scope = trim((string) ($_GET['scope'] ?? 'day'));
$stationId = trim((string) ($_GET['stationId'] ?? ''));
$time = trim((string) ($_GET['time'] ?? ''));

if ($stationId === '' || $time === '') {
    api_fail(400, 'Station id and time are required');
}

normalized_list_response(
    'energy',
    monitoring_provider()->stationEnergy($scope, $stationId, $time),
    'normalize_energy_point'
);

<?php
declare(strict_types=1);

require_once __DIR__ . '/providers/provider_factory.php';

$stationId = trim((string) ($_GET['stationId'] ?? ''));

solis_list_response(monitoring_provider()->inverters($stationId !== '' ? $stationId : null));

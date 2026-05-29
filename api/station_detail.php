<?php
declare(strict_types=1);

require_once __DIR__ . '/providers/provider_factory.php';

$id = trim((string) ($_GET['id'] ?? ''));
if ($id === '') {
    api_fail(400, 'Station id is required');
}

solis_detail_response(monitoring_provider()->stationDetail($id));

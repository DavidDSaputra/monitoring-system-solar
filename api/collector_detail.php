<?php
declare(strict_types=1);

require_once __DIR__ . '/providers/provider_factory.php';

$sn = trim((string) ($_GET['sn'] ?? ''));
if ($sn === '') {
    api_fail(400, 'Collector serial number is required');
}

solis_detail_response(monitoring_provider()->collectorDetail($sn));

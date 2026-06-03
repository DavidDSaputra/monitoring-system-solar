<?php
declare(strict_types=1);

require_once __DIR__ . '/lib/bootstrap.php';

api_json([
    'success' => true,
    'service' => 'Jarwinn Monitoring Backend',
    'status' => 'ok',
    'serverTime' => gmdate(DATE_ATOM),
    'endpoints' => [
        '/health.php',
        '/plants.php',
        '/monitoring/plants.php?source=all',
        '/huawei/plants.php',
        '/growatt/plants.php',
    ],
]);

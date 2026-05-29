<?php
declare(strict_types=1);

require_once __DIR__ . '/_helpers.php';

normalized_list_response('batteries', monitoring_provider()->batteries(), 'normalize_battery');

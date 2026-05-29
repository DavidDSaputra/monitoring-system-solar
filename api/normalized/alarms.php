<?php
declare(strict_types=1);

require_once __DIR__ . '/_helpers.php';

normalized_list_response('alarms', monitoring_provider()->alarms(), 'normalize_alarm');

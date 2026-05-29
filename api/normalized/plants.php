<?php
declare(strict_types=1);

require_once __DIR__ . '/_helpers.php';

normalized_list_response('plants', monitoring_provider()->plants(), 'normalize_plant');

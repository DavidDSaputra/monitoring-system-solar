<?php
declare(strict_types=1);

require_once __DIR__ . '/providers/provider_factory.php';

solis_list_response(monitoring_provider()->plants());

<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
header('Access-Control-Max-Age: 86400');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Method not allowed']);
    exit;
}

function read_env_file(string $path): array
{
    if (!is_file($path)) {
        return [];
    }

    $env = [];
    foreach (file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) ?: [] as $line) {
        $line = trim($line);
        if ($line === '' || str_starts_with($line, '#') || !str_contains($line, '=')) {
            continue;
        }

        [$key, $value] = explode('=', $line, 2);
        $key = trim($key);
        $value = trim($value);

        if (
            (str_starts_with($value, '"') && str_ends_with($value, '"')) ||
            (str_starts_with($value, "'") && str_ends_with($value, "'"))
        ) {
            $value = substr($value, 1, -1);
        }

        $env[$key] = $value;
    }

    return $env;
}

function fail_json(int $statusCode, string $message): never
{
    http_response_code($statusCode);
    echo json_encode(['success' => false, 'message' => $message]);
    exit;
}

$env = read_env_file(dirname(__DIR__) . DIRECTORY_SEPARATOR . '.env');

$keyId = getenv('SOLIS_API_KEY') ?: ($env['SOLIS_API_KEY'] ?? $env['SOLIS_KEY_ID'] ?? '');
$keySecret = getenv('SOLIS_API_SECRET') ?: ($env['SOLIS_API_SECRET'] ?? $env['SOLIS_KEY_SECRET'] ?? '');
$baseUrl = getenv('SOLIS_API_URL') ?: ($env['SOLIS_API_URL'] ?? 'https://www.soliscloud.com:13333');

if ($keyId === '' || $keySecret === '') {
    fail_json(500, 'Solis API credentials are missing on the server');
}

$input = json_decode(file_get_contents('php://input') ?: '', true);
if (!is_array($input)) {
    fail_json(400, 'Invalid JSON payload');
}

$endpoint = $input['endpoint'] ?? '';
$body = $input['body'] ?? null;

$allowedEndpoints = [
    '/v1/api/userStationList',
    '/v1/api/stationDetail',
    '/v1/api/stationDay',
    '/v1/api/stationMonth',
    '/v1/api/stationYear',
    '/v1/api/stationDayEnergyList',
    '/v1/api/inverterList',
    '/v1/api/inverterDetail',
    '/v1/api/inverterDay',
    '/v1/api/collectorList',
    '/v1/api/collectorDetail',
    '/v1/api/epmList',
    '/v1/api/epmDetail',
    '/v1/api/alarmList',
];

if (!is_string($endpoint) || !in_array($endpoint, $allowedEndpoints, true)) {
    fail_json(400, 'Endpoint is not allowed');
}

if (!is_array($body)) {
    fail_json(400, 'Request body must be an object');
}

$bodyJson = json_encode($body, JSON_UNESCAPED_SLASHES);
if ($bodyJson === false) {
    fail_json(400, 'Unable to encode request body');
}

$contentType = 'application/json';
$contentMd5 = base64_encode(md5($bodyJson, true));
$date = gmdate('D, d M Y H:i:s \G\M\T');
$signString = "POST\n{$contentMd5}\n{$contentType}\n{$date}\n{$endpoint}";
$signature = base64_encode(hash_hmac('sha1', $signString, $keySecret, true));
$url = rtrim($baseUrl, '/') . $endpoint;

$ch = curl_init($url);
if ($ch === false) {
    fail_json(500, 'Unable to initialize Solis request');
}

curl_setopt_array($ch, [
    CURLOPT_POST => true,
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_POSTFIELDS => $bodyJson,
    CURLOPT_CONNECTTIMEOUT => 10,
    CURLOPT_TIMEOUT => 25,
    CURLOPT_HTTPHEADER => [
        "Content-Type: {$contentType}",
        "Content-MD5: {$contentMd5}",
        "Date: {$date}",
        "Authorization: API {$keyId}:{$signature}",
    ],
]);

$responseBody = curl_exec($ch);
$curlError = curl_error($ch);
$statusCode = (int) curl_getinfo($ch, CURLINFO_RESPONSE_CODE);
curl_close($ch);

if ($responseBody === false) {
    fail_json(502, "Solis request failed: {$curlError}");
}

http_response_code($statusCode > 0 ? $statusCode : 502);
echo $responseBody;

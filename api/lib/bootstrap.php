<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
header('Access-Control-Max-Age: 86400');

$requestMethod = $_SERVER['REQUEST_METHOD'] ?? '';
if ($requestMethod === 'OPTIONS') {
    http_response_code(204);
    exit;
}

function api_read_env_file(string $path): array
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
        $value = trim($value);
        if (
            (str_starts_with($value, '"') && str_ends_with($value, '"')) ||
            (str_starts_with($value, "'") && str_ends_with($value, "'"))
        ) {
            $value = substr($value, 1, -1);
        }

        $env[trim($key)] = $value;
    }

    return $env;
}

function api_env(string $key, ?string $fallback = null): ?string
{
    static $env = null;
    if ($env === null) {
        $env = [];
        $explicitEnvFile = getenv('JARWINN_ENV_FILE');
        $paths = [
            $explicitEnvFile !== false ? $explicitEnvFile : null,
            dirname(__DIR__, 2) . DIRECTORY_SEPARATOR . '.env',
            dirname(__DIR__) . DIRECTORY_SEPARATOR . '.env',
        ];

        foreach ($paths as $path) {
            if (!is_string($path) || $path === '') {
                continue;
            }

            $env = array_merge($env, api_read_env_file($path));
        }
    }

    $value = getenv($key);
    if ($value !== false && $value !== '') {
        return $value;
    }

    return $env[$key] ?? $fallback;
}

function api_json(array $payload, int $statusCode = 200): never
{
    http_response_code($statusCode);
    echo json_encode($payload, JSON_UNESCAPED_SLASHES);
    exit;
}

function api_fail(int $statusCode, string $message, array $context = []): never
{
    api_json([
        'success' => false,
        'message' => $message,
        'context' => $context,
    ], $statusCode);
}

function api_cache_dir(): string
{
    $dir = dirname(__DIR__) . DIRECTORY_SEPARATOR . 'cache';
    if (!is_dir($dir)) {
        mkdir($dir, 0775, true);
    }
    return $dir;
}

function api_cache_get(string $key, int $ttlSeconds): ?array
{
    $entry = api_cache_entry($key);
    if ($entry === null) {
        return null;
    }

    if ((time() - (int) $entry['createdAt']) >= $ttlSeconds) {
        return null;
    }

    return $entry['payload'];
}

function api_cache_entry(string $key): ?array
{
    $file = api_cache_dir() . DIRECTORY_SEPARATOR . sha1($key) . '.json';
    if (!is_file($file)) {
        return null;
    }

    $raw = file_get_contents($file);
    if ($raw === false) {
        return null;
    }

    $cached = json_decode($raw, true);
    if (!is_array($cached) || !isset($cached['createdAt'], $cached['payload'])) {
        return null;
    }

    return $cached;
}

function api_cache_meta(string $key): array
{
    $entry = api_cache_entry($key);
    if ($entry === null) {
        return [
            'exists' => false,
            'ageSeconds' => null,
            'createdAt' => null,
        ];
    }

    $createdAt = (int) $entry['createdAt'];
    return [
        'exists' => true,
        'ageSeconds' => max(0, time() - $createdAt),
        'createdAt' => gmdate(DATE_ATOM, $createdAt),
    ];
}

function api_cache_get_stale(string $key, int $maxAgeSeconds): ?array
{
    $entry = api_cache_entry($key);
    if ($entry === null) {
        return null;
    }

    if ((time() - (int) $entry['createdAt']) >= $maxAgeSeconds) {
        return null;
    }

    return $entry['payload'];
}

function api_cache_put(string $key, array $payload): void
{
    $file = api_cache_dir() . DIRECTORY_SEPARATOR . sha1($key) . '.json';
    file_put_contents($file, json_encode([
        'createdAt' => time(),
        'payload' => $payload,
    ], JSON_UNESCAPED_SLASHES), LOCK_EX);
}

function api_lock_acquire(string $key, int $ttlSeconds = 120): mixed
{
    $file = api_cache_dir() . DIRECTORY_SEPARATOR . sha1('lock:' . $key) . '.lock';
    if (is_file($file) && (time() - (int) filemtime($file)) > $ttlSeconds) {
        @unlink($file);
    }

    $handle = @fopen($file, 'c');
    if ($handle === false) {
        return false;
    }

    if (!flock($handle, LOCK_EX | LOCK_NB)) {
        fclose($handle);
        return false;
    }

    ftruncate($handle, 0);
    fwrite($handle, (string) time());
    return $handle;
}

function api_lock_release(mixed $handle): void
{
    if ($handle === false || !is_resource($handle)) {
        return;
    }

    flock($handle, LOCK_UN);
    fclose($handle);
}

function api_run_background_php(string $script, array $args = []): void
{
    $php = PHP_BINARY;
    $cmd = '"' . $php . '" "' . $script . '"';
    foreach ($args as $arg) {
        $cmd .= ' ' . escapeshellarg((string) $arg);
    }

    if (PHP_OS_FAMILY === 'Windows') {
        @pclose(@popen('start /B "" ' . $cmd . ' > NUL 2>&1', 'r'));
        return;
    }

    @exec($cmd . ' > /dev/null 2>&1 &');
}

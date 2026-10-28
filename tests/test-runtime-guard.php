<?php
/**
 * Unit Test for Container Runtime Guard (scripts/runtime-guard.php)
 * Verifies that the container runtime guard neutralizes attack vectors.
 */

error_reporting(E_ALL);
ini_set('display_errors', '1');

$guardFile = dirname(__DIR__) . '/scripts/runtime-guard.php';

$passed = 0;
$failed = 0;

function assertContainerGuardBlocks($name, $server = [], $post = [], $get = []) {
    global $passed, $failed, $guardFile;

    $script = "<?php
        \$_SERVER = " . var_export(array_merge(['REQUEST_METHOD' => 'GET', 'REQUEST_URI' => '/', 'REMOTE_ADDR' => '127.0.0.1'], $server), true) . ";
        \$_POST = " . var_export($post, true) . ";
        \$_GET = " . var_export($get, true) . ";
        \$_COOKIE = [];
        require '{$guardFile}';
        echo 'ALLOWED';
    ";

    $tmp = tempnam(sys_get_temp_dir(), 'cg_test_');
    file_put_contents($tmp, $script);
    $out = shell_exec("php " . escapeshellarg($tmp) . " 2>&1");
    unlink($tmp);

    if (strpos($out, '403 Forbidden - Blocked by EOL-PHP-SecAuto') !== false || strpos($out, 'Host Header Malformed') !== false) {
        echo "  [PASS] {$name} -> Successfully blocked.\n";
        $passed++;
    } else {
        echo "  [FAIL] {$name} -> Failed to block! Output: " . trim($out) . "\n";
        $failed++;
    }
}

echo "=== Running EOL-PHP-SecAuto Container Runtime Guard Tests ===\n";

assertContainerGuardBlocks(
    'Vector 1: Upload progress delimiter injection',
    [],
    ['PHP_SESSION_UPLOAD_PROGRESS' => "evil_prefix|O:8:\"Exploit\":0:{}"]
);

assertContainerGuardBlocks(
    'Vector 2: Windows Best-Fit soft hyphen (%ad)',
    ['QUERY_STRING' => '%ad-d+allow_url_include=1']
);

assertContainerGuardBlocks(
    'Vector 3: Deep filter chain',
    [],
    [],
    ['filter' => 'php://filter/read=convert.iconv.utf-8.utf-16/resource=convert.base64-decode/resource=convert.iconv.utf-16.utf-8/resource=data']
);

assertContainerGuardBlocks(
    'Vector 4: phar:// wrapper in GET parameter',
    [],
    [],
    ['file' => 'phar:///tmp/payload.phar']
);

assertContainerGuardBlocks(
    'Vector 5: Sendmail -X log injection',
    [],
    ['email' => 'victim -X/tmp/shell.php']
);

assertContainerGuardBlocks(
    'Host Header with Newline Injection',
    ['HTTP_HOST' => "example.com\r\nSet-Cookie: pwn=1"]
);

echo "---------------------------------------------------------\n";
echo "Results: {$passed} Passed, {$failed} Failed\n";
echo "---------------------------------------------------------\n";

if ($failed > 0) {
    exit(1);
}
echo "All Container Runtime Guard unit tests passed successfully!\n";

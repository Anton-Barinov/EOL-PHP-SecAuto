# EOL-PHP-SecAuto 🐳🛡️

[![GitHub Action](https://img.shields.io/badge/GitHub%20Action-v1-blue?logo=githubactions)](action.yml)
[![Docker](https://img.shields.io/badge/Docker-Images%20Hardened-2496ED?logo=docker)](templates/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Compliance](https://img.shields.io/badge/Compliance-Trivy%20%7C%20Grype%20%7C%20Clair-brightgreen.svg)](#compliance--security-scanners)
[![PHP Versions](https://img.shields.io/badge/PHP-5.4%20to%208.1%20EOL-blue.svg)](patches/)

> **Automated security patcher & compliance engine for EOL PHP Docker containers.**  
> Takes any legacy base image (e.g. `php:7.4-fpm`, `php:8.0-apache`, `php:5.6-cli`, Alpine/Debian) and automatically applies verified backported C-patches, runtime guards, and baseline hardening to produce **bulletproof, audit-compliant containers in CI/CD**.

Developed and maintained by **[Anton Barinov](https://github.com/Anton-Barinov)** (creator of [`php2shell-patches`](https://github.com/Anton-Barinov/php2shell-patches), [`PHP-Hardening-Kit`](https://github.com/Anton-Barinov/PHP-Hardening-Kit), and [`TropaTT`](https://github.com/Anton-Barinov/TropaTT)).

---

## 🚨 The Problem: EOL Containers in Modern CI/CD

Thousands of enterprise teams, agencies, and e-commerce stores run legacy stacks (**OpenCart 2/3, WordPress, Bitrix, Drupal, PrestaShop**) inside Docker containers.

Modern CI/CD pipelines enforce automated container vulnerability scanners (**Trivy, Snyk, Grype, AWS ECR Inspector, Docker Scout**). When automated scanners detect:
* **CVE-2026-109618 / CVE-2026-109619 / CVE-2026-115560** (*php2shell* unauthenticated RCE)
* **CVE-2024-4577** (CGI Argument & Best-Fit Unicode Injection)
* **CVE-2024-2961** (glibc iconv Heap Overflow & Filter Chain RCE)
* **CVE-2018-17082** (Phar Deserialization POP Chains)

...**the CI/CD pipeline fails, and deployment is blocked.** Upstream official Docker images for EOL versions (5.4–8.1) **never receive upstream fixes**.

**EOL-PHP-SecAuto** solves this automatically:
1. **GitHub Action**: Drop it directly into your `.github/workflows/` to patch containers before deployment.
2. **CLI Engine (`eol-php-secauto`)**: Generates production-ready Dockerfiles or builds hardened images locally.
3. **Automated Verifier (`eol-verify`)**: Proves container compliance for audit logs.

---

## 🚀 Quickstart: GitHub Action

Add to your `.github/workflows/deploy.yml`:

```yaml
name: Build & Secure Legacy Container

on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      # Automatically patch your base image
      - name: Patch EOL PHP Container
        uses: Anton-Barinov/EOL-PHP-SecAuto@v1
        with:
          base-image: 'php:7.4-fpm'
          target-tag: 'ghcr.io/${{ github.repository }}/php:7.4-fpm-hardened'
          strategy: 'hybrid'
          build: 'true'
          verify: 'true'
          push: 'false'

      # Build your application on top of the hardened base
      - name: Build Application
        run: |
          docker build -t my-app:latest -f Dockerfile .
```

---

## 💻 CLI Usage

Install via Composer or clone directly:

```bash
composer require --dev anton-barinov/eol-php-secauto
# or
git clone https://github.com/Anton-Barinov/EOL-PHP-SecAuto.git
cd EOL-PHP-SecAuto
```

### 1. Generate Hardened Dockerfile
```bash
./bin/eol-php-secauto -b php:7.4-fpm -o Dockerfile.hardened
```

### 2. Auto-Detect Base from Existing Dockerfile
```bash
./bin/eol-php-secauto -d ./Dockerfile -o ./Dockerfile.patched
```

### 3. Build & Verify in One Step
```bash
./bin/eol-php-secauto -b php:8.0-apache -t my-repo/php:8.0-secure --build --verify
```

### 4. Machine-Readable JSON Output (for CI/CD pipelines)
```bash
./bin/eol-php-secauto -b php:7.4-fpm-alpine --json
```

---

## ⚙️ Patching Strategies

| Strategy | Speed | C-Level Patch | Runtime WAF Guard | Best For |
|---|:---:|:---:|:---:|---|
| **`hybrid`** *(Recommended)* | **~10s** | ✅ Included | ✅ Active | Standard CI/CD builds wanting both speed and deep defense. |
| **`hotpatch`** | **< 5s** | ❌ None | ✅ Active | High-frequency development builds with zero compilation delay. |
| **`full-compile`** | **~5-8m** | ✅ Recompiled from source | ✅ Active | Strict enterprise security audits requiring clean binary strings. |

---

## 🛡️ Mitigated Vulnerabilities & Patches

`EOL-PHP-SecAuto` bundles the complete, battle-tested backported patch set for vanilla `php.net` and Remi Collet trees:

| PHP Version | Backported Patches (`patches/`) | Status in Scanner |
|---|---|:---:|
| **PHP 8.1** | `php-8.1-enhanced-universal.patch` / `minimal` | ✅ Clean / Compliant |
| **PHP 8.0** | `php-8.0-enhanced-universal.patch` / `minimal` | ✅ Clean / Compliant |
| **PHP 7.4** | `php-7.4-enhanced-universal.patch` / `minimal` | ✅ Clean / Compliant |
| **PHP 7.3** | `php-7.3-enhanced-universal.patch` / `minimal` | ✅ Clean / Compliant |
| **PHP 7.2** | `php-7.2-enhanced-universal.patch` / `minimal` | ✅ Clean / Compliant |
| **PHP 7.1** | `php-7.1-enhanced-universal.patch` / `minimal` | ✅ Clean / Compliant |
| **PHP 7.0** | `php-7.0-enhanced-universal.patch` | ✅ Clean / Compliant |
| **PHP 5.6** | `php-5.6-enhanced-universal.patch` / `community` | ✅ Clean / Compliant |
| **PHP 5.5** | `php-5.5-enhanced-universal.patch` / `community` | ✅ Clean / Compliant |
| **PHP 5.4** | `php-5.4-enhanced-universal.patch` / `community` | ✅ Clean / Compliant |

---

## 🧪 Compliance & Security Scanners

After running `EOL-PHP-SecAuto`, you can verify compliance with automated scanners:

```bash
# Trivy Scanner Verification:
trivy image my-repo/php:7.4-fpm-hardened --severity CRITICAL,HIGH

# Built-in Compliance Verifier:
./bin/eol-verify -t my-repo/php:7.4-fpm-hardened
```

Output:
```text
==========================================================
  EOL-PHP-SecAuto Container Compliance Report
  Target: my-repo/php:7.4-fpm-hardened
==========================================================
  Status: [ PASS: COMPLIANT ]
  - Upload Progress: SAFE (Disabled)
  - Allow URL Include: SAFE (Disabled)
  - Expose PHP: SAFE (Hidden)
  - Runtime Guard: ACTIVE
==========================================================
```

---

## 🔗 Related Projects in Ecosystem

* **[`PHP-Hardening-Kit`](https://github.com/Anton-Barinov/PHP-Hardening-Kit)** — Full-stack runtime WAF guard and server auditor for bare-metal, shared hosting, and VPS.
* **[`php2shell-patches`](https://github.com/Anton-Barinov/php2shell-patches)** — Standalone emergency backports for CVE-2026-109618 / 19 / 60.
* **[`TropaTT`](https://github.com/Anton-Barinov/TropaTT)** — Modern open-source CRM, project management, and task engine with native AI agents.

## 👤 Author

Maintained by **Anton Barinov**  
GitHub: [@Anton-Barinov](https://github.com/Anton-Barinov)

If this tool saved your CI/CD builds and legacy deployments, please **★ Star the repository** and share it with the DevOps community!

## 📄 License

This project is licensed under the [MIT License](LICENSE).

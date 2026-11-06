# PHP Composer image

A Docker image for running Composer with PHP 8.5 CLI on Alpine Linux 3.24.

Licensed under the [MIT License](LICENSE).

## Image contents

- Updated Alpine packages, Bash, curl, Git, and unzip.
- Composer 2, installed after verifying the installer's SHA-384 signature.
- PHP extensions: `pdo_mysql`, `mbstring`, `dom`, `xml`, `xmlwriter`, and PCOV for code coverage.
- PHP memory limit set to `512M`.

`prepare-php.sh` installs the tools and extensions during the Docker build, then removes the temporary compilation dependencies. Composer and PCOV versions are not pinned, so rebuilding can change the installed versions.

## Build and use locally

Requires Docker with Linux container support. Run from this repository:

```sh
docker build --pull -t composer:local .
docker run --rm composer:local php --version
docker run --rm composer:local composer --version
docker run --rm composer:local php -m
```

To install dependencies for a PHP application, run from the application's directory, which must contain `composer.json`.

Bash:

```sh
docker run --rm --mount "type=bind,source=$(pwd),target=/app" --workdir /app composer:local composer install
```

PowerShell:

```powershell
docker run --rm --mount "type=bind,source=$($PWD.Path),target=/app" --workdir /app composer:local composer install
```

The container runs as root by default; files created in a bind mount may be owned by root on Linux. This repository contains the image setup, without an application or `composer.json`.

## GitHub Actions

The [workflow](.github/workflows/main.yml) runs on pushes, pull requests, and manual dispatches.

1. Hadolint, Checkov, Semgrep, and Trivy Dockerfile scans run in parallel. Checkov currently skips `CKV_DOCKER_2` (the health check requirement).
2. After all Dockerfile scans pass, Docker Buildx builds and loads the image locally.
3. Trivy scans the built image for vulnerabilities. No severity filter is configured, so reported vulnerabilities at any severity can fail the scan.
4. After a successful image scan, eligible runs tag and push the same local image to Docker Hub without rebuilding it.

Pull requests and non-default branches build and scan without publishing. Publishing runs on the default branch and tag refs. A newer run for the same ref cancels an older run.

### Docker Hub setup

Create a Docker Hub repository named `composer`. In the GitHub repository, add these Actions secrets under **Settings → Secrets and variables → Actions**:

| Secret | Value |
| --- | --- |
| `DOCKERHUB_USERNAME` | Your Docker Hub username |
| `DOCKERHUB_TOKEN` | A Docker Hub access token with permission to push to the repository |

Images publish to `docker.io/<username>/composer` with `latest` and a version tag:

- Tag-triggered runs use the triggering Git tag.
- Branch runs use the highest version-sorted Git tag pointing at the current commit.
- Commits without a tag use `sha-<full commit SHA>`.

Git tags must be valid Docker tag names. Every eligible publishing run also updates `latest`, including tag-triggered runs.

```sh
docker pull <username>/composer:latest
docker run --rm <username>/composer:latest composer --version
```

### Reports and failure artifacts

Download reports from the workflow run's **Artifacts** section. They are retained for 14 days. Upload steps run even after a preceding step fails, and scan failures still fail the workflow.

| Artifact | Contents |
| --- | --- |
| `<scanner>-reports-<run-id>-<attempt>` | Scanner JSON output and diagnostic log |
| `build-reports-<run-id>-<attempt>` | Docker build log and image metadata when available |
| `trivy-image-reports-<run-id>-<attempt>` | Image vulnerability JSON report and diagnostic log |

Steps skipped because of earlier failures do not produce reports. A failed build still produces `docker-build.log`, while image metadata is available only after a successful build.

### Current image-scan prerequisite

The workflow mounts `.trivyignore` from the repository root, but that file is currently absent. Before running the image scan, either add the file (empty if no exceptions are needed) or remove its bind mount and the `--ignorefile` argument from the workflow. Otherwise, Docker fails before Trivy can scan the image.

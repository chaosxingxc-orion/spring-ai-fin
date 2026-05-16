#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: bash scripts/render-architecture-views.sh [--png] [--check]

Renders L0 PlantUML architecture views.
  default   generate SVG exports
  --png     also generate PNG exports
  --check   render into a temporary directory and remove it afterward
USAGE
}

render_png=false
check_only=false

for arg in "$@"; do
  case "$arg" in
    --png)
      render_png=true
      ;;
    --check)
      check_only=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[architecture-views] ERROR: unknown argument: $arg" >&2
      usage >&2
      exit 2
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VIEW_ROOT="$REPO_ROOT/docs/architecture-views"
SRC_DIR="$VIEW_ROOT/plantuml/l0"
SVG_DIR="$VIEW_ROOT/exports/svg"
PNG_DIR="$VIEW_ROOT/exports/png"
IMAGE="${PLANTUML_DOCKER_IMAGE:-plantuml/plantuml:latest}"

if ! command -v docker >/dev/null 2>&1; then
  echo "[architecture-views] ERROR: Docker is required to render PlantUML views, but the docker command was not found." >&2
  echo "[architecture-views] Install Docker or run this script in an environment with Docker available." >&2
  exit 127
fi

required=(
  "$SRC_DIR/l0-scenario.puml"
  "$SRC_DIR/l0-logical.puml"
  "$SRC_DIR/l0-development.puml"
  "$SRC_DIR/l0-process.puml"
  "$SRC_DIR/l0-physical.puml"
)

for file in "${required[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "[architecture-views] ERROR: missing PlantUML source: ${file#$REPO_ROOT/}" >&2
    exit 1
  fi
done

cleanup_dir=""
if [[ "$check_only" == true ]]; then
  cleanup_dir="$(mktemp -d "$VIEW_ROOT/exports/.check.XXXXXX")"
  SVG_DIR="$cleanup_dir/svg"
  PNG_DIR="$cleanup_dir/png"
  trap 'rm -rf "$cleanup_dir"' EXIT
  echo "[architecture-views] Check mode: rendering into a temporary directory."
fi

mkdir -p "$SVG_DIR" "$PNG_DIR"

render_format() {
  local format="$1"
  local output_dir="$2"
  local output_rel
  output_rel="$(realpath --relative-to="$SRC_DIR" "$output_dir")"

  echo "[architecture-views] Rendering ${format^^} with Docker image $IMAGE"
  docker run --rm \
    -v "$REPO_ROOT:/workspace" \
    -w "/workspace/docs/architecture-views/plantuml/l0" \
    "$IMAGE" \
    "-t${format}" \
    -o "$output_rel" \
    l0-scenario.puml l0-logical.puml l0-development.puml l0-process.puml l0-physical.puml
}

render_format "svg" "$SVG_DIR"

if [[ "$render_png" == true ]]; then
  render_format "png" "$PNG_DIR"
fi

if [[ "$check_only" == true ]]; then
  expected=(l0-scenario l0-logical l0-development l0-process l0-physical)
  for name in "${expected[@]}"; do
    if [[ ! -s "$SVG_DIR/$name.svg" ]]; then
      echo "[architecture-views] ERROR: expected SVG was not generated: $name.svg" >&2
      exit 1
    fi
    if [[ "$render_png" == true && ! -s "$PNG_DIR/$name.png" ]]; then
      echo "[architecture-views] ERROR: expected PNG was not generated: $name.png" >&2
      exit 1
    fi
  done
  echo "[architecture-views] Check mode passed. Temporary exports will be removed."
else
  echo "[architecture-views] SVG exports written to ${SVG_DIR#$REPO_ROOT/}"
  if [[ "$render_png" == true ]]; then
    echo "[architecture-views] PNG exports written to ${PNG_DIR#$REPO_ROOT/}"
  fi
fi

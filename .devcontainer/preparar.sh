#!/usr/bin/env bash
# Se ejecuta una sola vez, al crear el Codespace.
set -e
pip install --user --quiet cfn-lint pytest==8.3.3 ruff==0.6.9
# Imágenes que usarán el emulador y los builds; descargarlas ahora ahorra tiempo en clase
docker pull "${FLOCI_IMAGE:-floci/floci:latest}"
docker pull python:3.12-slim
echo "Entorno preparado."

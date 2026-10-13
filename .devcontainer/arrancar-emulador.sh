#!/usr/bin/env bash
# Se ejecuta cada vez que se arranca el Codespace: levanta el emulador de AWS en el puerto 4566.
IMG="${FLOCI_IMAGE:-floci/floci:latest}"
if ! docker ps --format '{{.Names}}' | grep -qx emulador-aws; then
  docker rm -f emulador-aws >/dev/null 2>&1
  docker run -d --name emulador-aws -p 4566:4566 \
    -e FLOCI_DEFAULT_REGION=eu-west-1 \
    -v /var/run/docker.sock:/var/run/docker.sock \
    "$IMG" >/dev/null
fi
echo -n "Esperando al emulador de AWS"
for i in $(seq 1 60); do
  if aws sts get-caller-identity >/dev/null 2>&1; then
    echo " · listo en http://localhost:4566"; exit 0
  fi
  echo -n "."; sleep 2
done
echo
echo "El emulador no responde. Revisa: docker logs emulador-aws"
exit 1

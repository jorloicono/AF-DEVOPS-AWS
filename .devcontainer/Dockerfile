FROM mcr.microsoft.com/devcontainers/python:1-3.12-bookworm
# El repositorio de yarn de la imagen base tiene la clave caducada y rompe apt-get update
RUN rm -f /etc/apt/sources.list.d/yarn.list /etc/apt/sources.list.d/yarn*.list

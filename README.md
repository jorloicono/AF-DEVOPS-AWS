# Diseño e implementación de soluciones DevOps en AWS

Materiales del curso de 8 horas, impartido en dos sesiones síncronas de 4 horas (martes 13 y miércoles 14 de octubre de 2026, de 9:30 a 13:30).

## Hacer las prácticas sin cuenta de AWS y sin instalar nada

Las prácticas se hacen en el navegador, con **GitHub Codespaces** y un **emulador local de AWS** que se arranca solo dentro del Codespace. No necesitas cuenta de AWS, tarjeta ni instalar nada en tu ordenador: solo una cuenta gratuita de GitHub.

1. Entra en GitHub con tu cuenta (si no tienes, créala gratis en github.com).
2. En este repositorio, pulsa el botón verde **Code → pestaña Codespaces → Create codespace on master**.
3. Espera a que se abra el editor. La primera vez tarda entre 2 y 4 minutos, porque descarga el emulador y las imágenes que usan las prácticas.
4. En la terminal de la parte inferior, comprueba que todo funciona:

```bash
aws sts get-caller-identity
```

Si responde con una cuenta ficticia, ya puedes empezar. Si da error, ejecuta `bash .devcontainer/arrancar-emulador.sh`.

Los comandos `aws ...` de las prácticas son los mismos que usarías en AWS real: la variable `AWS_ENDPOINT_URL` hace que la CLI hable con el emulador en `http://localhost:4566` en lugar de con AWS. Para comprobar de una vez todo lo que usan las prácticas, ejecuta `bash comprobar-entorno.sh`.

**Cuida tus horas gratuitas.** Las cuentas personales de GitHub incluyen un número limitado de horas de Codespaces al mes, de sobra para el curso. Cuando termines, detén el Codespace: **Code → Codespaces → ⋯ → Stop codespace**. Si no lo usas, se detiene solo tras 30 minutos de inactividad.

## Contenido

La carpeta `presentaciones` contiene las diapositivas de cada sesión. La carpeta `practicas` contiene los laboratorios guiados, en Markdown y en PDF, preparados para el Codespace. En `practicas/aws_real` están las versiones originales para una cuenta de AWS real con CloudShell, por si quieres repetirlas en tu empresa.

| Laboratorio | Sesión | Duración |
|---|---|---|
| Lab 01 · Stacks, change sets y drift con CloudFormation | 1 | 50 min |
| Lab 02 · Build y pruebas automatizadas con CodeBuild | 1 | 55 min |
| Lab 03 · Pipeline completa con CodePipeline | 2 | 60 min |
| Lab 04 · Despliegue canary y rollback automático con CodeDeploy | 2 | 60 min |

## Sobre el emulador

El emulador es [Floci](https://floci.io), de código abierto (licencia MIT) y gratuito. Reproduce las API de AWS, pero no todo su comportamiento: cada práctica señala las diferencias que te vas a encontrar y cómo sería en AWS real. Lo que aprendes sobre CloudFormation, CodeBuild o CodePipeline es lo mismo; lo que no se puede probar en un emulador son los permisos reales de IAM, las cuotas, la red y los costes.

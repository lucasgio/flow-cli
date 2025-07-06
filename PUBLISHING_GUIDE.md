# Flow CLI Publishing Guide

Este documento describe los requisitos y el proceso para publicar el paquete Flow CLI en pub.dev.

## Cambios Realizados para la Publicación

### 1. Archivos Requeridos Agregados

- **LICENSE**: Archivo de licencia MIT (requerido para todos los paquetes)
- **CHANGELOG.md**: Seguimiento del historial de versiones
- **.pubignore**: Excluye archivos grandes y contenido innecesario del paquete publicado

### 2. pubspec.yaml Actualizado

Agregados campos de metadatos requeridos:
- `repository`: URL del repositorio de GitHub
- `issue_tracker`: URL de issues de GitHub  
- `documentation`: Enlace al README

### 3. Workflows de CI/CD Corregidos

- **Matriz de Build**: Ahora construye ejecutables para todas las plataformas (Linux, macOS, Windows)
- **Gestión de Artefactos**: Carga/descarga correcta de artefactos para assets de release
- **Assets de Release**: Todos los ejecutables de plataforma se suben a releases de GitHub
- **Publicación**: Publicación automatizada a pub.dev en release

## Problemas de Workflow Solucionados ✅

### Problema: Los Jobs de Build Se Saltan

**Problema**: Los jobs de build solo se ejecutaban en eventos de `release`, por lo que se saltaban durante el desarrollo normal.

**Solución**: 
- Modificadas las condiciones de los jobs de build para ejecutarse en más eventos
- Creado un workflow dedicado de build que siempre ejecuta los jobs
- Agregadas condiciones para ejecutar en `main` branch y releases

### Estructura de Workflows

#### Workflow Principal de CI/CD (`.github/workflows/ci.yml`)
- **Triggers**: Push a main/develop, PR a main, Release publicado
- **Jobs**:
  - `test`: Se ejecuta en todas las plataformas con múltiples versiones de Dart
  - `build-linux`: Construye ejecutable de Linux (main branch + release)
  - `build-macos`: Construye ejecutable de macOS (main branch + release)
  - `build-windows`: Construye ejecutable de Windows (main branch + release)
  - `publish`: Publica a pub.dev (solo release)
  - `release`: Crea assets de GitHub release (solo release)

#### Workflow de Build Dedicado (`.github/workflows/build.yml`)
- **Triggers**: Push a main/develop, PR a main, Manual dispatch
- **Propósito**: Siempre ejecuta los jobs de build para desarrollo y testing
- **Ventajas**: Garantiza que los builds se ejecuten en cada commit

#### Workflow Manual (`.github/workflows/manual-publish.yml`)
- **Triggers**: Manual workflow dispatch
- **Propósito**: Probar build y publicación sin crear un release
- **Opciones**: Puede elegir publicar a pub.dev o solo construir ejecutables

## Requisitos de Publicación ✅

Basado en la [documentación de publicación de Dart](https://dart.dev/tools/pub/publishing), todos los requisitos están cumplidos:

### ✅ Archivos Requeridos
- [x] Archivo LICENSE (Licencia MIT)
- [x] pubspec.yaml válido con metadatos completos
- [x] README.md con documentación completa
- [x] CHANGELOG.md para seguimiento de versiones

### ✅ Estructura del Paquete
- [x] Sigue las convenciones de paquetes de Dart
- [x] Estructura de directorios apropiada (lib/, bin/, test/)
- [x] Ejecutable definido en pubspec.yaml
- [x] Análisis pasa sin problemas

### ✅ Tamaño y Contenido
- [x] Tamaño del paquete bajo 100MB (actual: 37KB comprimido)
- [x] .pubignore excluye archivos grandes (ejecutable flow, artefactos de build)
- [x] Solo dependencias alojadas del servidor pub por defecto
- [x] No se incluyen archivos innecesarios

### ✅ Pipeline de CI/CD
- [x] Testing automatizado en múltiples plataformas
- [x] Verificación de formato y análisis de código
- [x] Verificación de build para todas las plataformas
- [x] Publicación automatizada a pub.dev
- [x] Creación de assets de GitHub release

## Proceso de Publicación

### Publicación Manual
```bash
# Probar el paquete
dart pub publish --dry-run

# Publicar a pub.dev (requiere PUB_TOKEN)
dart pub publish --force
```

### Publicación Automatizada
El paquete se publicará automáticamente cuando:
1. Se cree un GitHub release
2. Todas las pruebas de CI/CD pasen
3. El secreto `PUB_TOKEN` esté configurado en GitHub

### Testing de Workflows

#### Workflow de Build Automático
- Se ejecuta automáticamente en cada push a `main` o `develop`
- Construye ejecutables para todas las plataformas
- Sube artefactos para descarga

#### Workflow Manual
Para probar el proceso de build y publicación sin crear un release:

1. Ve a GitHub repository → Actions
2. Selecciona "Manual Publish" workflow
3. Haz clic en "Run workflow"
4. Elige si publicar a pub.dev o solo construir ejecutables
5. Haz clic en "Run workflow"

Esto te permite:
- Probar el proceso de build en todas las plataformas
- Verificar que los ejecutables se crean correctamente
- Probar la publicación sin crear un release
- Debuggear cualquier problema del workflow

## Secretos Requeridos

### Secretos del Repositorio de GitHub
- `PUB_TOKEN`: Tu token de autenticación de pub.dev

### Cómo Obtener PUB_TOKEN
1. Ve a https://pub.dev
2. Inicia sesión con tu cuenta de Google
3. Ve a la configuración de tu perfil
4. Genera un token de API
5. Agrégarlo a los secretos de tu repositorio de GitHub

## Gestión de Versiones

### Versionado Semántico
- Formato **MAJOR.MINOR.PATCH**
- Actualizar versión en `pubspec.yaml`
- Documentar cambios en `CHANGELOG.md`
- Crear GitHub release con tag de versión coincidente

### Proceso de Release
1. Actualizar versión en `pubspec.yaml`
2. Actualizar `CHANGELOG.md` con nueva versión
3. Commit y push de cambios
4. Crear GitHub release con tag de versión
5. CI/CD automáticamente:
   - Ejecutará pruebas
   - Construirá ejecutables
   - Publicará a pub.dev
   - Subirá assets de release

## Información del Paquete

- **Nombre**: flow_cli
- **Descripción**: Una herramienta CLI completa de Flutter para gestión de proyectos, construcción y despliegue
- **Página de inicio**: https://github.com/Flowstore/flow-cli
- **Licencia**: MIT
- **SDK**: >=3.0.0 <4.0.0
- **Ejecutable**: flow

## Instalación

Después de la publicación, los usuarios pueden instalar el paquete con:
```bash
dart pub global activate flow_cli
```

## Soporte

- **Issues**: https://github.com/Flowstore/flow-cli/issues
- **Documentación**: https://github.com/Flowstore/flow-cli#readme
- **Repositorio**: https://github.com/Flowstore/flow-cli 
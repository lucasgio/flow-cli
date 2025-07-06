#!/usr/bin/env python3
"""
Automates generation of app icons, splash screens and native app identifiers for Flutter flavors.
Usage: python tools/generate_branding.py <flavor>
Steps:
 1. Clean previous assets (Android mipmaps, iOS AppIcon and LaunchImage asset catalogs)
 2. Copy and validate icon, background, splash images from assets/configs/<flavor>/
 3. Update pubspec.yaml entries for flutter_launcher_icons and flutter_native_splash
 4. Generate flavor-specific YAML configs and run Dart commands to produce assets
 5. Update native package names and display names in Android and iOS
 6. Clean up temporary files and verify iOS asset catalogs
"""
import argparse
import json
import logging
import re
import shutil
import subprocess
import sys
import os
from pathlib import Path

from PIL import Image
from ruamel.yaml import YAML

# Dimensiones óptimas para cada plataforma
ICON_DIMENSIONS = {
    'android': {
        'adaptive_icon': 1024,  # 1024x1024 px
        'play_store': 512,      # 512x512 px
        'notification': 96,     # 96x96 px
    },
    'ios': {
        'app_store': 1024,      # 1024x1024 px
        'notification': 60,     # 60x60 px
        'settings': 29,         # 29x29 px
    }
}

SPLASH_DIMENSIONS = {
    'android': {
        'portrait': (1242, 2436),  # 1242x2436 px
        'landscape': (2436, 1242), # 2436x1242 px
    },
    'ios': {
        'portrait': (1242, 2688),  # 1242x2688 px (iPhone XS Max)
        'landscape': (2688, 1242), # 2688x1242 px
    }
}

# Project paths
PROJECT_ROOT = Path(__file__).parent.parent.resolve()
ANDROID_RES_DEFAULT = PROJECT_ROOT / 'android' / 'app' / 'src' / 'main' / 'res'
IOS_ASSETS = PROJECT_ROOT / 'ios' / 'Runner' / 'Assets.xcassets'
PUBSPEC = PROJECT_ROOT / 'pubspec.yaml'
CONFIG_BASE = PROJECT_ROOT / 'assets' / 'configs'
AndroidManifest = PROJECT_ROOT / 'android' / 'app' / 'src' / 'main' / 'AndroidManifest.xml'
AndroidGradle = PROJECT_ROOT / 'android' / 'app' / 'build.gradle.kts'
iOSInfoPlist = PROJECT_ROOT / 'ios' / 'Runner' / 'Info.plist'

logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')

def validate_image_dimensions(image_path: Path, required_dimensions: tuple, name: str):
    """Valida las dimensiones de una imagen"""
    try:
        with Image.open(image_path) as img:
            width, height = img.size
            if isinstance(required_dimensions, tuple):
                min_width, min_height = required_dimensions
                if width < min_width or height < min_height:
                    logging.error(f'❌ {name} debe tener dimensiones mínimas de {min_width}x{min_height}px (actual: {width}x{height}px)')
                    return False
            else:
                if width < required_dimensions or height < required_dimensions:
                    logging.error(f'❌ {name} debe tener dimensiones mínimas de {required_dimensions}x{required_dimensions}px (actual: {width}x{height}px)')
                    return False
                if width != height:
                    logging.error(f'❌ {name} debe ser cuadrada ({width}x{height}px)')
                    return False
            return True
    except Exception as e:
        logging.error(f'❌ Error al validar {name}: {str(e)}')
        return False

def clean_previous_app_data():
    """Limpia los datos de las apps anteriores en Android e iOS"""
    logging.info('Limpiando datos de apps anteriores...')
    
    # Limpiar datos de Android
    android_data = PROJECT_ROOT / 'android' / 'app' / 'build'
    if android_data.exists():
        shutil.rmtree(android_data)
        logging.info('✅ Limpiado build de Android')
    
    # Limpiar datos de iOS
    ios_data = PROJECT_ROOT / 'ios' / 'build'
    if ios_data.exists():
        shutil.rmtree(ios_data)
        logging.info('✅ Limpiado build de iOS')
    
    # Limpiar Pods de iOS
    ios_pods = PROJECT_ROOT / 'ios' / 'Pods'
    if ios_pods.exists():
        shutil.rmtree(ios_pods)
        logging.info('✅ Limpiado Pods de iOS')
    
    # Limpiar Podfile.lock
    podfile_lock = PROJECT_ROOT / 'ios' / 'Podfile.lock'
    if podfile_lock.exists():
        podfile_lock.unlink()
        logging.info('✅ Limpiado Podfile.lock')

def clean_previous_assets(android_res_path, flavor: str):
    logging.info('Limpiando assets anteriores...')
    if android_res_path.exists():
        for child in android_res_path.iterdir():
            if child.is_dir() and 'mipmap' in child.name:
                shutil.rmtree(child, ignore_errors=True)
    
    # Limpiar assets de iOS principales (que se generan por defecto)
    for folder in (IOS_ASSETS / 'AppIcon.appiconset', IOS_ASSETS / 'LaunchImage.imageset'):
        if folder.exists():
            shutil.rmtree(folder, ignore_errors=True)
        folder.mkdir(parents=True, exist_ok=True)

def validate_and_copy_images(flavor_dir: Path):
    """Valida y copia las imágenes necesarias para el branding"""
    logging.info('Validando y copiando imágenes...')
    
    # Validar y copiar icono
    icon_path = flavor_dir / 'icon.png'
    if not icon_path.exists():
        logging.error('❌ No se encontró icon.png en el directorio del flavor')
        sys.exit(1)
    
    if not validate_image_dimensions(icon_path, ICON_DIMENSIONS['android']['adaptive_icon'], 'icon.png'):
        sys.exit(1)
    
    # Validar y copiar splash
    splash_path = flavor_dir / 'splash.png'
    if not splash_path.exists():
        logging.error('❌ No se encontró splash.png en el directorio del flavor')
        sys.exit(1)
    
    if not validate_image_dimensions(splash_path, SPLASH_DIMENSIONS['android']['portrait'], 'splash.png'):
        sys.exit(1)
    
    # Copiar archivos al directorio raíz
    shutil.copy(icon_path, PROJECT_ROOT / 'icon.png')
    shutil.copy(splash_path, PROJECT_ROOT / 'splash.png')
    logging.info('✅ Imágenes validadas y copiadas correctamente')

def generate_pubspec_assets(flavor_dir: Path):
    yaml = YAML()
    yaml.preserve_quotes = True
    data = yaml.load(PUBSPEC)
    assets = data.setdefault('flutter', {}).setdefault('assets', [])
    
    # Leer el archivo config.json
    with (flavor_dir / 'config.json').open('r', encoding='utf-8') as f:
        config = json.load(f)
    
    # Agregar assets del flavor
    flavor_assets = [
        f'assets/configs/{flavor_dir.name}/icon.png',
        f'assets/configs/{flavor_dir.name}/splash.png',
        f'assets/configs/{flavor_dir.name}/config.json'
    ]
    
    for asset in flavor_assets:
        if asset not in assets:
            assets.append(asset)
    
    # Agregar assets adicionales del config
    for asset in config.get('assets', []):
        if asset not in assets:
            assets.append(asset)
    
    with PUBSPEC.open('w') as f:
        yaml.dump(data, f)
    logging.info('✅ Actualizado pubspec.yaml con los assets')

def update_pubspec(main_color: str, has_splash: bool):
    yaml = YAML()
    yaml.preserve_quotes = True
    data = yaml.load(PUBSPEC)
    
    # Configurar flutter_launcher_icons
    icons = data.setdefault('flutter_launcher_icons', {})
    icons.update({
        'android': True,
        'ios': True,
        'image_path_ios': 'icon.png',
        'adaptive_icon_background': main_color,
        'adaptive_icon_foreground': 'icon.png',
        'remove_alpha_ios': True,
        'min_sdk_android': 21,
        'web': False,
        'background_color_ios': main_color  # Color de fondo para iOS
    })
    
    # Configurar flutter_native_splash
    splash = data.setdefault('flutter_native_splash', {})
    splash.update({
        'color': main_color,
        'image': 'splash.png',
        'android_12': {
            'image': 'splash.png',
            'icon_background_color': main_color
        },
        'ios': True,
        'android': True,
        'web': False
    })
    
    with PUBSPEC.open('w') as f:
        yaml.dump(data, f)
    logging.info('✅ Actualizado pubspec.yaml con la configuración de branding')

def move_assets_to_flavor(flavor: str, android_res_path: Path):
    """Mueve los assets generados desde src/main/res a la carpeta específica del flavor"""
    logging.info(f'Moviendo assets a {android_res_path}...')
    
    main_res = PROJECT_ROOT / 'android' / 'app' / 'src' / 'main' / 'res'
    
    # Crear la carpeta de destino si no existe
    android_res_path.mkdir(parents=True, exist_ok=True)
    
    # Mover carpetas de mipmap (iconos) - solo si existen
    for mipmap_dir in main_res.glob('mipmap-*'):
        if mipmap_dir.is_dir() and mipmap_dir.exists():
            dest_dir = android_res_path / mipmap_dir.name
            if dest_dir.exists():
                shutil.rmtree(dest_dir)
            shutil.move(str(mipmap_dir), str(dest_dir))
            logging.info(f'✅ Movido {mipmap_dir.name}')
    
    # Mover archivos de configuración - solo si existen
    config_files = [
        'values/colors.xml',
        'drawable/launch_background.xml',
        'drawable-v21/launch_background.xml',
        'values/styles.xml',
        'values-night/styles.xml',
        'values-v31/styles.xml',
        'values-night-v31/styles.xml'
    ]
    
    for config_file in config_files:
        src_file = main_res / config_file
        if src_file.exists():
            dest_file = android_res_path / config_file
            dest_file.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(src_file), str(dest_file))
            logging.info(f'✅ Movido {config_file}')
    
    logging.info(f'✅ Assets movidos a {android_res_path}')

def generate_and_run(flavor: str, main_color: str):
    """Genera y ejecuta los comandos para crear los assets"""
    flavor_cfg = CONFIG_BASE / flavor
    
    # Generar configuración para flutter_launcher_icons (Android e iOS)
    icons_cfg = {
        'flutter_launcher_icons': {
            'android': True,
            'ios': True,  # Habilitar iOS
            'image_path': f'assets/configs/{flavor}/icon.png',
            'min_sdk_android': 21,
            'adaptive_icon_background': main_color,
            'adaptive_icon_foreground': f'assets/configs/{flavor}/icon.png',
            'background_color_ios': main_color,  # Color de fondo para iOS
            'remove_alpha_ios': True  # Remover canal alpha para iOS
        }
    }
    icons_yaml = flavor_cfg / f'flutter_launcher_icons-{flavor}.yaml'
    YAML().dump(icons_cfg, icons_yaml.open('w'))
    logging.info(f'✅ Generado {icons_yaml.name}')
    
    # Generar configuración para flutter_native_splash (Android e iOS)
    splash_cfg = {
        'flutter_native_splash': {
            'color': main_color,
            'image': f'assets/configs/{flavor}/splash.png',
            'android_12': {
                'image': f'assets/configs/{flavor}/splash.png',
                'icon_background_color': main_color
            },
            'ios': True,
            'android': True,
            'web': False
        }
    }
    splash_yaml = flavor_cfg / f'flutter_native_splash-{flavor}.yaml'
    YAML().dump(splash_cfg, splash_yaml.open('w'))
    logging.info(f'✅ Generado {splash_yaml.name}')
    
    # Ejecutar comandos desde el directorio raíz
    original_dir = Path.cwd()
    try:
        os.chdir(PROJECT_ROOT)
        
        # Generar iconos
        subprocess.run([
            'dart', 'run', 'flutter_launcher_icons',
            '-f', str(icons_yaml),
        ], check=True)
        logging.info('✅ Iconos generados correctamente')
        
        # Generar splash screen
        subprocess.run([
            'dart', 'run', 'flutter_native_splash:create',
            f'--path={splash_yaml}'
        ], check=True)
        logging.info('✅ Splash screen generado correctamente')
        
    except subprocess.CalledProcessError as e:
        logging.error(f'❌ Error al generar assets: {str(e)}')
        sys.exit(1)
    finally:
        os.chdir(original_dir)

def update_android_config(package_name: str, app_name: str):
    if AndroidManifest.exists():
        text = AndroidManifest.read_text(encoding='utf-8')
        text = re.sub(r'package="[^"]+"', f'package="{package_name}"', text)
        text = re.sub(r'android:label="[^"]+"', f'android:label="{app_name}"', text)
        AndroidManifest.write_text(text, encoding='utf-8')
        logging.info('✅ Actualizado AndroidManifest.xml')
    
    if AndroidGradle.exists():
        text = AndroidGradle.read_text(encoding='utf-8')
        text = re.sub(r'applicationId\s*=\s*"[^"]+"', f'applicationId = "{package_name}"', text)
        AndroidGradle.write_text(text, encoding='utf-8')
        logging.info('✅ Actualizado build.gradle.kts')

def update_ios_config(package_name: str, app_name: str):
    if iOSInfoPlist.exists():
        content = iOSInfoPlist.read_text(encoding='utf-8')
        content = re.sub(
            r'<key>CFBundleIdentifier</key>\s*<string>[^<]+</string>',
            f'<key>CFBundleIdentifier</key>\n\t<string>{package_name}</string>', content)
        
        if '<key>CFBundleDisplayName</key>' in content:
            content = re.sub(
                r'<key>CFBundleDisplayName</key>\s*<string>[^<]+</string>',
                f'<key>CFBundleDisplayName</key>\n\t<string>{app_name}</string>', content)
        else:
            content = re.sub(
                r'(<key>CFBundleIdentifier</key>\s*<string>[^<]+</string>)',
                r"\1\n\t<key>CFBundleDisplayName</key>\n\t<string>" + app_name + "</string>", content)
        
        iOSInfoPlist.write_text(content, encoding='utf-8')
        logging.info('✅ Actualizado Info.plist')

def verify_ios_assets(flavor: str):
    """Verifica que los assets de iOS se hayan generado correctamente en la carpeta principal"""
    app_icon = IOS_ASSETS / 'AppIcon.appiconset'
    launch_img = IOS_ASSETS / 'LaunchImage.imageset'
    
    if (app_icon.exists() and any(app_icon.glob('*.png')) and (app_icon / 'Contents.json').exists()):
        logging.info('✅ iOS AppIcon.appiconset OK')
    else:
        logging.error('❌ iOS AppIcon.appiconset incompleto')
    
    if (launch_img.exists() and any(launch_img.glob('*.png')) and (launch_img / 'Contents.json').exists()):
        logging.info('✅ iOS LaunchImage.imageset OK')
    else:
        logging.error('❌ iOS LaunchImage.imageset incompleto')

def main():
    parser = argparse.ArgumentParser(description='Generate Flutter branding assets by flavor')
    parser.add_argument('flavor', help='Flavor name to process')
    parser.add_argument('--android-res-path', help='Custom Android res path for flavor', default=None)
    args = parser.parse_args()

    flavor = args.flavor
    android_res_path = Path(args.android_res_path).resolve() if args.android_res_path else ANDROID_RES_DEFAULT
    config_file = CONFIG_BASE / flavor / 'config.json'
    
    if not config_file.exists():
        logging.error(f'❌ Config no encontrado: {config_file}')
        sys.exit(1)
    
    config = json.loads(config_file.read_text())
    main_color = '#' + config.get('mainColor', '').lstrip('#')
    app_name = config.get('appName', flavor.capitalize())
    package_name = f"com.giolabs.{flavor}"

    # Ejecutar pasos en orden
    clean_previous_app_data()
    clean_previous_assets(android_res_path, flavor)
    validate_and_copy_images(CONFIG_BASE / flavor)
    generate_pubspec_assets(CONFIG_BASE / flavor)
    update_pubspec(main_color, (PROJECT_ROOT / 'splash.png').exists())
    generate_and_run(flavor, main_color)
    move_assets_to_flavor(flavor, android_res_path)
    update_android_config(package_name, app_name)
    update_ios_config(package_name, app_name)
    verify_ios_assets(flavor)

    # Limpiar archivos temporales
    for tmp in ['icon.png', 'splash.png']:
        p = PROJECT_ROOT / tmp
        if p.exists():
            p.unlink()
    logging.info('✅ Archivos temporales limpiados')

    logging.info(f'✅ Branding completado para flavor `{flavor}` con app `{app_name}` y package `{package_name}`')

if __name__ == '__main__':
    main()

# Flow CLI

A comprehensive Flutter CLI tool for project management, building, and deployment.

## Features

- 🚀 **Easy Setup**: Interactive setup with multi-client support
- 🔨 **Build Management**: Build Flutter apps for Android and iOS
- 📱 **Device Management**: Deploy and manage apps on devices and emulators
- ⚡ **Hot Reload**: Interactive hot reload with real-time logging and controls
- 🌐 **Web Development**: Full-featured web development server and deployment
- 🔍 **Analysis Tools**: Analyze and optimize Flutter applications
- ⚙️ **Configuration**: Manage Flutter SDK and project settings
- 🌍 **Bilingual Support**: English and Spanish documentation
- 🎨 **Branding**: Automated asset generation for multiple clients

## Installation

### From pub.dev

```bash
dart pub global activate flow_cli
```

### From source

```bash
git clone https://github.com/Flowstore/flow-cli.git
cd flow-cli
dart pub get
dart pub global activate --source path .
```

## Quick Start

1. **Initialize Flow CLI**:
   ```bash
   flow setup
   ```

2. **Configure for multi-client** (optional):
   ```bash
   flow setup --multi-client
   ```

3. **Build your app**:
   ```bash
   flow build android --debug
   flow build ios --release
   ```

4. **Deploy to device**:
   ```bash
   flow device run
   ```

## Commands

### Setup
Initialize and configure your Flutter project:
```bash
flow setup [--multi-client]
```

### Build
Build Flutter applications:
```bash
flow build <platform> [options]

# Examples:
flow build android --debug
flow build ios --release --client client1
flow build web --release --pwa
flow build android --clean
```

### Device Management
Manage devices and deployments:
```bash
flow device <command> [options]

# Examples:
flow device list
flow device run --client client1
flow device logs --platform android
flow device install --client client1
```

### Hot Reload
Start an interactive hot reload session with real-time logging:
```bash
flow hotreload [options]

# Examples:
flow hotreload
flow hotreload --device emulator-5554
flow hotreload --client client1 --verbose
flow hotreload --log-level warning
```

#### Hot Reload Controls
During a hot reload session, you can use these keyboard shortcuts:
- `r` - Perform hot reload ⚡
- `R` - Perform hot restart 🔄
- `h` - Show help
- `c` - Clear console
- `l` - Toggle log level
- `v` - Toggle verbose mode
- `s` - Capture screenshot
- `d` - Show device info
- `q` - Quit session

### Web Development & Deployment
Comprehensive web development and deployment tools:
```bash
flow web <command> [options]

# Development Server
flow web serve
flow web serve --port 8080 --auto-open
flow web serve --client client1 --verbose

# Building
flow web build --release
flow web build --pwa --wasm
flow web build --tree-shake-icons --source-maps

# Deployment
flow web deploy
flow web analyze
flow web pwa
flow web optimize
```

#### Web Development Server
The web development server provides:
- **Hot Reload**: Real-time code changes without full page refresh
- **Auto Browser Opening**: Automatically opens your default browser
- **Live Logging**: Real-time web console and Flutter logs
- **Performance Monitoring**: Track build times and bundle sizes
- **Multi-client Support**: Serve different client configurations

#### Web Server Controls
During development, use these keyboard shortcuts:
- `r` - Hot reload
- `R` - Hot restart  
- `o` - Open in browser
- `h` - Show help
- `c` - Clear console
- `l` - Show logs
- `p` - Performance stats
- `q` - Quit server

#### PWA Support
Enable Progressive Web App features:
- **Service Worker**: Automatic caching and offline support
- **Web App Manifest**: Native app-like installation
- **App Icons**: Optimized icons for all device sizes
- **Responsive Design**: Mobile-first responsive layouts

#### Deployment Platforms
Deploy to popular hosting platforms:
- 🔥 **Firebase Hosting**: Google's fast global CDN
- 🌐 **Netlify**: JAMstack deployment with CI/CD
- ▲ **Vercel**: Zero-config deployments
- 📄 **GitHub Pages**: Free hosting for open source
- ☁️ **AWS S3**: Scalable cloud storage
- 🖥️ **Custom Server**: FTP/SFTP deployment
- 📁 **Manual**: Copy files to any hosting

#### Web Optimization
Automatic optimizations include:
- **Tree Shaking**: Remove unused code and icons
- **Code Splitting**: Reduce initial bundle size
- **Asset Optimization**: Compress images and resources
- **Source Maps**: Debug-friendly production builds
- **WebAssembly**: Enable WASM compilation for performance
- **Bundle Analysis**: Detailed size and performance reports

### Analysis
Analyze and optimize your Flutter app:
```bash
flow analyze [options]

# Examples:
flow analyze --all
flow analyze --optimize
flow analyze --performance --size
```

### Configuration
Manage CLI configuration:
```bash
flow config <command> [value]

# Examples:
flow config --list
flow config flutter-path /path/to/flutter
flow config language es
flow config add-client client1
```

## Multi-Client Support

Flow CLI supports managing multiple clients with different branding and configurations.

### Setup Multi-Client Structure

1. Run setup with multi-client option:
   ```bash
   flow setup --multi-client
   ```

2. Create client folders in `assets/configs/`:
   ```
   assets/
     configs/
       client1/
         ├── icon.png (1024x1024)
         ├── splash.png (1242x2436)
         └── config.json
       client2/
         ├── icon.png
         ├── splash.png
         └── config.json
   ```

3. Configure each client in `config.json`:
   ```json
   {
     "appName": "My App",
     "mainColor": "#FF0000",
     "packageName": "com.example.myapp",
     "assets": []
   }
   ```

### Build for Specific Client

```bash
flow build android --client client1 --release
flow build ios --client client2 --debug
```

## Configuration

Flow CLI stores configuration in `~/.flow_cli/config.json`. You can modify settings using:

```bash
flow config flutter-path /path/to/flutter/sdk
flow config project-path /path/to/your/project
flow config language es
```

## Branding Generation

Flow CLI includes automated branding generation using the `generate_branding.py` script. This script:

- Generates app icons and splash screens
- Updates native configurations
- Manages assets for multiple clients
- Optimizes images for different platforms

## Language Support

Flow CLI supports multiple languages:

- English (`en`)
- Spanish (`es`)

Set language during setup or change it later:
```bash
flow config language es
```

## Development

### Project Structure

```
lib/
├── core/
│   ├── constants/
│   ├── errors/
│   ├── usecases/
│   └── utils/
├── features/
│   ├── setup/
│   ├── build/
│   ├── device/
│   ├── analyze/
│   └── config/
└── shared/
    ├── models/
    ├── services/
    └── repositories/
```

### Running Tests

```bash
dart test
```

### Building

```bash
dart compile exe bin/main.dart -o flow
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- 🐛 **Bug Reports**: [GitHub Issues](https://github.com/Flowstore/flow-cli/issues)
- 📖 **Documentation**: [Flow CLI Docs](https://docs.flowstore.com/flow-cli)
- 💬 **Community**: [Discord](https://discord.gg/flowstore)

## Roadmap

- [x] Hot reload support
- [x] Web deployment
- [ ] Advanced analytics
- [ ] Plugin system
- [ ] CI/CD integrations
- [ ] Performance monitoring

---

Made with ❤️ by the Flowstore team
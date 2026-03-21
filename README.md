# CabritApp

**[English](#english) | [Español](#español)**

---

<a name="english"></a>
## English

A native macOS media player built with SwiftUI and AVKit. It connects to Xtream Codes-compatible servers for live TV, movies, and series.

### Features

- Xtream Codes login (server URL + username/password)
- Live TV, Movies, and Series browsing with categories
- Dark theme with poster cards and smooth animations
- Native player with PiP, fullscreen, and keyboard shortcuts (arrow keys to skip 10s)
- Continue Watching — automatically saves and resumes playback position
- Favorites and smart search (diacritic-insensitive)
- Custom categories and quality filters (4K, FHD, HD, etc.)

### Requirements

- macOS 14.0+ (Sonoma)
- Xcode 15+ (only if building from source)

### Installation

Download the latest `.dmg` from [Releases](https://github.com/Gael-OC/CabritApp/releases), open it, and drag **CabritApp** to your Applications folder.

> Since the app isn't signed with an Apple Developer certificate, macOS may block it the first time. To open it: right-click the app > Open, or go to System Settings > Privacy & Security > Open Anyway.

### Building from source

```bash
git clone https://github.com/Gael-OC/CabritApp.git
cd CabritApp
open CabritApp.xcodeproj
```

Select "My Mac" as target and press Cmd+R.

### Project structure

```
CabritApp/
├── CabritAppApp.swift         # Entry point
├── Models.swift                # Data models
├── AppViewModel.swift          # Business logic
├── XtreamService.swift         # API client
├── Persistence.swift           # Local storage
├── LoginView.swift             # Login screen
├── ContentView.swift           # Root view
├── DashboardView.swift         # Main UI
├── PlayerView.swift            # Video player
├── CarouselSectionView.swift   # Carousel component
├── ContentDetailView.swift     # Detail sheet
├── CategoryManagerView.swift   # Category manager
└── CachedAsyncImage.swift      # Image cache
```

### Technical Notes

- **SSL Certificate Validation**: CabritApp bypasses SSL certificate verification for all connections (`TrustAllCertsDelegate`). This is intentional — many IPTV servers use self-signed or expired certificates and would otherwise fail to connect. This means traffic to an IPTV server is **not authenticated by a trusted CA**, which is an acceptable tradeoff for a media player connecting to a user-provided server.
- **Credentials Storage**: Username, password, and server URL are stored in `UserDefaults` (not in Keychain). This avoids macOS password prompts when the app is not notarized. The stored data is local to the Mac and protected by the OS user account.

### Disclaimer

This application is a generic media player. It does not include, provide, or distribute any media content, playlists, or streaming URLs. The user is solely responsible for the content they access. This software is provided "as is", without warranty of any kind. The developer is not affiliated with any IPTV service provider.

---

<a name="español"></a>
## Español

Un reproductor multimedia nativo para macOS hecho con SwiftUI y AVKit. Se conecta a servidores compatibles con Xtream Codes para ver TV en vivo, películas y series.

### Funcionalidades

- Login con Xtream Codes (URL del servidor + usuario/contraseña)
- TV en vivo, películas y series organizadas por categorías
- Tema oscuro con tarjetas tipo póster y animaciones suaves
- Reproductor nativo con PiP, pantalla completa y atajos de teclado (flechas para saltar 10s)
- Continuar viendo — guarda y retoma la posición automáticamente
- Favoritos y búsqueda inteligente (ignora acentos)
- Categorías personalizadas y filtros de calidad (4K, FHD, HD, etc.)

### Requisitos

- macOS 14.0+ (Sonoma)
- Xcode 15+ (solo si compilas desde el código)

### Instalación

Descarga el `.dmg` más reciente de [Releases](https://github.com/Gael-OC/CabritApp/releases), ábrelo y arrastra **CabritApp** a tu carpeta de Aplicaciones.

> Como la app no está firmada con un certificado de Apple Developer, macOS puede bloquearla la primera vez. Para abrirla: clic derecho > Abrir, o ir a Ajustes del Sistema > Privacidad y Seguridad > Abrir de todos modos.

### Compilar desde el código

```bash
git clone https://github.com/Gael-OC/CabritApp.git
cd CabritApp
open CabritApp.xcodeproj
```

Selecciona "My Mac" como destino y presiona Cmd+R.

### Notas técnicas

- **Certificados SSL**: CabritApp omite la verificación de certificados SSL (`TrustAllCertsDelegate`) de forma intencional. Muchos servidores IPTV usan certificados autofirmados o vencidos, y sin este bypass la conexión fallaría. Esto es un compromiso aceptable para un reproductor que se conecta a servidores provistos por el usuario.
- **Almacenamiento de credenciales**: El usuario, contraseña y URL del servidor se guardan en `UserDefaults` (no en Keychain) para evitar popups de macOS en apps no notarizadas. Los datos quedan en el Mac y están protegidos por la cuenta del sistema operativo.

### Aviso legal

Esta aplicación es un reproductor multimedia genérico. No incluye, provee ni distribuye contenido multimedia, listas de reproducción ni URLs de streaming. El usuario es el único responsable del contenido al que accede. Este software se proporciona "tal cual", sin garantía de ningún tipo. El desarrollador no está afiliado a ningún proveedor de servicios IPTV.

---

## License / Licencia

MIT License — see [LICENSE](LICENSE).

## Contributing / Contribuir

Bug reports, feature suggestions, and pull requests are welcome.

Los reportes de bugs, sugerencias y pull requests son bienvenidos.

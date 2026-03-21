import SwiftUI
import Foundation
import Combine

// MARK: - Language Definition

enum AppLanguage: String, CaseIterable, Identifiable {
    case es = "es"
    case en = "en"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .es: return "Español"
        case .en: return "English"
        }
    }
}

// MARK: - Localized String Keys

enum L10nKey: String, Hashable {
    // Media Types
    case typeLive
    case typeVOD
    case typeSeries
    
    // Login
    case loginSubtitle
    case loginServerPlaceholder
    case loginUser
    case loginPassword
    case loginRemember
    case loginButton
    case loginForgetSaved
    case loginConnecting
    case loginLoadingLive
    case loginLoadingVOD
    case loginLoadingSeries
    case loginReady
    
    // Sidebar
    case sidebarContent
    case sidebarActions
    case sidebarReload
    case sidebarManage
    case sidebarCategories
    case sidebarUser
    case sidebarLogout
    case sidebarLanguage
    
    // Top Bar & States
    case searchPlaceholder
    case searchPrefixResults
    case searchNoResults
    case clearFilters
    case loadingPrefix
    case stateEmptyTitle
    case stateEmptyDesc
    case stateErrorTitle
    case stateRetry
    
    // Home Sections
    case btnPlay
    case continueWatching
    case btnRemoveContinue
    case sectionFavorites
    
    // Items & Cards
    case btnAddFav
    case btnRemoveFav
    case noEpisodesTitle
    case loadingEpisodes
    
    // Category Manager
    case catMgrTitle
    case catMgrCustomTitle
    case catMgrNewBtn
    case catMgrNoCustom
    case catMgrHiddenTitle
    case catMgrShowBtn
    case catMgrHideBtn
    case catMgrNoHidden
    case catMgrTabServer
    case catMgrTabCustom
    case catMgrShowAll
    case catMgrHideAll
    case catMgrFromServer
    case catMgrItems
    case catMgrGroupHint
    case catMgrAppearFirst
    case catMgrVisible
    case catMgrHidden
    case catMgrCustomLabel
    case catMgrCategoryName
    case catMgrNamePlaceholder
    case catMgrCategoriesSelected
    case catMgrSelectAll
    case catMgrDeselect
    case catMgrSave
    case catMgrCreate
    case catMgrEditTitle
    case catMgrNewTitle
    
    // Content Detail
    case detailPlot
    case detailCast
    case detailDirector
    case detailGenre
    case detailTrailer
    case detailLoadingInfo
    case detailEpisodes
    case detailSeason
    
    // Carousel / Section
    case seeAll
    case hideCategory
    
    // Errors
    case errInvalidURL
    case errAuthFailed
    case errMalformed
    case errHostNotFound
    case errTimeout
    case errConnectionLost
    case errNetworkGen
}

// MARK: - The Content Dictionary

private let translations: [AppLanguage: [L10nKey: String]] = [
    .es: [
        .typeLive: "Canales",
        .typeVOD: "Películas",
        .typeSeries: "Series",
        
        .loginSubtitle: "Canales en vivo · Películas · Series",
        .loginServerPlaceholder: "Servidor (ej: http://tu-servidor.com:8880)",
        .loginUser: "Usuario",
        .loginPassword: "Contraseña",
        .loginRemember: "Recordar credenciales en este Mac",
        .loginButton: "Entrar",
        .loginForgetSaved: "Olvidar cuenta",
        .loginConnecting: "Conectando al servidor…",
        .loginLoadingLive: "Cargando TV en vivo…",
        .loginLoadingVOD: "Cargando películas…",
        .loginLoadingSeries: "Cargando series…",
        .loginReady: "¡Listo!",
        
        .sidebarContent: "Contenido",
        .sidebarActions: "Acciones",
        .sidebarReload: "Recargar",
        .sidebarManage: "Gestionar",
        .sidebarCategories: "Categorías",
        .sidebarUser: "Usuario",
        .sidebarLogout: "Cerrar sesión",
        .sidebarLanguage: "Idioma (Language)",
        
        .searchPlaceholder: "Buscar…",
        .searchPrefixResults: "resultados",
        .searchNoResults: "Sin resultados para",
        .clearFilters: "Limpiar",
        .loadingPrefix: "Cargando",
        .stateEmptyTitle: "Sin contenido",
        .stateEmptyDesc: "Prueba recargar.",
        .stateErrorTitle: "Error al cargar",
        .stateRetry: "Reintentar",
        
        .btnPlay: "Reproducir",
        .continueWatching: "Continuar viendo",
        .btnRemoveContinue: "Quitar de continuar viendo",
        .sectionFavorites: "⭐ Favoritos",
        
        .btnAddFav: "Añadir a favoritos",
        .btnRemoveFav: "Quitar de favoritos",
        .noEpisodesTitle: "Sin episodios",
        .loadingEpisodes: "Cargando episodios…",
        
        .catMgrTitle: "Gestionar Categorías",
        .catMgrCustomTitle: "Tus Categorías Personalizadas",
        .catMgrNewBtn: "Nueva Categoría…",
        .catMgrNoCustom: "No has creado ninguna categoría.",
        .catMgrHiddenTitle: "Categorías Ocultas",
        .catMgrShowBtn: "Mostrar",
        .catMgrHideBtn: "Ocultar",
        .catMgrNoHidden: "No tienes categorías ocultas.",
        .catMgrTabServer: "Servidor",
        .catMgrTabCustom: "Personalizadas",
        .catMgrShowAll: "Mostrar todas",
        .catMgrHideAll: "Ocultar todas",
        .catMgrFromServer: "del servidor",
        .catMgrItems: "elementos",
        .catMgrGroupHint: "Agrupa categorías del servidor bajo un nombre personalizado.",
        .catMgrAppearFirst: "Las personalizadas aparecen primero en el dashboard.",
        .catMgrVisible: "visibles",
        .catMgrHidden: "ocultas",
        .catMgrCustomLabel: "personalizadas",
        .catMgrCategoryName: "Nombre",
        .catMgrNamePlaceholder: "Ej: Deportes, Cine, Infantil…",
        .catMgrCategoriesSelected: "Categorías (%d seleccionadas)",
        .catMgrSelectAll: "Seleccionar todo",
        .catMgrDeselect: "Deseleccionar",
        .catMgrSave: "Guardar",
        .catMgrCreate: "Crear",
        .catMgrEditTitle: "Editar categoría",
        .catMgrNewTitle: "Nueva categoría",
        
        .detailPlot: "Sinopsis",
        .detailCast: "Reparto",
        .detailDirector: "Director",
        .detailGenre: "Género",
        .detailTrailer: "Ver Trailer",
        .detailLoadingInfo: "Cargando info…",
        .detailEpisodes: "episodios",
        .detailSeason: "Temporada",
        
        .seeAll: "Ver todo",
        .hideCategory: "Ocultar",
        
        // Errors
        .errInvalidURL: "La URL del servidor no es válida. Usa http(s)://host[:puerto]",
        .errAuthFailed: "No se pudo iniciar sesión. Revisa servidor, usuario y contraseña.",
        .errMalformed: "La respuesta del servidor no tiene el formato esperado.",
        .errHostNotFound: "No se encontró el servidor. Revisa la URL.",
        .errTimeout: "Tiempo de espera agotado.",
        .errConnectionLost: "No se pudo conectar al servidor.",
        .errNetworkGen: "Error de red"
    ],
    .en: [
        .typeLive: "Live TV",
        .typeVOD: "Movies",
        .typeSeries: "Series",
        
        .loginSubtitle: "Live Channels · Movies · TV Shows",
        .loginServerPlaceholder: "Server URL (e.g., http://your-server.com:8880)",
        .loginUser: "Username",
        .loginPassword: "Password",
        .loginRemember: "Remember credentials on this Mac",
        .loginButton: "Sign In",
        .loginForgetSaved: "Forget account",
        .loginConnecting: "Connecting to server…",
        .loginLoadingLive: "Loading Live TV…",
        .loginLoadingVOD: "Loading Movies…",
        .loginLoadingSeries: "Loading Series…",
        .loginReady: "Ready!",
        
        .sidebarContent: "Content",
        .sidebarActions: "Actions",
        .sidebarReload: "Reload",
        .sidebarManage: "Manage",
        .sidebarCategories: "Categories",
        .sidebarUser: "User",
        .sidebarLogout: "Sign Out",
        .sidebarLanguage: "Language (Idioma)",
        
        .searchPlaceholder: "Search…",
        .searchPrefixResults: "results",
        .searchNoResults: "No results for",
        .clearFilters: "Clear",
        .loadingPrefix: "Loading",
        .stateEmptyTitle: "No Content",
        .stateEmptyDesc: "Try reloading.",
        .stateErrorTitle: "Failed to Load",
        .stateRetry: "Retry",
        
        .btnPlay: "Play",
        .continueWatching: "Continue Watching",
        .btnRemoveContinue: "Remove from continue watching",
        .sectionFavorites: "⭐ Favorites",
        
        .btnAddFav: "Add to favorites",
        .btnRemoveFav: "Remove from favorites",
        .noEpisodesTitle: "No episodes",
        .loadingEpisodes: "Loading episodes…",
        
        .catMgrTitle: "Manage Categories",
        .catMgrCustomTitle: "Your Custom Categories",
        .catMgrNewBtn: "New Category…",
        .catMgrNoCustom: "You haven't created any custom categories.",
        .catMgrHiddenTitle: "Hidden Categories",
        .catMgrShowBtn: "Show",
        .catMgrHideBtn: "Hide",
        .catMgrNoHidden: "You don't have any hidden categories.",
        .catMgrTabServer: "Server",
        .catMgrTabCustom: "Custom",
        .catMgrShowAll: "Show all",
        .catMgrHideAll: "Hide all",
        .catMgrFromServer: "from server",
        .catMgrItems: "items",
        .catMgrGroupHint: "Group server categories under a custom name.",
        .catMgrAppearFirst: "Custom categories appear first on the dashboard.",
        .catMgrVisible: "visible",
        .catMgrHidden: "hidden",
        .catMgrCustomLabel: "custom",
        .catMgrCategoryName: "Name",
        .catMgrNamePlaceholder: "e.g. Sports, Kids, Cinema…",
        .catMgrCategoriesSelected: "Categories (%d selected)",
        .catMgrSelectAll: "Select all",
        .catMgrDeselect: "Deselect",
        .catMgrSave: "Save",
        .catMgrCreate: "Create",
        .catMgrEditTitle: "Edit Category",
        .catMgrNewTitle: "New Category",
        
        .detailPlot: "Plot",
        .detailCast: "Cast",
        .detailDirector: "Director",
        .detailGenre: "Genre",
        .detailTrailer: "Watch Trailer",
        .detailLoadingInfo: "Loading info…",
        .detailEpisodes: "episodes",
        .detailSeason: "Season",
        
        .seeAll: "See All",
        .hideCategory: "Hide",
        
        // Errors
        .errInvalidURL: "Invalid server URL. Use http(s)://host[:port]",
        .errAuthFailed: "Login failed. Check server, username and password.",
        .errMalformed: "The server response format is not supported.",
        .errHostNotFound: "Server not found. Check the URL.",
        .errTimeout: "Connection timed out.",
        .errConnectionLost: "Could not connect to the server.",
        .errNetworkGen: "Network Error"
    ]
]

// MARK: - Manager

@MainActor
final class LanguageManager: ObservableObject {
    @Published var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "app_lang")
        }
    }
    
    init() {
        if let saved = UserDefaults.standard.string(forKey: "app_lang"),
           let lang = AppLanguage(rawValue: saved) {
            self.currentLanguage = lang
        } else {
            // Default to English as requested
            self.currentLanguage = .en
        }
    }
    
    /// Translates a strictly typed key
    func t(_ key: L10nKey) -> String {
        return translations[currentLanguage]?[key] ?? key.rawValue
    }
    
    /// Fallback for completely dynamic strings (like media types) to support switching language models without reloading
    func tMediaType(_ type: MediaType) -> String {
        switch type {
        case .live: return t(.typeLive)
        case .vod: return t(.typeVOD)
        case .series: return t(.typeSeries)
        }
    }
    
    func tSubtitleForMediaType(_ type: MediaType) -> String {
        switch type {
        case .live: return currentLanguage == .en ? "Live Television" : "Televisión en vivo"
        case .vod: return currentLanguage == .en ? "On-Demand Movies" : "Películas a demanda"
        case .series: return currentLanguage == .en ? "TV Shows and Episodes" : "Series y episodios"
        }
    }
    
    func toggleLanguage() {
        currentLanguage = (currentLanguage == .es) ? .en : .es
    }
}

// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get moveToCenter => 'Mover al centro';

  @override
  String get appTitle => 'Simple Player';

  @override
  String get windowInitializationFailed => 'Error al inicializar la ventana';

  @override
  String get brandName => 'S I M P L E   P L A Y E R';

  @override
  String get emptyStateSubtitle => 'Experiencia audiovisual inmersiva';

  @override
  String get openFile => 'Abrir archivo';

  @override
  String get openFileTooltip => 'Abrir archivo (O)';

  @override
  String get dragHint => 'Suelta un video aquí para reproducirlo';

  @override
  String get playModeLoopAll => 'Secuencial';

  @override
  String get playModeLoopSingle => 'Repetir uno';

  @override
  String get playModeShuffle => 'Aleatorio';

  @override
  String get shortcutPlayPause => 'Reproducir / Pausar';

  @override
  String get shortcutSeek => 'Retroceder/avanzar 5 segundos';

  @override
  String get shortcutVolume => 'Volumen +/- 5 %';

  @override
  String get shortcutFullscreen => 'Alternar pantalla completa';

  @override
  String get shortcutExitFullscreen => 'Salir de pantalla completa';

  @override
  String get shortcutMute => 'Silenciar/reactivar sonido';

  @override
  String get shortcutNext => 'Siguiente';

  @override
  String get shortcutPrevious => 'Anterior';

  @override
  String get shortcutOpenFile => 'Abrir archivo';

  @override
  String get shortcutSubtitle => 'Alternar subtítulos';

  @override
  String get shortcutPlaylist => 'Alternar lista de reproducción';

  @override
  String get shortcutSubtitleDelay => 'Retraso de subtítulos +/- 500 ms';

  @override
  String get shortcutHelp => 'Mostrar ayuda';

  @override
  String get shortcutMediaKeys => 'Reproducir/Pausar';

  @override
  String get settings => 'Configuración';

  @override
  String get back => 'Atrás';

  @override
  String get settingsSummaryGeneral =>
      'Idioma · Tarjeta de errores · Reanudar reproducción';

  @override
  String get settingsSummaryVideo =>
      'Brillo · Contraste · Rotación · Relación de aspecto';

  @override
  String get settingsSummaryAudio => 'Retraso de audio · Retraso de subtítulos';

  @override
  String get settingsSummaryAbout =>
      'Componentes · Agradecimientos · Tecnologías';

  @override
  String get audioTab => 'Audio';

  @override
  String get specialThanks => 'Agradecimientos especiales';

  @override
  String get thanksPending => 'La lista se está preparando — muy pronto';

  @override
  String get lgplNotice =>
      'mpv y FFmpeg se enlazan dinámicamente bajo LGPL-2.1-or-later — los detalles de cumplimiento están en el archivo NOTICE incluido';

  @override
  String get generalTab => 'General';

  @override
  String get language => 'Idioma';

  @override
  String get theme => 'Tema';

  @override
  String get shortcutsTab => 'Atajos';

  @override
  String get aboutTab => 'Acerca de';

  @override
  String get equalizer => 'Ecualizador';

  @override
  String get audioTrack => 'Pista de audio';

  @override
  String get videoTab => 'Video';

  @override
  String get noAudioTracks => 'No hay pistas de audio disponibles';

  @override
  String get videoProcessingUnavailable =>
      'Procesamiento de video no disponible';

  @override
  String audioTrackN(int index) {
    return 'Pista $index';
  }

  @override
  String get eqOff => 'Desactivado';

  @override
  String get eqBassBoost => 'Realce de graves';

  @override
  String get eqVocalBoost => 'Realce de voces';

  @override
  String get eqRock => 'Rock';

  @override
  String get eqClassical => 'Clásica';

  @override
  String get colorCorrection => 'Corrección de color';

  @override
  String get brightness => 'Brillo';

  @override
  String get contrast => 'Contraste';

  @override
  String get saturation => 'Saturación';

  @override
  String get hue => 'Tono';

  @override
  String get rotation => 'Rotación';

  @override
  String get aspectRatio => 'Relación de aspecto';

  @override
  String get deinterlace => 'Desentrelazado';

  @override
  String get resetAll => 'Restablecer todo';

  @override
  String get enableDeinterlace => 'Activar desentrelazado';

  @override
  String get softwareDecoderOnly => 'Solo con decodificador por software';

  @override
  String get videoProcessing => 'Video';

  @override
  String get shortcutsHelpTitle => 'Atajos de teclado';

  @override
  String get close => 'Cerrar';

  @override
  String get previousTrack => 'Anterior';

  @override
  String get nextTrack => 'Siguiente';

  @override
  String get playlist => 'Lista de reproducción';

  @override
  String get fullscreen => 'Pantalla completa (F)';

  @override
  String get exitFullscreen => 'Salir de pantalla completa (F)';

  @override
  String get openSubtitle => 'Abrir subtítulos';

  @override
  String get play => 'Reproducir';

  @override
  String get resumePlayback => 'Reanudar desde el punto guardado';

  @override
  String get pause => 'Pausar';

  @override
  String get stop => 'Detener';

  @override
  String get rewind10 => 'Retroceder 10 s';

  @override
  String get forward30 => 'Avanzar 30 s';

  @override
  String get pin => 'Siempre visible';

  @override
  String get unpin => 'Desanclar';

  @override
  String get minimize => 'Minimizar';

  @override
  String get maximize => 'Maximizar';

  @override
  String get restore => 'Restaurar';

  @override
  String get playlistEmpty => 'La lista de reproducción está vacía';

  @override
  String get resumeRememberPosition => 'Recordar posición de reproducción';

  @override
  String get audioDelay => 'Retraso de audio';

  @override
  String get subtitleDelay => 'Retraso de subtítulos';

  @override
  String get sortBy => 'Ordenar';

  @override
  String get sortByAddedOrder => 'Por orden de adición';

  @override
  String get sortByName => 'Por nombre';

  @override
  String get sortByLastPlayed => 'Por última reproducción';

  @override
  String get sortByDuration => 'Por duración';

  @override
  String get sortAscending => 'Ascendente';

  @override
  String get sortDescending => 'Descendente';

  @override
  String get noHistory => 'Sin historial de reproducción';

  @override
  String get playlistTab => 'Lista de reproducción';

  @override
  String get historyTab => 'Historial';

  @override
  String get clear => 'Vaciar';

  @override
  String get playAction => 'Reproducir';

  @override
  String get copyPath => 'Copiar ruta';

  @override
  String get properties => 'Propiedades';

  @override
  String get remove => 'Quitar';

  @override
  String get pathCopied => 'Ruta copiada';

  @override
  String breakpointAt(String time) {
    return 'Punto guardado $time';
  }

  @override
  String lastPlayedAt(String time) {
    return 'Reproducido hasta $time';
  }

  @override
  String get justNow => 'Justo ahora';

  @override
  String minutesAgo(int minutes) {
    return 'Hace $minutes min';
  }

  @override
  String hoursAgo(int hours) {
    return 'Hace $hours h';
  }

  @override
  String daysAgo(int days) {
    return 'Hace $days días';
  }

  @override
  String get propertiesDialog => 'Propiedades';

  @override
  String get fileSection => 'Archivo';

  @override
  String get filePath => 'Ruta';

  @override
  String get fileName => 'Nombre del archivo';

  @override
  String get videoSection => 'Video';

  @override
  String get resolution => 'Resolución';

  @override
  String get codec => 'Códec';

  @override
  String get pixelAspectRatio => 'Proporción de píxeles';

  @override
  String get aspectRatioLabel => 'Relación de aspecto';

  @override
  String get durationSection => 'Duración';

  @override
  String get totalDuration => 'Duración total';

  @override
  String get audioSection => 'Audio';

  @override
  String get trackCount => 'Número de pistas';

  @override
  String trackN(int index) {
    return 'Pista $index';
  }

  @override
  String get subtitleSection => 'Subtítulos';

  @override
  String get copied => 'Copiado';

  @override
  String get doubleClickToCopy => 'Doble clic para copiar';

  @override
  String get unknown => 'Desconocido';

  @override
  String get reopen => 'Volver a abrir';

  @override
  String get selectOtherFile => 'Elegir otro archivo';

  @override
  String get retry => 'Reintentar';

  @override
  String get unmute => 'Reactivar sonido';

  @override
  String get mute => 'Silenciar';

  @override
  String get volume => 'Volumen';

  @override
  String volumePercent(String percent) {
    return 'Volumen $percent %';
  }

  @override
  String get aspectRatioOriginal => 'Original';

  @override
  String get aspectRatioStretch => 'Estirar';

  @override
  String get aspectRatioCropFill => 'Recortar para llenar';

  @override
  String get aspectRatioFree => 'Libre';

  @override
  String get progressBar => 'Progreso de reproducción';

  @override
  String get speedDecrease => 'Reducir velocidad';

  @override
  String get speedReset => 'Velocidad (doble clic para restablecer)';

  @override
  String get speedIncrease => 'Aumentar velocidad';

  @override
  String get folderTab => 'Carpeta';

  @override
  String get resumeAction => 'Reanudar';

  @override
  String get openFileLocation => 'Abrir ubicación del archivo';

  @override
  String get clearHistory => 'Borrar historial';

  @override
  String get scanFolder => 'Escanear carpeta';

  @override
  String get noVideosInFolder => 'No hay videos en la carpeta';

  @override
  String get themeMidnight => 'Medianoche';

  @override
  String get themeOcean => 'Océano';

  @override
  String get themeForest => 'Bosque';

  @override
  String get version => 'Versión';

  @override
  String get techStack => 'Tecnologías';

  @override
  String get licenses => 'Licencias';

  @override
  String get copyright => 'Creado con Flutter + mpv_kit (libmpv)';

  @override
  String get resetShortcuts => 'Restablecer valores predeterminados';

  @override
  String get pressKeyToBind => 'Presiona una tecla…';

  @override
  String get shortcutConflict => 'Tecla ya asignada';

  @override
  String get currentTheme => 'Tema';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancelar';

  @override
  String get apply => 'Aplicar';

  @override
  String get playerLoadError => 'No se pudo cargar el módulo del reproductor';

  @override
  String get playerInitFailed => 'Error al inicializar el reproductor';

  @override
  String get performanceTab => 'Rendimiento';

  @override
  String get d3d11Rendering => 'Renderizado D3D11';

  @override
  String get d3d11Sync => 'Sincronización CPU D3D11';

  @override
  String get d3d11SyncDesc =>
      'Sincroniza la CPU y la GPU en cada fotograma. Desactívalo para menor latencia; puede causar desgarro de imagen.';

  @override
  String get decoderSettings => 'Decodificador';

  @override
  String get hardwareDecoding => 'Decodificación por hardware';

  @override
  String get hardwareDecodingDesc =>
      'Usa la GPU para decodificar el video. Desactívalo si ves artefactos.';

  @override
  String get performanceHint =>
      'Los cambios se aplican al abrir el siguiente archivo.';

  @override
  String get resetToDefaults => 'Restablecer valores predeterminados';

  @override
  String resetConfirmTitle(String tabName) {
    return '¿Restablecer la configuración de $tabName?';
  }

  @override
  String get resetConfirmMessage =>
      'Las siguientes configuraciones se restablecerán a los valores predeterminados:';

  @override
  String get confirmReset => 'Restablecer';

  @override
  String get exportSettings => 'Exportar';

  @override
  String get importSettings => 'Importar';

  @override
  String get importConfirmTitle => '¿Importar configuración?';

  @override
  String get importConfirmMessage =>
      'Las siguientes configuraciones se sobrescribirán:';

  @override
  String get importConfirmCategories =>
      'Reproducción, Video, Subtítulos, Ventana, Atajos, Tema, Idioma';

  @override
  String get importSuccess => 'Configuración importada';

  @override
  String importError(String error) {
    return 'Error al importar: $error';
  }

  @override
  String get exportError => 'Error al exportar';

  @override
  String get exportSuccess => 'Configuración exportada';

  @override
  String importParseError(String error) {
    return 'JSON no válido: $error';
  }

  @override
  String importFileReadError(String error) {
    return 'No se puede leer el archivo: $error';
  }

  @override
  String get openingMedia => 'Abriendo el medio';

  @override
  String get bufferingMedia => 'Almacenando en búfer';

  @override
  String get errorFilePathEmpty => 'La ruta del archivo está vacía';

  @override
  String get errorFileNotFound => 'Archivo no encontrado';

  @override
  String get errorFilepathTraversal => 'Ruta de archivo no válida';

  @override
  String get errorCodecUnsupportedFormat => 'Formato multimedia no compatible';

  @override
  String get errorCodecDecodeFailed => 'No se pudo decodificar el medio';

  @override
  String get errorCodecCodecUnsupported => 'Códec no compatible';

  @override
  String get errorPlaybackPlayFailed => 'Error de reproducción';

  @override
  String get errorPlaybackSeekFailed => 'Error al buscar posición';

  @override
  String get errorPlaybackTextureFailed => 'Error al renderizar el video';

  @override
  String get errorPlaybackOpenTimeout => 'Tiempo de apertura agotado';

  @override
  String get errorNetworkTimeout => 'Tiempo de espera de red agotado';

  @override
  String get errorNetworkConnectionLost => 'Conexión perdida';

  @override
  String get errorUnknown => 'Ocurrió un error inesperado';

  @override
  String errorCardBadgeLabel(int count) {
    return '$count errores';
  }

  @override
  String get errorCardClose => 'Cerrar';

  @override
  String get errorCardCopyTooltip => 'Copiar diagnóstico';

  @override
  String get errorCardCopied => 'Copiado';

  @override
  String get errorCardCopiedPathInLog => 'Copiado — ruta completa en error.log';

  @override
  String get errorCardCopyFailed => 'Error al copiar';

  @override
  String get errorCardOpenLogTooltip => 'Abrir ubicación del registro';

  @override
  String get errorCardLogOpened => 'Registro abierto';

  @override
  String get errorCardOpenLogFailed => 'Error al abrir el registro';

  @override
  String get errorCardSectionLocation => 'Ubicación';

  @override
  String get errorCardSectionSource => 'Líneas de código';

  @override
  String get errorCardSectionStack => 'Seguimiento de pila';

  @override
  String get errorCardSectionLogPath => 'Archivo de registro';

  @override
  String errorCardSectionRepeats(int count) {
    return 'Repeticiones: $count';
  }

  @override
  String get errorCardLogUnavailable => 'Archivo de registro no disponible';

  @override
  String get errorCardLocationUnavailable => 'Ubicación no disponible';

  @override
  String get errorCardCycleTooltip => 'Alternar entre errores';

  @override
  String get errorCardToggleLabel => 'Tarjeta de errores';

  @override
  String get languageLabel => 'Idioma';

  @override
  String get languageSystem => 'Según el sistema';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChinese => '中文';

  @override
  String get batchDelete => 'Eliminación por lotes';

  @override
  String batchSelectedCount(int count) {
    return '$count seleccionados';
  }

  @override
  String get selectAll => 'Seleccionar todo';

  @override
  String get batchDeleteConfirmTitle => 'Eliminar videos seleccionados';

  @override
  String batchDeleteConfirmBody(int count) {
    return 'Se quitarán $count entradas de video de la lista de reproducción. Esta operación solo afecta a la lista de reproducción misma y no eliminará ningún archivo de tu disco local.';
  }

  @override
  String get batchDeleteConfirmAction => 'Confirmar eliminación';

  @override
  String get playlistEntriesGone =>
      'Las entradas ya no están en la lista de reproducción';
}

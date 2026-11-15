// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get moveToCenter => 'Déplacer au centre';

  @override
  String get appTitle => 'Simple Player';

  @override
  String get windowInitializationFailed =>
      'Échec de l\'initialisation de la fenêtre';

  @override
  String get brandName => 'S I M P L E   P L A Y E R';

  @override
  String get emptyStateSubtitle => 'Expérience audiovisuelle immersive';

  @override
  String get openFile => 'Ouvrir un fichier';

  @override
  String get openFileTooltip => 'Ouvrir un fichier (O)';

  @override
  String get dragHint => 'Déposez une vidéo ici pour la lire';

  @override
  String get playModeLoopAll => 'Séquentiel';

  @override
  String get playModeLoopSingle => 'Boucle unique';

  @override
  String get playModeShuffle => 'Aléatoire';

  @override
  String get shortcutPlayPause => 'Lecture / Pause';

  @override
  String get shortcutSeek => 'Reculer/avancer de 5 secondes';

  @override
  String get shortcutVolume => 'Volume +/- 5 %';

  @override
  String get shortcutFullscreen => 'Basculer en plein écran';

  @override
  String get shortcutExitFullscreen => 'Quitter le plein écran';

  @override
  String get shortcutMute => 'Couper/rétablir le son';

  @override
  String get shortcutNext => 'Suivant';

  @override
  String get shortcutPrevious => 'Précédent';

  @override
  String get shortcutOpenFile => 'Ouvrir un fichier';

  @override
  String get shortcutSubtitle => 'Afficher/masquer les sous-titres';

  @override
  String get shortcutPlaylist => 'Afficher/masquer la liste de lecture';

  @override
  String get shortcutSubtitleDelay => 'Décalage des sous-titres +/- 500 ms';

  @override
  String get shortcutHelp => 'Afficher l\'aide';

  @override
  String get shortcutMediaKeys => 'Lecture/Pause';

  @override
  String get settings => 'Paramètres';

  @override
  String get back => 'Retour';

  @override
  String get settingsSummaryGeneral =>
      'Langue · Carte d\'erreurs · Reprise de la lecture';

  @override
  String get settingsSummaryVideo =>
      'Luminosité · Contraste · Rotation · Format d\'image';

  @override
  String get settingsSummaryAudio => 'Retard audio · Retard des sous-titres';

  @override
  String get settingsSummaryAbout =>
      'Composants · Remerciements · Pile technique';

  @override
  String get audioTab => 'Audio';

  @override
  String get specialThanks => 'Remerciements spéciaux';

  @override
  String get thanksPending => 'La liste est en préparation — restez à l\'affût';

  @override
  String get lgplNotice =>
      'mpv et FFmpeg sont liés dynamiquement sous LGPL-2.1-or-later — les détails de conformité figurent dans le fichier NOTICE fourni';

  @override
  String get generalTab => 'Général';

  @override
  String get language => 'Langue';

  @override
  String get theme => 'Thème';

  @override
  String get shortcutsTab => 'Raccourcis';

  @override
  String get aboutTab => 'À propos';

  @override
  String get equalizer => 'Égaliseur';

  @override
  String get audioTrack => 'Piste audio';

  @override
  String get videoTab => 'Vidéo';

  @override
  String get noAudioTracks => 'Aucune piste audio disponible';

  @override
  String get videoProcessingUnavailable => 'Traitement vidéo indisponible';

  @override
  String audioTrackN(int index) {
    return 'Piste $index';
  }

  @override
  String get eqOff => 'Désactivé';

  @override
  String get eqBassBoost => 'Renforcement des basses';

  @override
  String get eqVocalBoost => 'Renforcement des voix';

  @override
  String get eqRock => 'Rock';

  @override
  String get eqClassical => 'Classique';

  @override
  String get colorCorrection => 'Correction des couleurs';

  @override
  String get brightness => 'Luminosité';

  @override
  String get contrast => 'Contraste';

  @override
  String get saturation => 'Saturation';

  @override
  String get hue => 'Teinte';

  @override
  String get rotation => 'Rotation';

  @override
  String get aspectRatio => 'Format d\'image';

  @override
  String get deinterlace => 'Désentrelacement';

  @override
  String get resetAll => 'Tout réinitialiser';

  @override
  String get enableDeinterlace => 'Activer le désentrelacement';

  @override
  String get softwareDecoderOnly => 'Décodeur logiciel uniquement';

  @override
  String get videoProcessing => 'Vidéo';

  @override
  String get shortcutsHelpTitle => 'Raccourcis clavier';

  @override
  String get close => 'Fermer';

  @override
  String get previousTrack => 'Précédent';

  @override
  String get nextTrack => 'Suivant';

  @override
  String get playlist => 'Liste de lecture';

  @override
  String get fullscreen => 'Plein écran (F)';

  @override
  String get exitFullscreen => 'Quitter le plein écran (F)';

  @override
  String get openSubtitle => 'Ouvrir des sous-titres';

  @override
  String get play => 'Lecture';

  @override
  String get resumePlayback => 'Reprendre au point de reprise';

  @override
  String get pause => 'Pause';

  @override
  String get stop => 'Arrêter';

  @override
  String get rewind10 => 'Reculer de 10 s';

  @override
  String get forward30 => 'Avancer de 30 s';

  @override
  String get pin => 'Toujours au premier plan';

  @override
  String get unpin => 'Désépingler';

  @override
  String get minimize => 'Réduire';

  @override
  String get maximize => 'Agrandir';

  @override
  String get restore => 'Restaurer';

  @override
  String get playlistEmpty => 'La liste de lecture est vide';

  @override
  String get resumeRememberPosition => 'Mémoriser la position de lecture';

  @override
  String get audioDelay => 'Retard audio';

  @override
  String get subtitleDelay => 'Retard des sous-titres';

  @override
  String get sortBy => 'Trier';

  @override
  String get sortByAddedOrder => 'Par ordre d\'ajout';

  @override
  String get sortByName => 'Par nom';

  @override
  String get sortByLastPlayed => 'Par dernière lecture';

  @override
  String get sortByDuration => 'Par durée';

  @override
  String get sortAscending => 'Croissant';

  @override
  String get sortDescending => 'Décroissant';

  @override
  String get noHistory => 'Aucun historique de lecture';

  @override
  String get playlistTab => 'Liste de lecture';

  @override
  String get historyTab => 'Historique';

  @override
  String get clear => 'Vider';

  @override
  String get playAction => 'Lire';

  @override
  String get copyPath => 'Copier le chemin';

  @override
  String get properties => 'Propriétés';

  @override
  String get remove => 'Retirer';

  @override
  String get pathCopied => 'Chemin copié';

  @override
  String breakpointAt(String time) {
    return 'Point de reprise $time';
  }

  @override
  String lastPlayedAt(String time) {
    return 'Dernière lecture jusqu\'à $time';
  }

  @override
  String get justNow => 'À l\'instant';

  @override
  String minutesAgo(int minutes) {
    return 'Il y a $minutes min';
  }

  @override
  String hoursAgo(int hours) {
    return 'Il y a $hours h';
  }

  @override
  String daysAgo(int days) {
    return 'Il y a $days jours';
  }

  @override
  String get propertiesDialog => 'Propriétés';

  @override
  String get fileSection => 'Fichier';

  @override
  String get filePath => 'Chemin';

  @override
  String get fileName => 'Nom du fichier';

  @override
  String get videoSection => 'Vidéo';

  @override
  String get resolution => 'Résolution';

  @override
  String get codec => 'Codec';

  @override
  String get pixelAspectRatio => 'Format de pixel';

  @override
  String get aspectRatioLabel => 'Format d\'image';

  @override
  String get durationSection => 'Durée';

  @override
  String get totalDuration => 'Durée totale';

  @override
  String get audioSection => 'Audio';

  @override
  String get trackCount => 'Nombre de pistes';

  @override
  String trackN(int index) {
    return 'Piste $index';
  }

  @override
  String get subtitleSection => 'Sous-titres';

  @override
  String get copied => 'Copié';

  @override
  String get doubleClickToCopy => 'Double-cliquez pour copier';

  @override
  String get unknown => 'Inconnu';

  @override
  String get reopen => 'Rouvrir';

  @override
  String get selectOtherFile => 'Choisir un autre fichier';

  @override
  String get retry => 'Réessayer';

  @override
  String get unmute => 'Rétablir le son';

  @override
  String get mute => 'Couper le son';

  @override
  String get volume => 'Volume';

  @override
  String volumePercent(String percent) {
    return 'Volume $percent %';
  }

  @override
  String get aspectRatioOriginal => 'Original';

  @override
  String get aspectRatioStretch => 'Étirer';

  @override
  String get aspectRatioCropFill => 'Rogner pour remplir';

  @override
  String get aspectRatioFree => 'Libre';

  @override
  String get progressBar => 'Progression de la lecture';

  @override
  String get speedDecrease => 'Ralentir';

  @override
  String get speedReset => 'Vitesse (double-cliquez pour réinitialiser)';

  @override
  String get speedIncrease => 'Accélérer';

  @override
  String get folderTab => 'Dossier';

  @override
  String get resumeAction => 'Reprendre';

  @override
  String get openFileLocation => 'Ouvrir l\'emplacement du fichier';

  @override
  String get clearHistory => 'Vider l\'historique';

  @override
  String get scanFolder => 'Analyser le dossier';

  @override
  String get noVideosInFolder => 'Aucune vidéo dans le dossier';

  @override
  String get themeMidnight => 'Minuit';

  @override
  String get themeOcean => 'Océan';

  @override
  String get themeForest => 'Forêt';

  @override
  String get version => 'Version';

  @override
  String get techStack => 'Pile technique';

  @override
  String get licenses => 'Licences';

  @override
  String get copyright => 'Construit avec Flutter + mpv_kit (libmpv)';

  @override
  String get resetShortcuts => 'Rétablir les valeurs par défaut';

  @override
  String get pressKeyToBind => 'Appuyez sur une touche…';

  @override
  String get shortcutConflict => 'Touche déjà attribuée';

  @override
  String get currentTheme => 'Thème';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Annuler';

  @override
  String get apply => 'Appliquer';

  @override
  String get playerLoadError => 'Échec du chargement du module lecteur';

  @override
  String get playerInitFailed => 'Échec de l\'initialisation du lecteur';

  @override
  String get performanceTab => 'Performance';

  @override
  String get d3d11Rendering => 'Rendu D3D11';

  @override
  String get d3d11Sync => 'Synchro CPU D3D11';

  @override
  String get d3d11SyncDesc =>
      'Synchronise le CPU et le GPU à chaque image. Désactivez pour réduire la latence; peut causer du déchirement d\'image.';

  @override
  String get decoderSettings => 'Décodeur';

  @override
  String get hardwareDecoding => 'Décodage matériel';

  @override
  String get hardwareDecodingDesc =>
      'Utilise le GPU pour décoder la vidéo. Désactivez en cas d\'artefacts visuels.';

  @override
  String get performanceHint =>
      'Les changements prendront effet à l\'ouverture du prochain fichier.';

  @override
  String get resetToDefaults => 'Rétablir les valeurs par défaut';

  @override
  String resetConfirmTitle(String tabName) {
    return 'Réinitialiser les paramètres de « $tabName »?';
  }

  @override
  String get resetConfirmMessage =>
      'Les paramètres suivants seront rétablis à leurs valeurs par défaut :';

  @override
  String get confirmReset => 'Réinitialiser';

  @override
  String get exportSettings => 'Exporter';

  @override
  String get importSettings => 'Importer';

  @override
  String get importConfirmTitle => 'Importer les paramètres?';

  @override
  String get importConfirmMessage => 'Les paramètres suivants seront écrasés :';

  @override
  String get importConfirmCategories =>
      'Lecture, Vidéo, Sous-titres, Fenêtre, Raccourcis, Thème, Langue';

  @override
  String get importSuccess => 'Paramètres importés';

  @override
  String importError(String error) {
    return 'Échec de l\'importation : $error';
  }

  @override
  String get exportError => 'Échec de l\'exportation';

  @override
  String get exportSuccess => 'Paramètres exportés';

  @override
  String importParseError(String error) {
    return 'JSON invalide : $error';
  }

  @override
  String importFileReadError(String error) {
    return 'Impossible de lire le fichier : $error';
  }

  @override
  String get openingMedia => 'Ouverture du média';

  @override
  String get bufferingMedia => 'Mise en mémoire tampon du média';

  @override
  String get errorFilePathEmpty => 'Le chemin du fichier est vide';

  @override
  String get errorFileNotFound => 'Fichier introuvable';

  @override
  String get errorFilepathTraversal => 'Chemin de fichier invalide';

  @override
  String get errorCodecUnsupportedFormat =>
      'Format multimédia non pris en charge';

  @override
  String get errorCodecDecodeFailed => 'Échec du décodage du média';

  @override
  String get errorCodecCodecUnsupported => 'Codec non pris en charge';

  @override
  String get errorPlaybackPlayFailed => 'Échec de la lecture';

  @override
  String get errorPlaybackSeekFailed => 'Échec du déplacement dans le média';

  @override
  String get errorPlaybackTextureFailed => 'Échec du rendu vidéo';

  @override
  String get errorPlaybackOpenTimeout => 'Délai d\'ouverture dépassé';

  @override
  String get errorNetworkTimeout => 'Délai d\'attente réseau dépassé';

  @override
  String get errorNetworkConnectionLost => 'Connexion perdue';

  @override
  String get errorUnknown => 'Une erreur inattendue s\'est produite';

  @override
  String errorCardBadgeLabel(int count) {
    return '$count erreurs';
  }

  @override
  String get errorCardClose => 'Fermer';

  @override
  String get errorCardCopyTooltip => 'Copier les diagnostics';

  @override
  String get errorCardCopied => 'Copié';

  @override
  String get errorCardCopiedPathInLog =>
      'Copié — chemin complet dans error.log';

  @override
  String get errorCardCopyFailed => 'Échec de la copie';

  @override
  String get errorCardOpenLogTooltip => 'Ouvrir l\'emplacement du journal';

  @override
  String get errorCardLogOpened => 'Journal ouvert';

  @override
  String get errorCardOpenLogFailed => 'Échec de l\'ouverture du journal';

  @override
  String get errorCardSectionLocation => 'Emplacement';

  @override
  String get errorCardSectionSource => 'Lignes sources';

  @override
  String get errorCardSectionStack => 'Trace d\'appels';

  @override
  String get errorCardSectionLogPath => 'Fichier journal';

  @override
  String errorCardSectionRepeats(int count) {
    return 'Répétitions : $count';
  }

  @override
  String get errorCardLogUnavailable => 'Fichier journal indisponible';

  @override
  String get errorCardLocationUnavailable => 'Emplacement indisponible';

  @override
  String get errorCardCycleTooltip => 'Passer d\'une erreur à l\'autre';

  @override
  String get errorCardToggleLabel => 'Carte d\'erreurs';

  @override
  String get languageLabel => 'Langue';

  @override
  String get languageSystem => 'Suivre le système';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChinese => '中文';

  @override
  String get batchDelete => 'Suppression par lot';

  @override
  String batchSelectedCount(int count) {
    return '$count sélectionné(s)';
  }

  @override
  String get selectAll => 'Tout sélectionner';

  @override
  String get batchDeleteConfirmTitle => 'Supprimer les vidéos sélectionnées';

  @override
  String batchDeleteConfirmBody(int count) {
    return '$count entrées vidéo seront retirées de la liste de lecture. Cette opération ne touche que la liste de lecture elle-même et ne supprimera aucun fichier de votre disque local.';
  }

  @override
  String get batchDeleteConfirmAction => 'Confirmer la suppression';

  @override
  String get playlistEntriesGone =>
      'Les entrées ne sont plus dans la liste de lecture';
}

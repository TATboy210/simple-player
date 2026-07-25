# Simple Player Flutter - Internationalization Enhancement Plan

> Created: 2026-07-20
> Branch: feat/v1.8-stability-polish-plan-02-02
> Status: Planning

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Current State Analysis](#2-current-state-analysis)
3. [Target Language Planning](#3-target-language-planning)
4. [Translation Management](#4-translation-management)
5. [Technical Implementation](#5-technical-implementation)
6. [RTL Layout Support](#6-rtl-layout-support)
7. [Formatting Support](#7-formatting-support)
8. [Testing Strategy](#8-testing-strategy)
9. [Implementation Roadmap](#9-implementation-roadmap)
10. [Tools and Resources](#10-tools-and-resources)

---

## 1. Executive Summary

### 1.1 Current State

Simple Player Flutter currently supports **2 languages** (English and Chinese Simplified)
with **178 translation keys** managed through Flutter's standard ARB + gen-l10n pipeline.
The en/zh key parity is 100%, meaning every key in the English template has a corresponding
Chinese translation. The basic i18n infrastructure is functional but limited.

### 1.2 Primary Gaps

| Gap | Severity | Description |
|-----|----------|-------------|
| Limited language coverage | HIGH | Only 2 locales; no CJK neighbors, no European languages |
| Missing zh ARB metadata | MEDIUM | `app_zh.arb` has zero `@`-description entries (178 missing) |
| Hardcoded UI strings | MEDIUM | ~5 strings in UI bypass i18n (about_tab, general_tab, title_bar) |
| No RTL support | LOW | No `Directionality` or `TextDirection` usage anywhere in codebase |
| No plural/gender support | LOW | Relative time strings use manual int interpolation, not ICU plurals |
| No locale-aware formatting | LOW | Date/number formatting not locale-sensitive |
| Language selector hardcoded | MEDIUM | `_LanguageSelector` only offers 'zh' and 'en' as chip options |

### 1.3 Target Languages

| Priority | Languages | Rationale |
|----------|-----------|-----------|
| P1 | zh-TW (繁體), ja (日本語), ko (한국어) | CJK neighbors, high desktop media player usage |
| P2 | es (Español), fr (Français), de (Deutsch), pt (Português) | Major European markets |
| P3 | ar (العربية), he (עברית) | RTL languages, layout validation |

### 1.4 Goals

- Expand from 2 to 9+ supported locales
- Achieve 100% translation coverage for all target languages
- Implement RTL layout support for Arabic and Hebrew
- Add locale-aware date/number formatting
- Establish a sustainable translation workflow
- Ensure all UI strings are externalized (zero hardcoded text)

---

## 2. Current State Analysis

### 2.1 File Structure

```
lib/l10n/
  app_en.arb                  # English template (178 keys, 178 metadata entries)
  app_zh.arb                  # Chinese translation (178 keys, 0 metadata entries)
  app_localizations.dart      # Generated abstract class + delegate (~1200 lines)
  app_localizations_en.dart   # Generated English implementation (~573 lines)
  app_localizations_zh.dart   # Generated Chinese implementation (~568 lines)
```

### 2.2 Translation Key Inventory

| Category | Count | Examples |
|----------|-------|---------|
| App chrome (title, brand) | 3 | `appTitle`, `brandName`, `emptyStateSubtitle` |
| File operations | 5 | `openFile`, `openFileTooltip`, `dragHint`, `openSubtitle`, `scanFolder` |
| Play modes | 3 | `playModeLoopAll`, `playModeLoopSingle`, `playModeShuffle` |
| Keyboard shortcuts | 13 | `shortcutPlayPause`, `shortcutSeek`, `shortcutVolume`, ... |
| Settings tabs | 8 | `generalTab`, `shortcutsTab`, `aboutTab`, `videoTab`, `performanceTab`, ... |
| Equalizer presets | 5 | `eqOff`, `eqBassBoost`, `eqVocalBoost`, `eqRock`, `eqClassical` |
| Video processing | 11 | `colorCorrection`, `brightness`, `contrast`, `saturation`, `hue`, ... |
| Playback controls | 10 | `play`, `pause`, `stop`, `rewind10`, `forward30`, `previousTrack`, `nextTrack`, ... |
| Window controls | 5 | `pin`, `unpin`, `minimize`, `maximize`, `restore` |
| Playlist/History | 14 | `playlistEmpty`, `noHistory`, `playlistTab`, `historyTab`, `clear`, `playAction`, ... |
| Relative time | 4 | `justNow`, `minutesAgo`, `hoursAgo`, `daysAgo` |
| Media info dialog | 16 | `propertiesDialog`, `fileSection`, `filePath`, `fileName`, `resolution`, `codec`, ... |
| Error messages | 16 | `errorFilePathEmpty`, `errorFileNotFound`, `errorCodecUnsupportedFormat`, ... |
| Settings import/export | 12 | `exportSettings`, `importSettings`, `importConfirmTitle`, `importSuccess`, ... |
| UI actions | 8 | `ok`, `cancel`, `apply`, `close`, `retry`, `reopen`, `selectOtherFile`, ... |
| Performance settings | 8 | `performanceTab`, `d3d11Rendering`, `d3d11Sync`, `hardwareDecoding`, ... |
| Theme/About | 9 | `themeMidnight`, `themeOcean`, `themeForest`, `version`, `techStack`, `licenses`, ... |
| Speed controls | 3 | `speedDecrease`, `speedReset`, `speedIncrease` |
| Volume controls | 4 | `unmute`, `mute`, `volume`, `volumePercent` |
| Aspect ratio | 4 | `aspectRatioOriginal`, `aspectRatioStretch`, `aspectRatioCropFill`, `aspectRatioFree` |
| **Total** | **178** | (166 simple + 12 parameterized) |

### 2.3 Parameterized Keys (12 total)

These keys accept runtime parameters via ICU `{placeholder}` syntax:

| Key | Parameter | Type | Usage |
|-----|-----------|------|-------|
| `audioTrackN` | `{index}` | `int` | Audio track label with index |
| `trackN` | `{index}` | `int` | Track label in properties |
| `breakpointAt` | `{time}` | `String` | Breakpoint timestamp display |
| `lastPlayedAt` | `{time}` | `String` | Last played position tooltip |
| `minutesAgo` | `{minutes}` | `int` | Relative time display |
| `hoursAgo` | `{hours}` | `int` | Relative time display |
| `daysAgo` | `{days}` | `int` | Relative time display |
| `volumePercent` | `{percent}` | `String` | OSD volume percentage |
| `resetConfirmTitle` | `{tabName}` | `String` | Reset dialog title |
| `importError` | `{error}` | `String` | Import error message |
| `importParseError` | `{error}` | `String` | JSON parse error |
| `importFileReadError` | `{error}` | `String` | File read error |

### 2.4 Configuration (l10n.yaml)

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
preferred-supported-locales: ["en"]
nullable-getter: false
```

Notable: `synthetic-package: false` is NOT set, meaning generated code goes to
`.dart_tool/flutter_gen/gen_l10n/` by default (standard Flutter behavior).
The `lib/l10n/` directory contains both source ARBs and the generated Dart files,
which suggests manual copy or a custom output-dir was used at some point.

### 2.5 Integration Points

- **`app.dart`**: Uses `AppLocalizations.localizationsDelegates` and `AppLocalizations.supportedLocales`
- **`general_tab.dart`**: Language selector with hardcoded `'zh'` / `'en'` chip options
- **`about_tab.dart`**: Hardcoded `'Simple Player'` and `'Flutter + fvp'` strings
- **`custom_title_bar.dart`**: Hardcoded `'Simple Player'` window title
- **69 call sites** across the codebase use `AppLocalizations.of(context)` or `.of(context)`

### 2.6 Identified Hardcoded Strings

These strings bypass the i18n system and must be externalized:

| File | Line | String | Fix |
|------|------|--------|-----|
| `ui/dialogs/settings/about_tab.dart` | 43 | `'Flutter + fvp'` | Add ARB key `techStackValue` |
| `ui/dialogs/settings/about_tab.dart` | 87 | `applicationName: 'Simple Player'` | Use `AppLocalizations.of(context).appTitle` |
| `ui/dialogs/settings/general_tab.dart` | 110 | `label: 'English'` | Add ARB keys for language display names |
| `ui/window/custom_title_bar.dart` | 51 | `'Simple Player'` | Use `AppLocalizations.of(context).appTitle` |
| `ui/dialogs/settings/video_tab.dart` | 272 | `'$deg°'` | Minor — degree symbol is locale-neutral |

---

## 3. Target Language Planning

### 3.1 Priority 1: CJK Neighbors (Phase 1)

These languages share similar UI density characteristics with Chinese and are
high-usage markets for desktop media players.

#### 3.1.1 Traditional Chinese (zh-TW)

| Property | Value |
|----------|-------|
| Locale code | `zh-TW` (fallback: `zh`) |
| Script | Traditional Chinese (繁體中文) |
| UI density | Similar to zh-CN (slightly longer in some cases) |
| Key differences from zh-CN | 繁體字形, Taiwan-specific terminology (設定 vs 设置, 檔案 vs 文件) |
| Estimated effort | 2-3 hours (many strings are identical or near-identical) |
| Native speaker review | Required for Taiwan-specific terms |

**Term mapping examples:**

| EN | zh-CN (current) | zh-TW (proposed) |
|----|-----------------|------------------|
| Settings | 设置 | 設定 |
| File | 文件 | 檔案 |
| Playlist | 播放列表 | 播放清單 |
| History | 播放歷史 | 播放記錄 |
| Codec | 編碼 | 編解碼器 |
| Resolution | 分辨率 | 解析度 |
| Equalizer | 均衡器 | 等化器 |
| Deinterlace | 去隔行 | 去交錯 |

#### 3.1.2 Japanese (ja)

| Property | Value |
|----------|-------|
| Locale code | `ja` |
| Script | Mixed (Kanji + Hiragana + Katakana) |
| UI density | ~1.3x English length for most strings |
| Writing considerations | Katakana for loanwords (プレイヤー, サブタイトル), Kanji for native terms |
| Estimated effort | 4-6 hours |
| Native speaker review | Required |

**Key translation considerations:**
- Use polite form (です/ます) for user-facing text
- Katakana for technical loanwords: プレイヤー (player), サブタイトル (subtitle)
- UI strings are generally shorter than English due to Kanji efficiency
- Honorific particles and sentence-ending particles affect string length

#### 3.1.3 Korean (ko)

| Property | Value |
|----------|-------|
| Locale code | `ko` |
| Script | Hangul (한글) |
| UI density | ~1.2x English length |
| Writing considerations | Pure Hangul for native terms, Hangul transliteration for loanwords |
| Estimated effort | 4-6 hours |
| Native speaker review | Required |

**Key translation considerations:**
- Sentence structure (SOV) affects parameterized string templates
- Formal/polite style (합니다/합쇼체) for UI text
- Loanwords written in Hangul: 플레이어 (player), 자막 (subtitle)

### 3.2 Priority 2: European Languages (Phase 2)

These languages use Latin script but have different UI density and
grammatical characteristics.

#### 3.2.1 Spanish (es)

| Property | Value |
|----------|-------|
| Locale code | `es` |
| UI density | ~1.2-1.5x English (Spanish text is generally longer) |
| Considerations | Gendered articles (el/la), formal usted vs informal tú |
| Estimated effort | 3-4 hours |
| Variants | es-ES (Spain), es-MX (Mexico), es-419 (Latin America) — start with es-ES |

#### 3.2.2 French (fr)

| Property | Value |
|----------|-------|
| Locale code | `fr` |
| UI density | ~1.3-1.5x English |
| Considerations | Gendered nouns, accent characters (é, è, ê, ç), non-breaking spaces before :;!? |
| Estimated effort | 3-4 hours |

#### 3.2.3 German (de)

| Property | Value |
|----------|-------|
| Locale code | `de` |
| UI density | ~1.3-1.6x English (compound words can be very long) |
| Considerations | Compound nouns (Wiedergabeliste = Playlist), formal Sie |
| Estimated effort | 3-4 hours |
| UI risk | Long compound words may overflow UI containers |

#### 3.2.4 Portuguese (pt-BR)

| Property | Value |
|----------|-------|
| Locale code | `pt-BR` (Brazilian Portuguese — larger market) |
| UI density | ~1.2-1.4x English |
| Considerations | Gendered articles, different from pt-PT in vocabulary |
| Estimated effort | 3-4 hours |

### 3.3 Priority 3: RTL Languages (Phase 3)

These languages require significant layout changes due to right-to-left text direction.

#### 3.3.1 Arabic (ar)

| Property | Value |
|----------|-------|
| Locale code | `ar` |
| Script | Arabic (right-to-left) |
| UI density | ~0.8-1.0x English (Arabic is often more concise) |
| Considerations | Full RTL layout, connected letter forms, no uppercase/lowercase |
| Estimated effort | 6-8 hours (translation) + 20-30 hours (RTL layout) |
| UI impact | Entire layout mirroring, progress bar direction, icon flipping |

#### 3.3.2 Hebrew (he)

| Property | Value |
|----------|-------|
| Locale code | `he` |
| Script | Hebrew (right-to-left) |
| UI density | ~0.9-1.1x English |
| Considerations | RTL layout, no vowels in standard text |
| Estimated effort | 4-6 hours (translation) + 20-30 hours (RTL layout, shared with ar) |

### 3.4 Future Consideration

| Language | Locale | Notes |
|----------|--------|-------|
| Italian | `it` | Similar to es/fr in effort |
| Russian | `ru` | Cyrillic script, longer strings |
| Thai | `th` | No word spacing, complex rendering |
| Vietnamese | `vi` | Latin script with diacritics, very long strings |
| Turkish | `tr` | Latin script, locale-sensitive case conversion (dotless i) |

---

## 4. Translation Management

### 4.1 Translation Workflow

```
                    ┌─────────────────────┐
                    │  Developer adds new  │
                    │  key to app_en.arb   │
                    └──────────┬──────────┘
                               │
                    ┌──────────▼──────────┐
                    │  CI checks key      │
                    │  parity across all  │
                    │  ARB files          │
                    └──────────┬──────────┘
                               │
              ┌────────────────┼────────────────┐
              │                │                │
    ┌─────────▼─────────┐ ┌───▼────────┐ ┌─────▼───────┐
    │  Machine translate │ │  Community │ │  Professional│
    │  (first draft)     │ │  review    │ │  translation │
    └─────────┬─────────┘ └───┬────────┘ └─────┬───────┘
              │                │                │
              └────────────────┼────────────────┘
                               │
                    ┌──────────▼──────────┐
                    │  Native speaker     │
                    │  review & approve   │
                    └──────────┬──────────┘
                               │
                    ┌──────────▼──────────┐
                    │  Merge to ARB file  │
                    │  Run gen_l10n       │
                    └──────────┬──────────┘
                               │
                    ┌──────────▼──────────┐
                    │  Visual QA in app   │
                    └─────────────────────┘
```

### 4.2 Translation Quality Standards

#### 4.2.1 Consistency Rules

| Rule | Description | Example |
|------|-------------|---------|
| Terminology consistency | Same English term must map to same target term everywhere | "Playlist" always = "播放列表" (zh), never mix with "播放清单" |
| Parameter preservation | All `{placeholders}` must be preserved exactly | `"Volume {percent}%"` → `"音量 {percent}%"` |
| Tone consistency | All strings in same locale use same formality level | Japanese: all です/ます form |
| Length constraints | UI strings should fit within their containers | German compound words may need abbreviation |
| Context awareness | Same English word may need different translations by context | "Play" (button) vs "Play" (action) — zh: both "播放" is OK |

#### 4.2.2 Quality Checklist per Locale

- [ ] All 178 keys translated
- [ ] All 12 parameterized keys tested with sample values
- [ ] No untranslated English strings remaining
- [ ] Terminology glossary created and followed
- [ ] UI text fits within containers (no overflow)
- [ ] Special characters render correctly
- [ ] Formal/informal register is consistent
- [ ] Native speaker has reviewed all strings

### 4.3 ARB Metadata Strategy

Currently `app_zh.arb` has zero metadata entries. All ARB files should include
`@`-description entries for translator context. Two approaches:

**Option A: Copy metadata from template (Recommended)**
- Copy all `@key` entries from `app_en.arb` to each locale ARB
- Pros: Translators see context descriptions in their working file
- Cons: Slightly larger files, metadata is in English

**Option B: External context document**
- Keep metadata only in template ARB
- Provide a separate translator guide with context
- Pros: Smaller locale ARBs
- Cons: Translators must cross-reference

**Decision: Option A** — Copy metadata to all ARB files. The context descriptions
are essential for accurate translation and the file size overhead is negligible.

### 4.4 Terminology Glossary

Maintain a shared glossary per locale to ensure consistency:

```markdown
# Japanese Terminology Glossary

| English | Japanese | Notes |
|---------|----------|-------|
| Player | プレイヤー | Katakana loanword |
| Playlist | 再生リスト | Native Japanese, not プレイリスト |
| Subtitle | 字幕 | Kanji |
| Codec | コーデック | Katakana loanword |
| Fullscreen | フルスクリーン | Katakana, or 全画面表示 |
| Settings | 設定 | Kanji |
| Equalizer | イコライザー | Katakana loanword |
| Playback | 再生 | Kanji |
| Track | トラック | Katakana loanword |
| Volume | 音量 | Kanji |
| Mute | ミュート | Katakana loanword |
| Shuffle | シャッフル | Katakana loanword |
```

---

## 5. Technical Implementation

### 5.1 ARB File Management

#### 5.1.1 File Naming Convention

Follow Flutter's standard locale naming:

```
lib/l10n/
  app_en.arb          # English (template)
  app_zh.arb          # Chinese Simplified
  app_zh_TW.arb       # Chinese Traditional (Taiwan)
  app_ja.arb          # Japanese
  app_ko.arb          # Korean
  app_es.arb          # Spanish
  app_fr.arb          # French
  app_de.arb          # German
  app_pt_BR.arb       # Portuguese (Brazil)
  app_ar.arb          # Arabic
  app_he.arb          # Hebrew
```

#### 5.1.2 l10n.yaml Configuration Updates

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
preferred-supported-locales: ["en"]
nullable-getter: false
# New additions:
synthetic-package: false          # Generate into lib/l10n/ directly
output-dir: lib/l10n              # Explicit output directory
```

#### 5.1.3 ARB File Template for New Locales

Each new locale ARB file must:
1. Set `"@@locale": "<locale_code>"` as the first entry
2. Include all `@key` metadata entries (copied from template)
3. Provide translations for all 178 keys
4. Preserve all `{placeholder}` syntax exactly

### 5.2 Code Generation

#### 5.2.1 Generated File Structure

After adding all locales, `flutter gen-l10n` will generate:

```
lib/l10n/
  app_localizations.dart          # Abstract class + delegate (auto-updated)
  app_localizations_en.dart       # English implementation
  app_localizations_zh.dart       # Chinese Simplified
  app_localizations_zh_TW.dart    # Chinese Traditional
  app_localizations_ja.dart       # Japanese
  app_localizations_ko.dart       # Korean
  app_localizations_es.dart       # Spanish
  app_localizations_fr.dart       # French
  app_localizations_de.dart       # German
  app_localizations_pt_BR.dart    # Portuguese (Brazil)
  app_localizations_ar.dart       # Arabic
  app_localizations_he.dart       # Hebrew
```

The `AppLocalizations.supportedLocales` list and `lookupAppLocalizations()`
switch statement will be auto-regenerated.

#### 5.2.2 Build Integration

Add to CI pipeline:

```bash
# Verify ARB key parity
flutter gen-l10n --arb-dir=lib/l10n --template-arb-file=app_en.arb

# Verify no missing translations
dart run arb_tool:check_missing --dir=lib/l10n
```

### 5.3 Runtime Support

#### 5.3.1 Locale Resolution Strategy

Update `app.dart` to use a cascading locale resolution:

```dart
MaterialApp(
  locale: currentLocale,  // From settings
  localeResolutionCallback: (locale, supportedLocales) {
    // 1. Exact match (e.g., zh-TW)
    for (final supported in supportedLocales) {
      if (supported.languageCode == locale?.languageCode &&
          supported.countryCode == locale?.countryCode) {
        return supported;
      }
    }
    // 2. Language-only match (e.g., zh → zh)
    for (final supported in supportedLocales) {
      if (supported.languageCode == locale?.languageCode) {
        return supported;
      }
    }
    // 3. Fallback to English
    return supportedLocales.first;
  },
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
)
```

#### 5.3.2 Dynamic Language Selector

Replace the hardcoded `_LanguageSelector` chips with a data-driven approach:

```dart
/// Language option with display name in both English and native script.
class LanguageOption {
  const LanguageOption({
    required this.locale,
    required this.nameEn,
    required this.nameNative,
  });

  final Locale locale;
  final String nameEn;
  final String nameNative;
}

/// All supported languages with display metadata.
const supportedLanguages = [
  LanguageOption(locale: Locale('en'), nameEn: 'English', nameNative: 'English'),
  LanguageOption(locale: Locale('zh'), nameEn: 'Chinese Simplified', nameNative: '简体中文'),
  LanguageOption(Locale('zh', 'TW'), 'Chinese Traditional', '繁體中文'),
  LanguageOption(Locale('ja'), 'Japanese', '日本語'),
  LanguageOption(Locale('ko'), 'Korean', '한국어'),
  LanguageOption(Locale('es'), 'Spanish', 'Español'),
  LanguageOption(Locale('fr'), 'French', 'Français'),
  LanguageOption(Locale('de'), 'German', 'Deutsch'),
  LanguageOption(Locale('pt', 'BR'), 'Portuguese (Brazil)', 'Português (Brasil)'),
  LanguageOption(Locale('ar'), 'Arabic', 'العربية'),
  LanguageOption(Locale('he'), 'Hebrew', 'עברית'),
];
```

#### 5.3.3 Hardcoded String Externalization

| File | Current | Fix |
|------|---------|-----|
| `about_tab.dart:43` | `'Flutter + fvp'` | New key: `techStackValue` = `"Flutter + fvp"` / `"Flutter + fvp"` |
| `about_tab.dart:87` | `applicationName: 'Simple Player'` | `AppLocalizations.of(context).appTitle` |
| `general_tab.dart:110` | `label: 'English'` | Use `nameNative` from `LanguageOption` |
| `custom_title_bar.dart:51` | `'Simple Player'` | `AppLocalizations.of(context).appTitle` |

### 5.4 New ARB Keys Required

Add these keys to support the enhanced language selector and missing externalizations:

```json
{
  "languageEn": "English",
  "@languageEn": { "description": "Language name in English for selector" },
  "languageZh": "简体中文",
  "@languageZh": { "description": "Language name in Chinese Simplified for selector" },
  "languageZhTw": "繁體中文",
  "@languageZhTw": { "description": "Language name in Chinese Traditional for selector" },
  "languageJa": "日本語",
  "@languageJa": { "description": "Language name in Japanese for selector" },
  "languageKo": "한국어",
  "@languageKo": { "description": "Language name in Korean for selector" },
  "languageEs": "Español",
  "@languageEs": { "description": "Language name in Spanish for selector" },
  "languageFr": "Français",
  "@languageFr": { "description": "Language name in French for selector" },
  "languageDe": "Deutsch",
  "@languageDe": { "description": "Language name in German for selector" },
  "languagePtBr": "Português (Brasil)",
  "@languagePtBr": { "description": "Language name in Portuguese (Brazil) for selector" },
  "languageAr": "العربية",
  "@languageAr": { "description": "Language name in Arabic for selector" },
  "languageHe": "עברית",
  "@languageHe": { "description": "Language name in Hebrew for selector" }
}
```

**Decision: Language names are NOT translated** — each language name is always
displayed in its native script regardless of current locale (e.g., "日本語" is
always "日本語", never "Japanese" when viewing in English). This is the standard
UX pattern for language selectors.

---

## 6. RTL Layout Support

### 6.1 Scope Assessment

RTL (Right-to-Left) support affects the entire UI layer. Flutter's
`Directionality` widget and `TextDirection` handle most text layout automatically,
but custom layouts, icons, and animations need manual attention.

### 6.2 Components Requiring RTL Adaptation

| Component | File | RTL Impact | Fix Strategy |
|-----------|------|------------|--------------|
| Progress bar | `progress_bar.dart` | Seek direction reversed | Mirror using `Directionality` or conditional `Alignment` |
| Control bar | `control_bar.dart` | Button order mirrored | Flutter auto-mirrors `Row` in RTL context |
| Playlist panel | `playlist_panel.dart` | Slide direction, scroll direction | Use `AnimatedSlide` with locale-aware offset |
| Settings dialog | `settings_dialog.dart` | Tab order, form layout | Flutter auto-mirrors, verify manually |
| Context menu | (PopupMenu) | Menu item order | Flutter auto-mirrors `PopupMenuItem` |
| Title bar | `custom_title_bar.dart` | Button order (close/min/max) | Windows convention: always right-side, no mirror |
| Volume slider | `volume_controls.dart` | Slider direction | Flutter auto-mirrors `Slider` in RTL |
| Speed button | `speed_button.dart` | Popup direction | Use `Directionality`-aware positioning |
| OSD overlay | `osd_overlay.dart` | Text alignment | Flutter auto-mirrors `Text` alignment |
| Keyboard handler | `keyboard_handler.dart` | Left/Right arrow semantics | Keep physical keys, no change needed |
| Drop handler | `drop_handler.dart` | No text, no impact | No change needed |
| Video surface | `video_surface.dart` | No text, no impact | No change needed |

### 6.3 Implementation Approach

#### 6.3.1 Automatic Mirroring

Flutter automatically mirrors these widgets in RTL context:
- `Row`, `Column`, `Flex` children order
- `Text` alignment
- `ListView` scroll direction
- `Padding` (start/end vs left/right)
- `EdgeInsetsDirectional`

**Action:** Audit all `EdgeInsets.only(left: ...)` / `EdgeInsets.only(right: ...)`
and replace with `EdgeInsetsDirectional.only(start: ...)` / `EdgeInsetsDirectional.only(end: ...)`.

#### 6.3.2 Manual Mirroring Required

Some elements must NOT be mirrored:
- **Video surface**: Always LTR (video content is not affected by UI locale)
- **Title bar buttons** (Windows): Close/Min/Max stay on the right per platform convention
- **Keyboard shortcuts**: Physical Left/Right arrows keep their meaning
- **Progress bar seek direction**: Debate — most players keep LTR for media progress

**Decision: Progress bar stays LTR** — media progress is universal (left=start,
right=end) regardless of text direction. This matches VLC, mpv, and most players.

#### 6.3.3 Icon Mirroring

Some icons should be mirrored in RTL:
- **Back/Forward arrows**: `<` becomes `>`, `>` becomes `<`
- **Skip forward/backward**: Mirror the icon
- **Playlist expand/collapse**: Mirror the chevron

Flutter's `Icon` widget supports `textDirection` parameter for automatic mirroring.
Use `Icons.arrow_back` (auto-mirrors) instead of `Icons.arrow_left` (fixed).

### 6.4 RTL Testing Checklist

- [ ] All text renders right-aligned
- [ ] Control bar buttons mirror correctly
- [ ] Playlist panel slides from correct side
- [ ] Settings dialog tabs are in correct order
- [ ] Progress bar displays correctly (keep LTR)
- [ ] Context menus appear in correct position
- [ ] No layout overflow from longer RTL strings
- [ ] Mixed LTR/RTL text (e.g., file paths) renders correctly
- [ ] Video surface is unaffected by RTL toggle

---

## 7. Formatting Support

### 7.1 Current State

The codebase uses basic string interpolation for all formatted values:
- Time: `'$hours hr ago'` (manual)
- Volume: `'Volume $percent%'` (manual)
- Track index: `'Track $index'` (manual)

No locale-aware formatting is used (no `DateFormat`, `NumberFormat`, etc.).

### 7.2 Date/Time Formatting

#### 7.2.1 Relative Time (Current: Manual Interpolation)

Current implementation manually handles singular/plural:

```dart
// Current (app_en.arb)
"minutesAgo": "{minutes} min ago",
"hoursAgo": "{hours} hr ago",
"daysAgo": "{days} days ago",
```

**Recommended: Use ICU plurals** for proper pluralization:

```json
// Enhanced app_en.arb with ICU plurals
"minutesAgo": "{minutes,plural, =0{just now} =1{1 minute ago} other{{minutes} minutes ago}}",
"hoursAgo": "{hours,plural, =0{just now} =1{1 hour ago} other{{hours} hours ago}}",
"daysAgo": "{days,plural, =0{today} =1{1 day ago} other{{days} days ago}}",
```

**Note:** ICU plurals require changing the Dart method signature from `int` to
`num` and using `Intl.plural()`. This is a breaking change to the generated API.

**Decision: Defer ICU plurals to Phase 2** — the current manual approach works
acceptably for all target languages. Japanese and Korean do not have plural
forms (same string for all counts). European languages do need proper plurals,
so this becomes necessary for Phase 2.

#### 7.2.2 Absolute Date/Time (New Feature)

If playback history shows absolute timestamps, use `DateFormat`:

```dart
import 'package:intl/intl.dart';

// Locale-aware date formatting
final formatter = DateFormat.yMMMd(locale);  // "Jan 1, 2026" / "2026年1月1日"
final timeFormatter = DateFormat.Hm(locale);  // "14:30" / "下午2:30"
```

### 7.3 Number Formatting

#### 7.3.1 Current Usage

- Volume percentage: `"Volume {percent}%"` — displayed as integer string
- Track index: `"Track {index}"` — displayed as integer

#### 7.3.2 Locale-Aware Numbers

For locales that use different digit grouping:

```dart
import 'package:intl/intl.dart';

// Locale-aware number formatting
final formatter = NumberFormat('#,###', locale);
formatter.format(1234567);  // "1,234,567" (en) / "1.234.567" (de) / "١٬٢٣٤٬٥٦٧" (ar)
```

**Decision: Defer number formatting** — the player only displays small integers
(track indices, volume percentages) where locale-aware formatting adds no value.
Revisit if the app ever displays large numbers (file sizes, etc.).

### 7.4 Text Direction Formatting

For mixed LTR/RTL content (e.g., file paths containing both Latin and Arabic
characters), use Unicode bidi markers:

```dart
// Force LTR for file paths in RTL context
String formatFilePath(String path, TextDirection direction) {
  if (direction == TextDirection.rtl) {
    return '‎$path‏';  // LTR mark + path + RTL mark
  }
  return path;
}
```

---

## 8. Testing Strategy

### 8.1 Translation Tests

#### 8.1.1 Key Parity Test (Automated)

```dart
// test/l10n/translation_parity_test.dart
void main() {
  test('all locale ARBs have same keys as template', () {
    final template = loadArb('app_en.arb');
    final templateKeys = template.keys.where((k) => !k.startsWith('@')).toSet();

    for (final locale in ['zh', 'zh_TW', 'ja', 'ko', 'es', 'fr', 'de', 'pt_BR', 'ar', 'he']) {
      final arb = loadArb('app_$locale.arb');
      final keys = arb.keys.where((k) => !k.startsWith('@')).toSet();

      final missing = templateKeys.difference(keys);
      final extra = keys.difference(templateKeys);

      expect(missing, isEmpty, reason: '$locale missing keys: $missing');
      expect(extra, isEmpty, reason: '$locale has extra keys: $extra');
    }
  });
}
```

#### 8.1.2 Placeholder Preservation Test (Automated)

```dart
test('all parameterized keys preserve placeholders', () {
  final template = loadArb('app_en.arb');
  final paramKeys = template.entries
      .where((e) => !e.key.startsWith('@') && e.value.contains('{'))
      .toList();

  for (final locale in allLocales) {
    final arb = loadArb('app_$locale.arb');
    for (final entry in paramKeys) {
      final templatePlaceholders = extractPlaceholders(entry.value);
      final localePlaceholders = extractPlaceholders(arb[entry.key]!);
      expect(localePlaceholders, equals(templatePlaceholders),
        reason: '${entry.key} in $locale has different placeholders');
    }
  }
});
```

#### 8.1.3 Metadata Completeness Test (Automated)

```dart
test('all locale ARBs have metadata for every key', () {
  for (final locale in allLocales) {
    final arb = loadArb('app_$locale.arb');
    final keys = arb.keys.where((k) => !k.startsWith('@')).toSet();
    final metaKeys = arb.keys.where((k) => k.startsWith('@') && k != '@@locale').toSet();

    final missingMeta = keys.where((k) => !metaKeys.contains('@$k')).toSet();
    expect(missingMeta, isEmpty,
      reason: '$locale missing metadata for: $missingMeta');
  }
});
```

### 8.2 Layout Tests

#### 8.2.1 Widget Tests for RTL

```dart
testWidgets('control bar mirrors in RTL locale', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ar'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const ControlBar(/* ... */),
    ),
  );

  // Verify button order is mirrored
  final buttons = tester.widgetList<IconButton>(find.byType(IconButton));
  // First button should be rightmost in RTL
  // ...
});

testWidgets('progress bar stays LTR in RTL locale', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ar'),
      // ...
      home: const ProgressBar(/* ... */),
    ),
  );

  // Verify progress bar direction is NOT mirrored
  // ...
});
```

#### 8.2.2 Visual Regression Tests

For each locale, capture screenshots of key screens:
1. Empty state (brand name + subtitle)
2. Playback state (controls visible)
3. Settings dialog (all tabs)
4. Playlist panel (both tabs)
5. Error state (error banner)
6. Context menu

### 8.3 String Length Stress Tests

```dart
testWidgets('German compound words do not overflow', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('de'),
      // ...
      home: const SettingsPanel(/* ... */),
    ),
  );

  // Check for overflow errors
  expect(tester.takeException(), isNull);
});
```

### 8.4 Fallback Tests

```dart
testWidgets('unsupported locale falls back to English', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('xx'),  // Unsupported
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          expect(l10n.localeName, 'en');
          return const SizedBox();
        },
      ),
    ),
  );
});
```

---

## 9. Implementation Roadmap

### Phase 1: Foundation + CJK Expansion (Weeks 1-2)

**Goal:** Expand to 5 languages, fix infrastructure gaps.

| Task | Effort | Priority | Dependencies |
|------|--------|----------|-------------|
| Add metadata to `app_zh.arb` | 1h | P0 | None |
| Externalize hardcoded strings (5 items) | 2h | P0 | None |
| Create `app_zh_TW.arb` (Traditional Chinese) | 3h | P1 | Metadata fix |
| Create `app_ja.arb` (Japanese) | 5h | P1 | Metadata fix |
| Create `app_ko.arb` (Korean) | 5h | P1 | Metadata fix |
| Add new ARB keys for language selector | 1h | P1 | None |
| Update `_LanguageSelector` to be data-driven | 3h | P1 | New ARB keys |
| Update `l10n.yaml` configuration | 0.5h | P1 | None |
| Update `app.dart` locale resolution | 1h | P1 | None |
| Add key parity + placeholder tests | 2h | P1 | All ARB files |
| Native speaker review (zh-TW, ja, ko) | 4h | P1 | Draft translations |
| Visual QA for 5 locales | 2h | P1 | All translations |

**Total Phase 1: ~30 hours**

**Deliverables:**
- 5 supported locales (en, zh, zh-TW, ja, ko)
- All hardcoded strings externalized
- Data-driven language selector
- Automated translation tests

### Phase 2: European Languages + Formatting (Weeks 3-4)

**Goal:** Add 4 European languages, improve formatting.

| Task | Effort | Priority | Dependencies |
|------|--------|----------|-------------|
| Create `app_es.arb` (Spanish) | 4h | P2 | Phase 1 complete |
| Create `app_fr.arb` (French) | 4h | P2 | Phase 1 complete |
| Create `app_de.arb` (German) | 4h | P2 | Phase 1 complete |
| Create `app_pt_BR.arb` (Portuguese) | 4h | P2 | Phase 1 complete |
| German UI overflow testing + fixes | 4h | P2 | German ARB |
| Implement ICU plurals for relative time | 4h | P2 | All ARB files |
| Add `DateFormat` for absolute timestamps | 2h | P2 | If needed |
| Native speaker review (es, fr, de, pt) | 6h | P2 | Draft translations |
| Visual QA for 9 locales | 3h | P2 | All translations |
| String length stress tests | 2h | P2 | All ARB files |

**Total Phase 2: ~37 hours**

**Deliverables:**
- 9 supported locales
- ICU plural support
- German compound word overflow fixes
- Locale-aware date formatting

### Phase 3: RTL Support + Polish (Weeks 5-8)

**Goal:** Add Arabic/Hebrew with full RTL layout support.

| Task | Effort | Priority | Dependencies |
|------|--------|----------|-------------|
| Audit all `EdgeInsets` for directional variants | 4h | P3 | Phase 2 complete |
| Audit all icon usage for mirroring candidates | 2h | P3 | Phase 2 complete |
| Implement RTL-aware progress bar | 3h | P3 | Audit complete |
| Implement RTL-aware playlist panel | 4h | P3 | Audit complete |
| Implement RTL-aware control bar | 3h | P3 | Audit complete |
| Create `app_ar.arb` (Arabic) | 6h | P3 | RTL layout ready |
| Create `app_he.arb` (Hebrew) | 5h | P3 | RTL layout ready |
| Mixed bidi text handling (file paths) | 3h | P3 | RTL layout ready |
| Native speaker review (ar, he) | 4h | P3 | Draft translations |
| RTL visual regression tests | 4h | P3 | All RTL code |
| Full visual QA for 11 locales | 4h | P3 | Everything |
| Accessibility audit for all locales | 3h | P3 | Everything |

**Total Phase 3: ~45 hours**

**Deliverables:**
- 11 supported locales (including 2 RTL)
- Full RTL layout support
- Bidi text handling
- Comprehensive visual regression tests

### Summary Timeline

```
Week 1-2:  Phase 1 — Foundation + CJK (en, zh, zh-TW, ja, ko)
Week 3-4:  Phase 2 — European (es, fr, de, pt-BR) + Formatting
Week 5-8:  Phase 3 — RTL (ar, he) + Layout Mirroring + Polish

Total: ~112 hours across 8 weeks
Final: 11 locales, full RTL support, ICU plurals, locale-aware formatting
```

---

## 10. Tools and Resources

### 10.1 Translation Tools

| Tool | Type | Use Case |
|------|------|----------|
| **Google Translate API** | Machine | First draft translations for all languages |
| **DeepL API** | Machine | Higher quality for European languages (es, fr, de, pt) |
| **ChatGPT / Claude** | AI | Context-aware translation with glossary enforcement |
| **Weblate** | Platform | Open-source translation management (self-hosted or cloud) |
| **Crowdin** | Platform | Commercial TMS with ARB support and GitHub integration |
| **POEditor** | Platform | Free tier available, supports ARB format |

### 10.2 Flutter i18n Tools

| Tool | Purpose | Command |
|------|---------|---------|
| `flutter gen-l10n` | Code generation from ARB files | `flutter gen-l10n` |
| `intl_utils` | CLI tool for ARB management | `dart run intl_utils:generate` |
| `arb_utils` | ARB file validation and manipulation | `dart run arb_utils:validate` |
| `flutter_localizations` | Built-in Material/Cupertino i18n | Already in pubspec.yaml |

### 10.3 Testing Tools

| Tool | Purpose |
|------|---------|
| `flutter_test` | Widget tests for RTL layout |
| `golden_toolkit` | Screenshot-based visual regression tests |
| `patrol` | Integration tests for locale switching |
| Custom ARB validator | Key parity + placeholder preservation tests |

### 10.4 Reference Material

| Resource | URL | Use Case |
|----------|-----|----------|
| ICU MessageFormat spec | unicode.org/reports/tr35 | Plural/gender/select syntax |
| Flutter i18n guide | docs.flutter.dev/ui/accessibility-and-internationalization/internationalization | Official guide |
| Material Design i18n | m3.material.io/foundations/layout/understanding-layout/overview | Layout mirroring guidelines |
| CLDR data | unicode.org/cldr | Locale-specific formatting rules |
| Unicode bidi algorithm | unicode.org/reports/tr9 | RTL text rendering |

### 10.5 ARB Validation Script

Create a CI script to validate ARB files on every commit:

```bash
#!/bin/bash
# scripts/validate_arbs.sh

TEMPLATE="lib/l10n/app_en.arb"
ERRORS=0

# Extract template keys
TEMPLATE_KEYS=$(python3 -c "
import json, sys
with open('$TEMPLATE') as f:
    data = json.load(f)
keys = sorted(k for k in data if not k.startswith('@'))
print('\n'.join(keys))
")

# Check each locale ARB
for arb in lib/l10n/app_*.arb; do
  [ "$arb" = "$TEMPLATE" ] && continue

  LOCALE=$(basename "$arb" .arb | sed 's/app_//')
  LOCALE_KEYS=$(python3 -c "
import json
with open('$arb') as f:
    data = json.load(f)
keys = sorted(k for k in data if not k.startswith('@'))
print('\n'.join(keys))
")

  # Check for missing keys
  MISSING=$(comm -23 <(echo "$TEMPLATE_KEYS") <(echo "$LOCALE_KEYS"))
  if [ -n "$MISSING" ]; then
    echo "ERROR: $LOCALE missing keys: $MISSING"
    ERRORS=$((ERRORS + 1))
  fi

  # Check for extra keys
  EXTRA=$(comm -13 <(echo "$TEMPLATE_KEYS") <(echo "$LOCALE_KEYS"))
  if [ -n "$EXTRA" ]; then
    echo "WARNING: $LOCALE has extra keys: $EXTRA"
  fi
done

if [ $ERRORS -gt 0 ]; then
  echo "FAILED: $ERRORS locale(s) have missing translations"
  exit 1
fi

echo "All ARB files are valid and complete"
```

---

## Appendix A: Translation Priority Matrix

| Key Category | Count | P1 (CJK) | P2 (EU) | P3 (RTL) | Notes |
|-------------|-------|----------|---------|----------|-------|
| App chrome | 3 | Yes | Yes | Yes | Brand name stays English |
| File operations | 5 | Yes | Yes | Yes | |
| Play modes | 3 | Yes | Yes | Yes | |
| Keyboard shortcuts | 13 | Yes | Yes | Yes | Key names stay English |
| Settings tabs | 8 | Yes | Yes | Yes | |
| Equalizer presets | 5 | Yes | Yes | Yes | |
| Video processing | 11 | Yes | Yes | Yes | |
| Playback controls | 10 | Yes | Yes | Yes | |
| Window controls | 5 | Yes | Yes | Yes | |
| Playlist/History | 14 | Yes | Yes | Yes | |
| Relative time | 4 | Yes | Yes | Yes | Needs ICU plurals for EU |
| Media info dialog | 16 | Yes | Yes | Yes | |
| Error messages | 16 | Yes | Yes | Yes | |
| Settings import/export | 12 | Yes | Yes | Yes | |
| UI actions | 8 | Yes | Yes | Yes | |
| Performance settings | 8 | Yes | Yes | Yes | |
| Theme/About | 9 | Yes | Yes | Yes | |
| Speed controls | 3 | Yes | Yes | Yes | |
| Volume controls | 4 | Yes | Yes | Yes | |
| Aspect ratio | 4 | Yes | Yes | Yes | |
| **Total** | **178** | **178** | **178** | **178** | 100% coverage target |

## Appendix B: String Length Multipliers

Estimated string length relative to English (for UI overflow risk assessment):

| Language | Multiplier | Risk Level | Affected Components |
|----------|-----------|------------|---------------------|
| en | 1.0x | Baseline | — |
| zh | 0.6-0.8x | Low (shorter) | — |
| zh-TW | 0.6-0.8x | Low (shorter) | — |
| ja | 0.8-1.3x | Medium | Settings tabs, error messages |
| ko | 0.9-1.2x | Medium | Settings tabs |
| es | 1.2-1.5x | Medium | Button labels, tooltips |
| fr | 1.3-1.5x | High | Button labels, settings |
| de | 1.3-1.6x | **Critical** | Compound words overflow |
| pt-BR | 1.2-1.4x | Medium | Button labels |
| ar | 0.8-1.0x | Low (shorter) | RTL layout issues |
| he | 0.9-1.1x | Low | RTL layout issues |

**German is the highest overflow risk.** Specific terms to watch:
- "Wiedergabeliste" (Playlist) — 15 chars vs 8
- "Untertitelverzögerung" (Subtitle Delay) — 20 chars vs 14
- "Videowiedergabeeinstellungen" (Video Playback Settings) — 28 chars vs 24

**Mitigation:**
- Use `FittedBox` or `AutoSizeText` for long labels
- Set `overflow: TextOverflow.ellipsis` on fixed-width containers
- Consider abbreviated forms for German where space is tight

## Appendix C: Locale Code Reference

| Code | Language | Country/Region | Script | Direction |
|------|----------|---------------|--------|-----------|
| `en` | English | — | Latin | LTR |
| `zh` | Chinese | — (Simplified) | Han (Simplified) | LTR |
| `zh-TW` | Chinese | Taiwan (Traditional) | Han (Traditional) | LTR |
| `ja` | Japanese | — | Mixed (Kanji+Kana) | LTR |
| `ko` | Korean | — | Hangul | LTR |
| `es` | Spanish | Spain | Latin | LTR |
| `fr` | French | France | Latin | LTR |
| `de` | German | Germany | Latin | LTR |
| `pt-BR` | Portuguese | Brazil | Latin | LTR |
| `ar` | Arabic | — | Arabic | RTL |
| `he` | Hebrew | — | Hebrew | RTL |

#!/usr/bin/env python3
"""One-shot: point every test file's localizationsDelegates at the shared
lib/l10n/localizations_delegates.dart constant (l10nDelegates), inserting
the proper relative import for each file depth."""
import glob
import re

helper_import = (
    "import 'package:simple_player_flutter/l10n/localizations_delegates.dart'"
    " show l10nDelegates;\n"
)

changed = 0
files = sorted(glob.glob('test/**/*.dart', recursive=True)) + ['lib/app.dart']
for p in files:
    s = open(p, encoding='utf-8').read()
    if 'AppLocalizations.localizationsDelegates' not in s:
        continue
    s2 = s.replace(
        'AppLocalizations.localizationsDelegates', 'l10nDelegates'
    )
    if p.endswith('app.dart'):
        # Collapse the hand-assembled block from the previous commit into the
        # shared constant (single source of truth).
        s2 = re.sub(
            r"          // delegates 手工组装.*?localizationsDelegates: const"
            r" <LocalizationsDelegate<Object>>\[.*?\],\n",
            "          localizationsDelegates: l10nDelegates,\n",
            s2,
            flags=re.S,
        )
        for gone in (
            "import 'package:cupertino_ui/cupertino_ui.dart' as cui;\n",
            "import 'package:flutter_localizations/flutter_localizations.dart'"
            " as fl;\n",
            "import 'package:material_ui/material_ui.dart' as mui;\n",
        ):
            s2 = s2.replace(gone, '')
        s2 = s2.replace(
            "import 'l10n/app_localizations.dart';",
            "import 'l10n/app_localizations.dart';\n"
            "import 'l10n/localizations_delegates.dart' show l10nDelegates;",
        )
    else:
        depth = p.replace('\\', '/').count('/') - 1
        rel = '../' * depth + 'helpers/l10n_delegates.dart'
        imp = f"import '{rel}' show l10nDelegates;\n"
        if imp not in s2 and 'l10n_delegates.dart' not in s2:
            lines = s2.split('\n')
            last_imp = max(
                i for i, l in enumerate(lines) if l.startswith('import ')
            )
            lines.insert(last_imp + 1, imp.rstrip('\n'))
            s2 = '\n'.join(lines)
    open(p, 'w', encoding='utf-8', newline='\n').write(s2)
    changed += 1
print('changed files:', changed)

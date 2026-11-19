"""Compare a built app and its installed copy without operating the simulator.
Pass the installed app path returned by simctl get_app_container DEVICE BUNDLE app.
Exit nonzero if any shipped file differs or is missing, including appex debug dylibs.
"""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import sys

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('built_app', type=Path)
parser.add_argument('installed_app', type=Path)
parser.add_argument('--report', type=Path, required=True)
args = parser.parse_args()
for path in (args.built_app, args.installed_app):
    if not path.is_dir() or not (path / 'Info.plist').is_file():
        parser.error(f'Not an app bundle: {path}')

def digest(path):
    if not path.is_file():
        return None
    value = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            value.update(chunk)
    return value.hexdigest()

files = []
for source in sorted(args.built_app.rglob('*')):
    if source.is_file():
        relative = source.relative_to(args.built_app)
        built = digest(source)
        installed = digest(args.installed_app / relative)
        files.append({'path': str(relative), 'built_sha256': built,
                      'installed_sha256': installed, 'match': built == installed})
bundles = []
for info in [args.built_app / 'Info.plist', *args.built_app.glob('PlugIns/*.appex/Info.plist')]:
    relative = info.relative_to(args.built_app)
    versions = {}
    for label, root in [('built', args.built_app), ('installed', args.installed_app)]:
        path = root / relative
        if path.is_file():
            with path.open('rb') as stream:
                data = plistlib.load(stream)
            versions[label] = {key: data.get(key) for key in
                               ('CFBundleIdentifier', 'CFBundleVersion', 'CFBundleShortVersionString', 'CFBundleExecutable')}
    bundles.append({'path': str(relative.parent), **versions})
matched = bool(files) and all(file['match'] for file in files)
report = {'built_app': str(args.built_app.resolve()), 'installed_app': str(args.installed_app.resolve()),
          'match': matched, 'bundles': bundles, 'files': files,
          'limitation': 'File equality establishes installation identity, not that an existing SpringBoard widget process or cached view has reloaded.'}
args.report.write_text(json.dumps(report, indent=2))
print(json.dumps({'match': matched, 'checked_files': len(files),
                  'differences': [file['path'] for file in files if not file['match']],
                  'report': str(args.report)}))
sys.exit(0 if matched else 1)

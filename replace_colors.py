import os
import re

lib_dir = r"c:\Users\ignac\Documents\github projects\Eitzy\sefirot\lib\presentation"

replacements = {
    r'\b_black\b': 'Theme.of(context).colorScheme.onSurface',
    r'\b_white\b': 'Theme.of(context).cardColor',
    r'\b_blue\b': 'Theme.of(context).colorScheme.secondary',
    r'\b_red\b': 'Theme.of(context).colorScheme.primary',
    r'\b_bg\b': 'Theme.of(context).colorScheme.surface',
    r'\b_cream\b': 'Theme.of(context).colorScheme.surfaceContainerHighest',
    r'\b_primaryBlue\b': 'Theme.of(context).colorScheme.secondary',
    r'\b_primaryRed\b': 'Theme.of(context).colorScheme.primary',
}

constants_to_remove = [
    r'^const _black.*$',
    r'^const _white.*$',
    r'^const _blue.*$',
    r'^const _red.*$',
    r'^const _bg.*$',
    r'^const _cream.*$',
    r'^const _primaryBlue.*$',
    r'^const _primaryRed.*$',
    r'^const _googleBlue.*$', # we might need this one intact actually, I'll leave googleBlue
]

def process_file(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    original_content = content
    # Remove constant declarations
    for p in constants_to_remove:
        content = re.sub(p, '', content, flags=re.MULTILINE)

    # Replace usages
    for k, v in replacements.items():
        content = re.sub(k, v, content)
        
    if content != original_content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Updated {file_path}")

for root, _, files in os.walk(lib_dir):
    for f in files:
        if f.endswith('.dart'):
            process_file(os.path.join(root, f))

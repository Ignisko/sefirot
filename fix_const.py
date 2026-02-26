import re
import sys
import os

analysis_file = 'analysis_cmd2.txt'

if not os.path.exists(analysis_file):
    print("analysis_file not found")
    sys.exit(0)

with open(analysis_file, 'r', encoding='utf-8') as f:
    lines = f.readlines()

fixes_made = 0
file_changes = {}

for line in lines:
    # Look for errors related to const
    if ('non_constant_default_value' in line or 
        'invalid_constant' in line or
        'const_eval_method_invocation' in line or
        "isn't a constant expression" in line or
        "cannot be invoked in a 'const' constructor" in line or
        "list literal must be constants" in line or
        "values in a const map literal" in line or
        "The constructor being called isn't a const" in line or
        "Const constructors can't be called" in line or
        "Arguments of a constant creation must be" in line or
        "Const variables must be initialized" in line):
        
        # Format: info - Invalid constant value - lib\path.dart:line:col - rule
        # Or: error - ...
        match = re.search(r'-\s+(lib[\\/].*?\.dart):(\d+):(\d+)\s+-', line)
        if match:
            file_path = match.group(1).replace('\\', '/')
            # Ensure the path is relative to the current directory
            file_path = os.path.normpath(file_path)
            line_num = int(match.group(2)) - 1
            
            if file_path not in file_changes:
                if os.path.exists(file_path):
                    with open(file_path, 'r', encoding='utf-8') as f_dart:
                        file_changes[file_path] = f_dart.readlines()
                else:
                    continue

            dart_lines = file_changes[file_path]
            if 0 <= line_num < len(dart_lines):
                # Search backwards for the nearest 'const ' keyword up to 20 lines, stopping at ;, {, }
                for i in range(line_num, max(-1, line_num - 20), -1):
                    original = dart_lines[i]
                    if 'const ' in original:
                        dart_lines[i] = re.sub(r'\bconst\s+', '', original, count=1)
                        fixes_made += 1
                        break
                    if ';' in original or '{' in original or '}' in original:
                        if i != line_num: # if it's not the error line itself
                            break

# Write back changes
for file_path, dart_lines in file_changes.items():
    with open(file_path, 'w', encoding='utf-8') as f_dart:
        f_dart.writelines(dart_lines)

print(f"Removed const in {fixes_made} places.")

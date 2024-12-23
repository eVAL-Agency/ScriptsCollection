import shutil
from glob import glob
import os

def parse_include(src_file: str, src_line: int, include: str, scriptlets: list):
	dependencies = ''
	output = ''

	if include not in scriptlets:
		scriptlets.append(include)
		file = os.path.join('scriptlets', include)
		if os.path.exists(file):
			output += '# scriptlet: ' + include + '\n'
			line_number = 0

			with open(file, 'r') as include_f:
				for include_line in include_f:
					line_number += 1
					if include_line.startswith('# scriptlet:'):
						sub_include = include_line[12:].strip()
						dependencies += parse_include(file, line_number, sub_include, scriptlets)
					else:
						output += include_line
			if not output.endswith("\n"):
				output += "\n"
			output += '# end-scriptlet: ' + include + '\n\n'
		else:
			output += '# ERROR - scriptlet ' + include+ ' not found\n\n'
			print('ERROR - script %s not found' % include)
			print('  in file %s at line %d' % (src_file, src_line))

	return dependencies + output


# Parse and company any script files
for file in glob('src/**/*.sh', recursive=True):
	print('Parsing file %s' % file)
	dest_file = 'dist/' + file[4:]
	if not os.path.exists(os.path.dirname(dest_file)):
		os.makedirs(os.path.dirname(dest_file))

	scriptlets = []
	line_number = 0

	with open(file, 'r') as f:
		with open(dest_file, 'w') as dest_f:
			for line in f:
				line_number += 1
				# Check for "# scriptlet:..." replacements
				if line.startswith('# scriptlet:'):
					include = line[12:].strip()
					dest_f.write(parse_include(file, line_number, include, scriptlets))
				else:
					dest_f.write(line)

# Locate and copy any README files
for file in glob('src/**/README.md', recursive=True):
	print('Copying README %s' % file)
	dest_file = 'dist/' + file[4:]
	if not os.path.exists(os.path.dirname(dest_file)):
		os.makedirs(os.path.dirname(dest_file))

	shutil.copy(file, dest_file)

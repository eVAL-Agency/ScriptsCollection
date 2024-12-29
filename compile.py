import shutil
from glob import glob
import os
import stat
from pprint import pprint


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


def get_bash_header():
	lines = []

	lines.append('#')
	#lines.append('# Generated on ' + datetime.now().strftime('%Y-%m-%d %H:%M:%S'))
	lines.append('# Collection repository: https://github.com/cdp1337/ScriptsCollection')
	lines.append('')

	return "\n".join(lines)


scripts = []


# Parse and company any script files
for file in glob('src/**/*.sh', recursive=True):
	print('Parsing file %s' % file)
	dest_file = 'dist/' + file[4:]
	if not os.path.exists(os.path.dirname(dest_file)):
		os.makedirs(os.path.dirname(dest_file))

	scriptlets = []
	line_number = 0
	in_header = True
	title = None
	readme = None

	if os.path.exists(os.path.join(os.path.dirname(file), 'README.md')):
		readme = os.path.join(os.path.dirname(file), 'README.md')

	with open(file, 'r') as f:
		with open(dest_file, 'w') as dest_f:
			for line in f:
				line_number += 1
				# Check for "# scriptlet:..." replacements
				if line.startswith('# scriptlet:'):
					if in_header:
						# Print header before continuing
						in_header = False
						dest_f.write(get_bash_header())
					include = line[12:].strip()
					dest_f.write(parse_include(file, line_number, include, scriptlets))
				else:
					if in_header and title is None and line.startswith('#') and line.strip() != '#' and line_number > 1:
						title = line[1:].strip()
					
					if in_header and not line.startswith('#'):
						# Print header before continuing
						in_header = False
						dest_f.write(get_bash_header())
					dest_f.write(line)

	# Ensure new file is executable
	os.chmod(dest_file, 0o775)

	# Add to stack to update project docs
	scripts.append({
		'title': title,
		'readme': readme,
		'file': file
	})

# Locate and copy any README files
for file in glob('src/**/README.md', recursive=True):
	print('Copying README %s' % file)
	dest_file = 'dist/' + file[4:]
	if not os.path.exists(os.path.dirname(dest_file)):
		os.makedirs(os.path.dirname(dest_file))

	shutil.copy(file, dest_file)

pprint(scripts)
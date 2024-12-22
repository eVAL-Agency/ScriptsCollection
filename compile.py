from glob import glob
from pprint import pprint
import os

def parse_include(include, scriptlets):
	dependencies = ''
	output = ''

	if include not in scriptlets:
		scriptlets.append(include)
		file = os.path.join('scriptlets', include)
		if os.path.exists(file):
			output += '# scriptlet: ' + include + '\n'
			with open(file, 'r') as include_f:
				for include_line in include_f:
					if include_line.startswith('# scriptlet:'):
						sub_include = include_line[12:].strip()
						dependencies += parse_include(sub_include, scriptlets)
					else:
						output += include_line
			if not output.endswith("\n"):
				output += "\n"
			output += '# end-scriptlet: ' + include + '\n\n'
		else:
			output += '# ERROR - scriptlet ' + include+ ' not found\n\n'

	return dependencies + output


for file in glob('src/**/*.sh', recursive=True):
	print('Parsing file %s' % file)
	dest_file = 'dist/' + file[4:]
	if not os.path.exists(os.path.dirname(dest_file)):
		os.makedirs(os.path.dirname(dest_file))

	scriptlets = []

	with open(file, 'r') as f:
		with open(dest_file, 'w') as dest_f:
			for line in f:
				# Check for "# scriptlet:..." replacements
				if line.startswith('# scriptlet:'):
					include = line[12:].strip()
					dest_f.write(parse_include(include, scriptlets))
				else:
					dest_f.write(line)

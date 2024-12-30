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


class Script:
	def __init__(self, file: str):
		self.file = file
		self.title = None
		self.readme = None
		self.author = None
		self.supports = []
		self.scriptlets = []

	def parse(self):
		print('Parsing file %s' % self.file)
		dest_file = 'dist/' + self.file[4:]
		if not os.path.exists(os.path.dirname(dest_file)):
			os.makedirs(os.path.dirname(dest_file))

		scriptlets = []
		line_number = 0
		in_header = True

		if os.path.exists(os.path.join(os.path.dirname(self.file), 'README.md')):
			self.readme = os.path.join(os.path.dirname(self.file), 'README.md')

		with open(self.file, 'r') as f:
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
						if in_header and not line.startswith('#'):
							# Print header before continuing
							in_header = False
							dest_f.write(get_bash_header())

						if in_header:
							# Process header tags
							if self.title is None and line.strip() != '#' and line_number > 1:
								self.title = line[1:].strip()
							elif '@AUTHOR' in line:
								self._parse_author(line)
							elif '@SUPPORTS' in line:
								self._parse_supports(line)

						dest_f.write(line)

		# Ensure new file is executable
		os.chmod(dest_file, 0o775)

	def _parse_author(self, line):
		a = line[9:].strip()
		if '<' in a and '>' in a:
			n = a[:a.find('<')].strip()
			e = a[a.find('<')+1:a.find('>')].strip()
			self.author = {'name': n, 'email': e}
		else:
			self.author = {'name': a, 'email': None}

	def _parse_supports(self, line):
		# @SUPPORTS: ubuntu, debian, centos
		s = line[11:].strip().lower()
		maps = [
			('debian', ('debian',)),
			('ubuntu', ('ubuntu',)),
			('centos', ('centos',)),
			('redhat', ('redhat', 'rhel')),
			('fedora', ('fedora',)),
			('suse', ('suse', 'opensuse')),
			('linuxmint', ('linuxmint',)),
		]
		for os_key, lookups in maps:
			for lookup in lookups:
				if lookup in s and os_key not in self.supports:
					self.supports.append(os_key)

	def __str__(self):
		return 'Script: %s' % self.file

	def asdict(self):
		return {
			'file': self.file,
			'title': self.title,
			'readme': self.readme,
			'author': self.author,
			'supports': self.supports,
		}

# Parse and company any script files
for file in glob('src/**/*.sh', recursive=True):
	script = Script(file)
	# Parse the source
	script.parse()
	# Add to stack to update project docs
	scripts.append(script)

# Locate and copy any README files
for file in glob('src/**/README.md', recursive=True):
	print('Copying README %s' % file)
	dest_file = 'dist/' + file[4:]
	if not os.path.exists(os.path.dirname(dest_file)):
		os.makedirs(os.path.dirname(dest_file))

	shutil.copy(file, dest_file)

# Update project README
for s in scripts:
	with open('README.md', 'w') as f:
		f.write('# Scripts Collection\n\n')
		f.write('A collection of useful scripts for various Linux distributions\n\n')
		f.write('## Scripts\n\n')
		f.write('| Script | Supports |\n')
		f.write('|--------|----------|\n')
		for script in scripts:
			title = script.title if script.title else script.file
			href = script.readme if script.readme else script.file
			os_support = []
			for support in script.supports:
				os_support.append('![%s](docs/images/icons/%s.svg)' % (support, support))
			f.write('| [%s](%s) | %s |\n' % (title, href, ' '.join(os_support)))
	pprint(s.asdict())
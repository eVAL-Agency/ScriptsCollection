import re
import shutil
import uuid
from glob import glob
import os
import stat
from pprint import pprint
import json


class Script:
	def __init__(self, file: str, type: str):
		self.file = file
		self.type = type
		self.title = None
		self.readme = None
		self.author = None
		self.guid = None
		self.category = None
		self.trmm_timeout = 60
		self.supports = []
		self.supports_detailed = []
		self.scriptlets = []
		self.imports = []
		self.args = []
		self.env = []
		self.syntax = []
		self.content_header = ''
		self.content_body = ''

	def parse(self):
		"""
		Parse a script file to produce a single distributable file with all dependencies included
		:return:
		"""
		print('Parsing file %s' % self.file)
		line_number = 0
		in_header = True
		header_section = None

		self._parse_guid()

		if os.path.exists(os.path.join(os.path.dirname(self.file), 'README.md')):
			self.readme = os.path.join(os.path.dirname(self.file), 'README.md')

		with open(self.file, 'r') as f:
			for line in f:
				line_number += 1
				write = True

				if line.startswith('# scriptlet:'):
					# Check for "# scriptlet:..." replacements
					in_header = False
					include = line[12:].strip()
					line = self._parse_include(file, line_number, include)

				if line.startswith('import ') and self.type == 'python':
					in_header = False
					self._parse_import(line)
					write = False

				if line.startswith('from scriptlets.') and self.type == 'python':
					# Treat this as a scriptlet include
					# Trim "from scriptlets." off the beginning to get the filename
					line = line[16:].strip()
					# Trim anything after "import..."; we'll just include the whole file
					line = line[:line.index(' import')]
					line = line.replace('.', '/') + '.py'
					line = self._parse_include(file, line_number, line)

				if in_header and not line.startswith('#'):
					# End of '#' lines indicate an end of the header
					in_header = False

				if in_header:
					# Process header tags
					if self.title is None and line.strip() != '#' and line_number > 1:
						self.title = line[1:].strip()
					elif '@AUTHOR' in line:
						self._parse_author(line)
					elif '@SUPPORTS' in line:
						self._parse_supports(line)
					elif '@CATEGORY' in line:
						self.category = line[11:].strip()
					elif '@TRMM-TIMEOUT' in line:
						self.trmm_timeout = int(line[15:].strip())
					elif '# trmm arguments:' == line.lower().strip():
						header_section = 'trmm_args'
					elif '# trmm environment:' == line.lower().strip():
						header_section = 'trmm_env'
					elif '# syntax:' == line.lower().strip():
						header_section = 'syntax'
					elif '# supports:' == line.lower().strip():
						header_section = 'supports'
					elif line[0:3] == '#  ' and header_section == 'trmm_args':
						self._parse_arg(line)
					elif line[0:3] == '#  ' and header_section == 'trmm_env':
						self._parse_env(line)
					elif line[0:3] == '#  ' and header_section == 'syntax':
						self._parse_syntax(line)
					elif line[0:3] == '#  ' and header_section == 'supports':
						self._parse_supports(line)
					elif line.strip() == '#' and header_section is not None:
						header_section = None

				if write:
					if in_header:
						self.content_header += line
					else:
						self.content_body += line

	def write(self):
		"""
		Write generated script to the filesystem
		:return:
		"""
		dest_file = 'dist/' + self.file[4:]
		if not os.path.exists(os.path.dirname(dest_file)):
			os.makedirs(os.path.dirname(dest_file))

		# Generate the compiled file
		with open(dest_file, 'w') as dest_f:
			dest_f.write(self.content_header)
			if self.type == 'python':
				dest_f.write('\n'.join(self.imports))
			dest_f.write(self.content_body)
		# Ensure new file is executable
		os.chmod(dest_file, 0o775)

		# Store the TRMM metafile
		#script_name = os.path.basename(self.file)[:-3]
		#with open(os.path.join(os.path.dirname(dest_file), script_name + '.json'), 'w') as dest_f:
		#	dest_f.write(json.dumps([self.as_trmm_meta()], indent=4))

	def _parse_import(self, line: str):
		"""
		Parse Python-style 'import' statements to the parent script
		:param line:
		:return:
		"""
		# import blah
		if not line.strip() in self.imports:
			self.imports.append(line.strip())

	def _parse_include(self, src_file: str, src_line: int, include: str):
		if include not in self.scriptlets:
			self.scriptlets.append(include)
			file = os.path.join('scriptlets', include)
			if os.path.exists(file):
				script = Script(file, self.type)
				script.scriptlets = self.scriptlets
				script.imports = self.imports
				# Parse the source
				script.parse()
				return script.content_header + script.content_body
			else:
				print('ERROR - script %s not found' % include)
				print('  in file %s at line %d' % (src_file, src_line))
				return '# ERROR - scriptlet ' + include + ' not found\n\n'
		else:
			return ''

	def _parse_syntax(self, line: str):
		#   -n - Run in non-interactive mode, (will not ask for prompts)
		line = line[1:].strip()
		self.syntax.append(line)

	def _parse_arg(self, line: str):
		#   -n - Run in non-interactive mode, (will not ask for prompts)
		line = line[1:].strip()
		self.args.append(line)

	def _parse_env(self, line: str):
		#   ZABBIX_SERVER - Hostname or IP of Zabbix server
		line = line[1:].strip()
		self.env.append(line)

	def _parse_guid(self):
		hashedValueEven = hashedValueOdd = 3074457345618258791
		KnuthMultiValue = 3074457345618258799
		i = 1
		for char in self.file:
			i += 1
			if i % 2 == 0:
				hashedValueEven = (hashedValueEven + ord(char)) * KnuthMultiValue
			else:
				hashedValueOdd = (hashedValueOdd + ord(char)) * KnuthMultiValue

		frame = bytearray()
		frame.append(0xff & hashedValueEven)
		frame.append(0xff & hashedValueEven >> 8)
		frame.append(0xff & hashedValueEven >> 16)
		frame.append(0xff & hashedValueEven >> 24)
		frame.append(0xff & hashedValueEven >> 32)
		frame.append(0xff & hashedValueEven >> 40)
		frame.append(0xff & hashedValueEven >> 48)
		frame.append(0xff & hashedValueEven >> 56)
		frame.append(0xff & hashedValueOdd)
		frame.append(0xff & hashedValueOdd >> 8)
		frame.append(0xff & hashedValueOdd >> 16)
		frame.append(0xff & hashedValueOdd >> 24)
		frame.append(0xff & hashedValueOdd >> 32)
		frame.append(0xff & hashedValueOdd >> 40)
		frame.append(0xff & hashedValueOdd >> 48)
		frame.append(0xff & hashedValueOdd >> 56)
		self.guid = uuid.UUID(bytes=bytes(frame)).__str__()


	def _parse_author(self, line):
		a = line[9:].strip()
		if '<' in a and '>' in a:
			n = a[:a.find('<')].strip()
			e = a[a.find('<')+1:a.find('>')].strip()
			self.author = {'name': n, 'email': e}
		else:
			self.author = {'name': a, 'email': None}

	def _parse_supports(self, line):
		if line.lower().startswith('# @supports'):
			# @SUPPORTS ubuntu, debian, centos
			line = line[11:].strip()
		else:
			# Supports:\n#  Distro Name\n...
			line = line[1:].strip()
		s = line.lower()
		maps = [
			('centos', ('linux-all', 'centos')),
			('debian', ('linux-all', 'debian')),
			('fedora', ('linux-all', 'fedora')),
			('linuxmint', ('linux-all', 'linuxmint')),
			('redhat', ('linux-all', 'redhat', 'rhel')),
			('rocky', ('linux-all', 'rocky', 'rockylinux')),
			('suse', ('linux-all', 'suse', 'opensuse')),
			('ubuntu', ('linux-all', 'ubuntu')),
		]
		for os_key, lookups in maps:
			for lookup in lookups:
				if lookup in s and os_key not in self.supports:
					self.supports.append(os_key)
					self.supports_detailed.append((os_key, line))

	def __str__(self):
		return 'Script: %s' % self.file

	def get_full_author(self) -> str:
		if self.author is None:
			return ''
		elif self.author['email']:
			return '%s <%s>' % (self.author['name'], self.author['email'])
		else:
			return self.author['name']

	def asdict(self):
		return {
			'file': self.file,
			'title': self.title,
			'readme': self.readme,
			'author': self.author,
			'supports': self.supports,
			'category': self.category,
			'trmm_timeout': self.trmm_timeout,
			'guid': self.guid,
		}

	def as_trmm_meta(self):
		return {
			'$schema': 'https://raw.githubusercontent.com/amidaware/community-scripts/main/community_scripts.schema.json',
			'guid': self.guid,
			'filename': os.path.basename(self.file),
			'args': self.args,
			'env': self.env,
			'submittedBy': self.get_full_author(),
			'name': self.title,
			'syntax': self.syntax,
			'default_timeout': str(self.trmm_timeout),
			'shell': self.type,
			'supported_platforms': [['linux'] + self.supports],
			'category': self.category,
		}


# Clean the dist directory
if os.path.exists('dist'):
	shutil.rmtree('dist')

scripts = []


# Parse and company any script files
for file in glob('src/**/*.sh', recursive=True):
	script = Script(file, 'shell')
	# Parse the source
	script.parse()
	script.write()
	# Add to stack to update project docs
	scripts.append(script)

for file in glob('src/**/*.py', recursive=True):
	script = Script(file, 'python')
	# Parse the source
	script.parse()
	script.write()
	# Add to stack to update project docs
	scripts.append(script)

# Locate and copy any README files
for file in glob('src/**/README.md', recursive=True):
	print('Copying README %s' % file)
	dest_file = 'dist/' + file[4:]
	if not os.path.exists(os.path.dirname(dest_file)):
		os.makedirs(os.path.dirname(dest_file))

	shutil.copy(file, dest_file)

# Generate project README
scripts_table = []
scripts_table.append('| Script | Type | Supports |')
scripts_table.append('|--------|------|----------|')
for script in scripts:
	title = script.title if script.title else script.file
	href = script.readme.replace('src/', 'dist/') if script.readme else script.file.replace('src/', 'dist/')
	type = script.type[0].upper() + script.type[1:]
	os_support = []
	supported = script.supports_detailed
	supported.sort(key = lambda x: x[0])
	for support in supported:
		os_support.append('![%s](.supplemental/images/icons/%s.svg "%s")' % (support[0], support[0], support[1]))
	scripts_table.append('| [%s](%s) | %s | %s |' % (title, href, type, ' '.join(os_support)))

replacements = {
	'%%SCRIPTS_TABLE%%': '\n'.join(scripts_table),
}
with open('.supplemental/README-template.md', 'r') as f:
	template = f.read()
	for key, value in replacements.items():
		template = template.replace(key, value)

with open('README.md', 'w') as f:
	f.write(template)

# Generate TRMM metafile
with open('dist/community_scripts.json', 'w') as f:
	meta = []
	for script in scripts:
		data = script.as_trmm_meta()
		data['filename'] = script.file[4:]
		meta.append(data)
	f.write(json.dumps(meta, indent=4))
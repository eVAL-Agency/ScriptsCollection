import os
from pathlib import Path
from typing import List

class UnrealConfigParser:
	"""
	Class to parse and modify Unreal Engine INI configuration files
	Version 1.2.0
	Forked from https://github.com/xwoojin/UEConfigParser
	Licensed under MIT License
	"""
	def __init__(self):
		"""Constructor"""
		self.content: List[str] = []
		self.changed = False

	def is_empty(self) -> bool:
		"""
		Check if the content is empty
		"""
		return len(self.content) == 0

	def is_changed(self) -> bool:
		"""
		Check if the content has been changed
		"""
		return self.changed

	def is_filename(self, file_path: str):
		"""
		Check if the file exists
		:param file_path: Path to the file
		"""
		return Path(file_path).name == file_path

	def read_file(self, file_path: str):
		"""Read and store file contents
			Args:
				file_path: Path to the INI file
			Raises:
				FileNotFoundError: If file doesn't exist
		"""
		if not os.path.exists(file_path):
			raise FileNotFoundError(f'File not found: {file_path}')

		with open(file_path, 'r', encoding='utf-8') as file:
			self.content = file.readlines()

		self.changed = False

	def write_file(self, output_path: str, newline_option=None):
		"""
		Writes output to a file with the changes made
		:param output_path: Path to the output file
		:param newline_option: Newline character to use. Options: 'None','\n', '\r\n' (default: None)
		"""
		file_path = output_path
		if self.is_filename(output_path):
			file_path = os.path.join(os.getcwd(), output_path)
		if not os.path.exists(os.path.dirname(file_path)):
			try:
				os.makedirs(os.path.dirname(file_path))
			except Exception as e:
				print(f'Directory create error: {file_path}', end='')
				print(e)
		try:
			with open(file_path, 'w', encoding='utf-8', newline=newline_option) as file:
				file.writelines(self.content)
			self.changed = False
		except Exception as e:
			print(f'File write error: ', end='')
			print(e)
			raise

	def is_section(self, line: str, section: str) -> bool:
		"""
		Checks if the line is a section
		:param line: Line to check
		:param section: Section name to compare
		"""
		if line.startswith('[') and line.endswith(']'):
			current_section = line[1:-1].strip()
			return current_section == section
		return False

	def add_key(self, section: str, key: str, value: str):
		"""
		Adds a key to a section
		:param section: Section name to add the key
		:param key: Key name to add
		:param value: Value to add
		"""
		in_section = False
		updated_lines = []
		section_found = False
		for index, line in enumerate(self.content):
			stripped = line.strip()
			if self.is_section(stripped, section):
				in_section = True
				section_found = True

			if in_section and (index + 1 == len(self.content) or self.content[index + 1].strip().startswith('[')):
				# Look-ahead to see if next line is a new section or end of file
				updated_lines.append(f"{key}={value}\n")
				self.changed = True
				in_section = False

			updated_lines.append(line)
		if not section_found:
			updated_lines.append(f'\n[{section}]\n')
			updated_lines.append(f'{key}={value}\n')
			self.changed = True
		self.content = updated_lines

	def add_key_after_match(self, section: str, substring: str, new_line: str):
		"""
		Adds a new line after the line in the specified section where the substring matches.

		:param section: The section name to search in
		:param substring: The substring to search for in lines within the section
		:param new_line: The new line to append after the matched line
		:raises ValueError: If the section or matching substring is not found
		"""
		in_section = False
		updated_lines = []
		section_found = False
		found = False
		for index, line in enumerate(self.content):
			stripped = line.strip()
			if self.is_section(stripped, section):
				in_section = True
				section_found = True
			if in_section and substring in stripped and not found:
				updated_lines.append(line)  # Add the current line
				updated_lines.append(new_line + '\n')  # Add the new line after the match
				self.changed = True
				found = True
			else:
				updated_lines.append(line)

			# If we exit the section
			if in_section and self.is_section(line, section) and stripped[1:-1] != section:
				in_section = False

		if not section_found:
			updated_lines.append(f'\n[{section}]\n')
			updated_lines.append(f'{new_line}\n')
			self.changed = True
		self.content = updated_lines

	def remove_key(self, section: str, key: str):
		"""
		Removes a key from a section
		:param section: Section name to remove the key
		:param key: Key name to remove
		"""
		in_section = False
		exists = False
		updated_lines = []
		for line in self.content:
			if not exists:
				stripped = line.strip()
				if self.is_section(stripped, section):
					in_section = True
				elif stripped.startswith('[') and stripped.endswith(']'):
					in_section = False
				if in_section and '=' in stripped and not stripped.startswith((';', '#')):
					current_key, value = map(str.strip, stripped.split('=', 1))
					if current_key == key:
						exists = True
						self.changed = True
						continue
			updated_lines.append(line)

		if not exists:
			return False
		self.content = updated_lines
		return True

	def remove_key_by_substring_search(self, section: str, substring: str, search_in_comment=False):
		"""
		Removes a key from a section
		:param section: Section name to remove the key
		:param key: Key name to remove
		"""
		in_section = False
		exists = False
		updated_lines = []
		for line in self.content:
			if not exists:
				stripped = line.strip()
				if self.is_section(stripped, section):
					in_section = True
				elif stripped.startswith('[') and stripped.endswith(']'):
					in_section = False
				if in_section and '=' in stripped:
					search = True
					if stripped.startswith(';') or stripped.startswith('#'):
						if not search_in_comment:
							search = False
					if search:
						if substring in stripped:
							exists = True
							self.changed = True
							continue
			updated_lines.append(line)

		if not exists:
			return False
		self.content = updated_lines
		return True

	def replace_value_with_same_key(self, section: str, key: str, new_value: str, spacing=False):
		"""
		Modifies the value of a key in a section
		:param section: Section name to modify
		:param key: Key name to modify
		:param new_value: New value to set
		:param spacing: Add space between key and the value (default: False)
		"""
		in_section = False
		exists = False
		updated_lines = []
		for line in self.content:
			if not exists:
				stripped = line.strip()
				if self.is_section(stripped, section):
					in_section = True
				elif stripped.startswith('[') and stripped.endswith(']'):
					in_section = False
				if in_section and '=' in stripped and not stripped.startswith((';', '#')):
					current_key, value = map(str.strip, stripped.split('=', 1))
					if current_key == key:
						if spacing:
							line = f'{key} = {new_value}\n'
						else:
							line = f'{key}={new_value}\n'
						self.changed = True
						exists = True
			updated_lines.append(line)

		if not exists:
			return False
		self.content = updated_lines
		return True

	def comment_key(self, section: str, key: str):
		"""
		Disables a key by commenting it out
		:param section: Section name to modify
		:param key: Key name to disable
		"""
		in_section = False
		exists = False
		updated_lines = []
		for line in self.content:
			if not exists:
				stripped = line.strip()
				if self.is_section(stripped, section):
					in_section = True
				elif stripped.startswith('[') and stripped.endswith(']'):
					in_section = False
				if in_section and '=' in stripped and not stripped.startswith((';', '#')):
					current_key, value = map(str.strip, stripped.split('=', 1))
					if current_key == key:
						line = f';{line}'
						self.changed = True
						exists = True
			updated_lines.append(line)
		if not exists:
			return False
		self.content = updated_lines
		return True

	def uncomment_key(self, section: str, key: str):
		"""
		Enables a key by uncommenting it
		:param section: Section name to modify
		:param key: Key name to enable
		"""
		in_section = False
		exists = False
		updated_lines = []
		for line in self.content:
			if not exists:
				stripped = line.strip()
				if self.is_section(stripped, section):
					in_section = True
				elif stripped.startswith('[') and stripped.endswith(']'):
					in_section = False
				if in_section and stripped.startswith(';') and '=' in stripped:
					uncommented_line = stripped[1:].strip()
					current_key, value = map(str.strip, uncommented_line.split('=', 1))
					if current_key == key:
						line = uncommented_line + '\n'
						self.changed = True
						exists = True
			updated_lines.append(line)
		if not exists:
			return False
		self.content = updated_lines
		return True

	def set_value_by_substring_search(self, section: str, match_substring: str, new_value: str, search_in_comment=False):
		"""
		Updates the value of any key in the given section if the full 'key=value' string contains the match_substring. (even partial match)

		:param section: The section to search in.
		:param match_substring: The substring to match within the 'key=value' string.
		:param new_value: The new value to set if the substring matches.
		"""
		in_section = False
		updated_lines = []
		exists = False

		for line in self.content:
			search = True
			updated = False
			if not exists:
				stripped = line.strip()
				if self.is_section(stripped, section):
					in_section = True
				elif stripped.startswith('[') and stripped.endswith(']'):
					in_section = False
				if in_section and '=' in stripped:
					if stripped.startswith((';', '#')):
						if not search_in_comment:
							search = False
					if search:
						key, value = map(str.strip, stripped.split('=', 1))
						if match_substring in stripped:
							line = f'{key}={new_value}\n'
							self.changed = True
							exists = True
			updated_lines.append(line)

		if not exists:
			return False
		self.content = updated_lines
		return True

	def comment_by_substring_search(self, section: str, match_substring: str, search_in_comment=False):
		"""
		comment entire key if value is matched in given section  (even partial match)

		:param section: The section to search in.
		:param key: The key whose value needs to be updated.
		:param match_substring: The substring to match in the current value.
		"""
		in_section = False
		exists = False
		updated_lines = []

		for line in self.content:
			if not exists:
				stripped = line.strip()
				if self.is_section(stripped, section):
					in_section = True
				elif stripped.startswith('[') and stripped.endswith(']'):
					in_section = False
				if in_section and '=' in stripped and not exists:
					search = True
					if stripped.startswith(';') or stripped.startswith('#'):
						if not search_in_comment:
							search = False
					if search:
						current_key, value = map(str.strip, stripped.split('=', 1))
						if match_substring in value:
							line = f';{line}'
							self.changed = True
							exists = True
			updated_lines.append(line)

		if not exists:
			return False
		self.content = updated_lines
		return True

	def uncomment_by_substring_search(self, section: str, match_substring: str):
		"""
		uncomment entire key if value is matched in given section  (even partial match)

		:param section: The section to search in.
		:param match_substring: The substring to match in the current value.
		"""
		in_section = False
		exists = False
		updated_lines = []

		for line in self.content:
			if not exists:
				stripped = line.strip()
				if self.is_section(stripped, section):
					in_section = True
				elif stripped.startswith('[') and stripped.endswith(']'):
					in_section = False
				if in_section and stripped.startswith(';'):
					uncommented_line = stripped[1:].strip()
					if match_substring in stripped:
						line = uncommented_line + '\n'
						self.changed = True
						exists = True
			updated_lines.append(line)

		if not exists:
			return False
		self.content = updated_lines
		return True

	def replace_value_by_substring_search(self, section: str, match_substring: str, new_substring: str, search_in_comment=False):
		"""
		Replaces a substring in the values as it treats key=value entire line as a single string within a given section.

		:param section: The section to search in.
		:param match_substring: The substring to match in the current value.
		:param new_substring: The new substring to replace the match.
		"""
		in_section = False
		exists = False
		updated_lines = []
		for line in self.content:
			search = True
			found = False
			stripped = line.strip()
			if not exists:
				if self.is_section(stripped, section):
					in_section = True
				elif stripped.startswith('[') and stripped.endswith(']'):
					in_section = False
				if in_section and '=' in stripped:
					if stripped.startswith(';') or stripped.startswith('#'):
						if not search_in_comment:
							search = False
					if search:
						if match_substring in stripped:
							line = stripped.replace(match_substring, new_substring) + '\n'
							self.changed = True
							exists = True
							found = True
			updated_lines.append(line)

		if not exists:
			return False
		self.content = updated_lines
		return True

	def display(self):
		"""
		Prints the lines to the console
		"""
		for line in self.content:
			print(line, end='')
		print(' ')

	def get_key(self, section: str, key: str, default: str = '') -> str:
		"""
		Get the value of a requested section/key.

		:param section: Section name to modify
		:param key: Key name to retrieve
		:param default: Default value if key not found

		:return: Value of the key or default if not found
		"""
		in_section = False
		for line in self.content:
			stripped = line.strip()
			if self.is_section(stripped, section):
				in_section = True
			elif stripped.startswith('[') and stripped.endswith(']'):
				in_section = False

			if in_section and '=' in stripped:
				uncommented_line = stripped[1:].strip() if stripped.startswith(';') else stripped
				current_key, value = map(str.strip, uncommented_line.split('=', 1))
				if current_key == key:
					return value

		return default

	def set_key(self, section: str, key: str, value: str):
		"""
		Sets a key/value pair to a section, creating it if necessary

		:param section: Section name to add the key
		:param key: Key name to add
		:param value: Value to add
		"""
		in_section = False
		updated_lines = []
		found = False
		for line in self.content:
			stripped = line.strip()
			if self.is_section(stripped, section):
				in_section = True
			elif stripped.startswith('[') and stripped.endswith(']'):
				in_section = False

			if in_section and '=' in stripped:
				if stripped.startswith(';'):
					uncommented_line = stripped[1:].strip()
					commented = True
				else:
					uncommented_line = stripped
					commented = False
				current_key, prev_value = map(str.strip, uncommented_line.split('=', 1))
				if current_key == key:
					# Key found; replace the line with the new value
					line = ';' if commented else '' + f"{key}={value}\n"
					self.changed = prev_value != value
					found = True
			updated_lines.append(line)

		if found:
			self.content = updated_lines
		else:
			self.add_key(section, key, value)

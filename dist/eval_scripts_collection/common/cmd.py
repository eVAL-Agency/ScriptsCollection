import subprocess
import json
class Cmd:
	"""
	Simple subprocess wrapper to provide convenience methods for common interactions.
	"""
	def __init__(self, cmd: list):
		self.cmd = cmd
		self.result = None

	def exists(self) -> bool:
		"""
		Check if this binary exists
		:return:
		"""
		return subprocess.run(['which', self.cmd[0]], check=False, stdout=subprocess.PIPE).returncode == 0

	def text(self) -> str:
		"""
		Get the output of the command as raw text
		:return:
		"""
		return self._exec().stdout.strip()

	def lines(self) -> list:
		"""
		Get the output of the command as lines of text (as a list)
		:return:
		"""
		return self.text().split('\n')

	def json(self):
		"""
		Get the output of the command decoded as JSON
		:return:
		"""
		return json.loads(self.text())

	def _exec(self):
		if self.result is None:
			self.result = subprocess.run(
				self.cmd,
				stdout=subprocess.PIPE,
				stderr=subprocess.PIPE,
				check=True,
				encoding='utf-8'
			)

		return self.result

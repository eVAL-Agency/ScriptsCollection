##
# Generate a random password, (using characters that are easy to read and type)
function random_password() {
	< /dev/urandom tr -dc _cdefhjkmnprtvwxyACDEFGHJKLMNPQRTUVWXY2345689 | head -c${1:-24};echo;
}
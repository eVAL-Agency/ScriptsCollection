##
# Use sed to set a line in a config file
#
# If the target line does not exist, it will simply get appended to the end
#
# Arguments:
#   $1 Line match
#   $2 Line replace
#   $3 filename
#
# Example:
#   setconfigfile_orappend "^Password=.*" "Password=1234" "/etc/myapp/myapp.conf"
#
#
# CHANGELOG:
#   2025.04.10 - Escape '?' characters in the sed search
function setconfigfile_orappend() {
  # Swap '/' with '\/' since sed here uses '/' as the delimiter
  # Additionally, '?' characters in the SED search need escaped
  SED_SEARCH="$(echo "$1" | sed 's:/:\\/:g' | sed 's:?:\\\?:g')"
  SED_REPLACE="$(echo "$2" | sed 's:/:\\/:g')"
  GREP_SEARCH="$1"
  GREP_REPLACE="$2"
  FILENAME="$3"

  if grep -Eq "$GREP_SEARCH" "$FILENAME"; then
    if [ "$OSFAMILY" == "bsd" ]; then
      sed -i '' "s/$SED_SEARCH/$SED_REPLACE/" "$FILENAME"
    else
      sed -i "s/$SED_SEARCH/$SED_REPLACE/" "$FILENAME"
    fi
  else
    echo "$GREP_REPLACE" >> "$FILENAME"
  fi
}

##
# Disable a package from a given yum repo
function yum_repo_excludepkg() {
	local REPO_FILE="$1"
	local PACKAGE="$2"
	if [ ! -e "$REPO_FILE" ]; then
		# If the repo file does not exist at all, nothing to do.
		return 1
	fi
	local STARTED=0
	local FOUND=0
	local TMP_FILE="$(mktemp)"
	local SECTION=""

	if [ -z "$TMP_FILE" ]; then
		# Ensure a temp file exists for temporary writing, (even if mktemp fails)
		TMP_FILE="/tmp/tmp.$(tr -dc A-Za-z0-9 </dev/urandom | head -c 13)"
		touch $TMP_FILE
	fi

	while read LINE; do
		if [[ "$LINE" =~ ^\[.*\] ]]; then
			# "[...] indicates the start of a new section
			if [ $STARTED -eq 1 -a $FOUND -eq 0 ]; then
				# If a new section has started with the directive being written, ensure it's written
				# prior to the next section starting.
				# Exception is the first section in the file.
				echo "Excluding $PACKAGE from $SECTION in $REPO_FILE"
				echo "excludepkgs=$PACKAGE" >> $TMP_FILE
				echo "" >> $TMP_FILE
			fi
			SECTION="$LINE"
			STARTED=1
			FOUND=0
		fi

		if [[ "$LINE" =~ ^excludepkgs= ]]; then
			# Line contains "excludepkgs", just append the requested package if necessary!
			FOUND=1
			if [ -z "$(echo $LINE | grep "$PACKAGE")" ]; then
				echo "Excluding $PACKAGE from $SECTION in $REPO_FILE"
				if [ "$LINE" == "excludepkgs=" ]; then
					LINE="$LINE$PACKAGE"
				else
					LINE="$LINE,$PACKAGE"
				fi
			fi
		fi

		if [ "$LINE" == "" -a $STARTED -eq 1 ]; then
			# End of a section
			if [ $FOUND -eq 0 ]; then
				echo "Excluding $PACKAGE from $SECTION in $REPO_FILE"
				echo "excludepkgs=$PACKAGE" >> $TMP_FILE
				FOUND=1
			fi
		fi
		echo "$LINE" >> $TMP_FILE
	done <$REPO_FILE

	if [ $FOUND -eq 0 ]; then
		# Last section in the file, if it was not written yet, ensure it's set.
		echo "Excluding $PACKAGE from $SECTION in $REPO_FILE"
		echo "excludepkgs=$PACKAGE" >> $TMP_FILE
	fi

	# Now that all operations are complete, replace the original file with the parsed one.
	mv $TMP_FILE $REPO_FILE
}

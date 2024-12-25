##
# Print a header message
#
function print_header() {
	local header="$1"
	echo "================================================================================"
	printf "%*s\n" $(((${#header}+80)/2)) "$header"
    echo ""
}
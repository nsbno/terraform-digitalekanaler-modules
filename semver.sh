bump() {
	level=$1

	CURRENT_VERSION=$(git describe --abbrev=0 --tags)
	CURRENT_VERSION_SPLIT=(${CURRENT_VERSION//./ })

	MAJOR=${CURRENT_VERSION_SPLIT[0]}
	MINOR=${CURRENT_VERSION_SPLIT[1]}
	PATCH=${CURRENT_VERSION_SPLIT[2]}

	case $level in
	major)
		MAJOR=$((MAJOR + 1))
		MINOR="0"
		PATCH="0"
		;;
	minor)
		MINOR=$((MINOR + 1))
		PATCH="0"
		;;
	patch)
		PATCH=$((PATCH + 1))

		;;
	*)
		echo "Invalid level, use major, minor or patch."
		exit 1
		;;
	esac

	echo "$MAJOR.$MINOR.$PATCH"
}

NEXT_VERSION=$(bump "major")
echo $NEXT_VERSION

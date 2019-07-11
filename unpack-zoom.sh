#!/bin/zsh -f
# Purpose: given a 'zoom' .pkg file, extract just the parts that we need
#
# From:	Timothy J. Luoma
# Mail:	luomat at gmail dot com
# Date:	2019-07-11

NAME="$0:t:r"

if [[ -e "$HOME/.path" ]]
then
	source "$HOME/.path"
else
	PATH='/usr/local/scripts:/usr/local/bin:/usr/bin:/usr/sbin:/sbin:/bin'
fi

function die
{
	echo "$NAME: $@"
	exit 1
}

if [[ "$#" != "1" ]]
then

	echo "$0 expects exactly one argument, which is most likely to be 'Zoom.pkg' from "
	echo "		https://zoom.us/client/latest/Zoom.pkg"

	exit 1
fi

INPUT="$@"

if [[ ! -e "$INPUT" ]]
then

	echo "$NAME: You asked me to act on '$INPUT' but it does not exist."

	echo "	This script expects exactly one argument, which is most likely to be 'Zoom.pkg' from "
	echo "		https://zoom.us/client/latest/Zoom.pkg"

	exit 1
fi

	# get the full path of $INPUT
	# we can use '$INPUT:h' to refer to the directory
	# in which it resides
INPUT=($INPUT(:A))

if [[ "$INPUT:e:l" != "pkg" ]]
then
	echo "$NAME: [WARNING] I was expecting that '$INPUT' would have a '.pkg' extension. It does not, but I'll try anyway."
fi

FILE_TYPE_EXPECTED='xar archive version 1, SHA-1 checksum'

FILE_TYPE_ACTUAL=$(/usr/bin/file -b "$INPUT")

if [[ "$FILE_TYPE_ACTUAL" != "$FILE_TYPE_ACTUAL" ]]
then
	echo "$NAME: Expected '$INPUT' to be '$FILE_TYPE_EXPECTED' but it is '$FILE_TYPE_ACTUAL'."
	echo "	Try downloading the latest version from 'https://zoom.us/client/latest/Zoom.pkg'"

	exit 1
fi

	# this is where we'll put the files while we work on them
TEMP_DIR=$(mktemp -d "${TMPDIR-/tmp/}${NAME}-XXXXXXXX")

	# unpack the .pkg into the temp dir we created
xar -v -x -f "$INPUT" -C "$TEMP_DIR" || die "xar failed to extract '$INPUT' to '$TEMP_DIR'."

cd "$TEMP_DIR" || die "Failed to chdir to '$TEMP_DIR'."

echo "$NAME: Working directory is '$TEMP_DIR'"

if [[ ! -e "Scripts" ]]
then
	die "expected to find a file named 'Scripts' in '$PWD' but did not. Quitting."
fi

	# the 'Scripts' file is actually a 'cpio.gz' file, so we rename it that way
mv -vf "Scripts" "Scripts.cpio.gz" || die "Failed to rename 'Scripts'."

mkdir -p Scripts || die "mkdir 'Scripts' failed"

	# move the 'Scripts.cpio.gz' file to a sub-folder named 'Scripts/'
mv -vf "Scripts.cpio.gz" "Scripts/" || die "mv failed"

cd Scripts || die "'chdir Scripts' failed"

( gunzip --force --stdout --verbose Scripts.cpio.gz | cpio -i ) || die "gunzip/cpio failed"

	# get the 'Scripts.cpio.gz' file out of the way
	# move it back into the parent directory where it originally came from
mv -vf Scripts.cpio.gz ..

	# This should unpack 'zm.7z' into the PWD, which will create 'zoom.us.app'
./7zr x ./zm.7z -o"$PWD" || die "7zr on 'zm.7z' failed"

if [[ ! -d "zoom.us.app" ]]
then
	die "Failed to find 'zoom.us.app' in '$PWD'."
fi

	## this should unpack 'res.7z' and create 'zoom.us.app/Contents/Frameworks/zMacRes.bundle'
./7zr x ./res.7z -o"zoom.us.app/Contents/Frameworks"

if [[ ! -d 'zoom.us.app/Contents/Frameworks/zMacRes.bundle' ]]
then
	die "failed to find 'zoom.us.app/Contents/Frameworks/zMacRes.bundle' in '$PWD'."
fi

########################################################################################################################
#
#	Ok, if we get here, we have the app ready to install
#

GLOBAL_APP_PATH="/Applications/zoom.us.app"

LOCAL_APP_PATH="$HOME/Applications/zoom.us.app"

if [ ! -d "$GLOBAL_APP_PATH" -a ! -d "$LOCAL_APP_PATH" ]
then

	echo "\n\n$NAME: zoom.us.app can be installed either to '$GLOBAL_APP_PATH' or '$LOCAL_APP_PATH'"
	echo "	but it won't be automatically installed unless it is found in either of those places."

		# try to move 'zoom.us.app' to the same dir as the original .pkg file
	mv -n "zoom.us.app" "$INPUT:h"

	EXIT="$?"

	if [ "$EXIT" = "0" ]
	then
		echo "	You can find the current app at '$INPUT:h/zoom.us.app' if you want to install it yourself."

	else
		echo "	You can find the current app at '$PWD/zoom.us.app' if you want to move it yourself."
	fi

elif [ -d "$GLOBAL_APP_PATH" -a -d "$LOCAL_APP_PATH" ]
then

	echo "\n\n$NAME: You seem to have zoom.us.app installed at _BOTH_ places where it can be found:"
	echo "	'$GLOBAL_APP_PATH' _and_ '$LOCAL_APP_PATH'. You should only have one installed."

		# try to move 'zoom.us.app' to the same dir as the original .pkg file
	mv -vn "zoom.us.app" "$INPUT:h"

	EXIT="$?"

	if [ "$EXIT" = "0" ]
	then
		echo "	You can find the current app at '$INPUT:h/zoom.us.app' if you want to install it yourself."

	else
		echo "	You can find the current app at '$PWD/zoom.us.app' if you want to move it yourself."
	fi

else

	if [ -d "$GLOBAL_APP_PATH" ]
	then
		APP_INSTALLED_AT="$GLOBAL_APP_PATH"

	elif [ -d "$LOCAL_APP_PATH" ]
	then
		APP_INSTALLED_AT="$LOCAL_APP_PATH"

	else
			# if it isn't installed anywhere, set variable to ""
		APP_INSTALLED_AT=""
	fi

	if [[ "$APP_INSTALLED_AT" != "" ]]
	then

		echo "$NAME: You have 'zoom.us.app' installed at '$APP_INSTALLED_AT'. Do you you want to replace it with the"
		echo "	version we just unpacked? (You probably do.)\n"

		read "?Replace Existing App? [Y/n] " ANSWER

		case "$ANSWER" in
			N*|n*)
					echo "$NAME: Ok, you can find it at '$PWD' if you want to install it manually."
			;;

			*)
				zmodload zsh/datetime

					# get the current time
				TIME=$(strftime "%Y-%m-%d--%H.%M.%S" "$EPOCHSECONDS")

					# move the old version to the user's trash, just in case they change their minds
				mv -vf "$APP_INSTALLED_AT" "$HOME/.Trash/zoom.us.$TIME.app"

				if [[ -d "$APP_INSTALLED_AT" ]]
				then
					echo "$NAME: Sorry, I tried to remove '$APP_INSTALLED_AT' but failed."

						# try to move 'zoom.us.app' to the same dir as the original .pkg file
					mv -vn "zoom.us.app" "$INPUT:h"

					EXIT="$?"

					if [ "$EXIT" = "0" ]
					then
						echo "	You can find the current app at '$INPUT:h/zoom.us.app' if you want to install it yourself."

					else
						echo "	You can find the current app at '$PWD/zoom.us.app' if you want to move it yourself."
					fi

				else
					mv -vf zoom.us.app "$APP_INSTALLED_AT" \
					&& echo "$NAME: I successfully installed the new version at '$APP_INSTALLED_AT'."
				fi
			;;
		esac
	fi
fi

########################################################################################################################

	# if the plugin is installed for all users
GLOBAL_PLUGIN="/Library/Internet Plug-Ins/ZoomUsPlugIn.plugin"

	# if the plugin is only installed for the local user
LOCAL_PLUGIN="$HOME/Library/Internet Plug-Ins/ZoomUsPlugIn.plugin"

if [ ! -d "$GLOBAL_PLUGIN" -a ! -d "$LOCAL_PLUGIN" ]
then
	echo "\n\n$NAME: The file 'ZoomUsPlugIn.plugin' can be installed either in '/Library/Internet Plug-Ins/' or '$HOME/Library/Internet Plug-Ins/'"
	echo "	but is not currently installed in either place."

		# try to move 'zoom.us.app' to the same dir as the original .pkg file
	mv -n "ZoomUsPlugIn.plugin" "$INPUT:h"

	EXIT="$?"

	if [ "$EXIT" = "0" ]
	then
		echo "	You can find the current plugin at '$INPUT:h/ZoomUsPlugIn.plugin' if you want to install it yourself."

	else
		echo "	You can find the current plugin at '$PWD/ZoomUsPlugIn.plugin' if you want to move it yourself."
	fi

elif [ -d "$GLOBAL_PLUGIN" -a -d "$LOCAL_PLUGIN" ]
then

	echo "\n\n$NAME: You seem to have 'ZoomUsPlugIn.plugin' installed at _BOTH_ locations where it can be installed:"
	echo "		'$GLOBAL_PLUGIN' _and_ '$LOCAL_PLUGIN' "
	echo "	You should remove them both and install the new version from '$PWD' in one or the other location."

		# try to move 'zoom.us.app' to the same dir as the original .pkg file
	mv -vn "ZoomUsPlugIn.plugin" "$INPUT:h"

	EXIT="$?"

	if [ "$EXIT" = "0" ]
	then
		echo "	You can find the current app at '$INPUT:h/ZoomUsPlugIn.plugin' if you want to install it yourself."

	else
		echo "	You can find the current app at '$PWD/ZoomUsPlugIn.plugin' if you want to move it yourself."
	fi

else

	if [ -d "$GLOBAL_PLUGIN" ]
	then
		PLUGIN_INSTALLED_AT="$GLOBAL_PLUGIN"
	elif [ -d "$LOCAL_PLUGIN" ]
	then
		PLUGIN_INSTALLED_AT="$LOCAL_PLUGIN"
	else
		PLUGIN_INSTALLED_AT=""
	fi

	if [[ "$PLUGIN_INSTALLED_AT" != "" ]]
	then
		echo "\n\n$NAME: You already have a plugin installed at '$PLUGIN_INSTALLED_AT' but you should probably replace it with the "
		echo "	new one from this .pkg, just in case they made some changes. Do you want to do that? (You probably do.)"

		read "?Update Plugin? [Y/n] " ANSWER

		case "$ANSWER" in
			N*|n*)
					echo "$NAME: Ok, it will not be replaced."
			;;

			*)
					echo "$NAME: Ok, it will be replaced."

					zmodload zsh/datetime

					TIME=$(strftime "%Y-%m-%d--%H.%M.%S" "$EPOCHSECONDS")

						# put the old one in the user's trash. Just in case.
					mv -vf "$PLUGIN_INSTALLED_AT" "$HOME/.Trash/ZoomUsPlugIn.$TIME.plugin"

					EXIT="$?"

					if [ "$EXIT" = "0" ]
					then

						mv -vf 'ZoomUsPlugIn.plugin' "$PLUGIN_INSTALLED_AT"

					else

						echo " ! ! ! $NAME: failed to delete old '$PLUGIN_INSTALLED_AT' You will have to do it manually. (\$EXIT = $EXIT)"

							# try to move 'zoom.us.app' to the same dir as the original .pkg file
						mv -vn "ZoomUsPlugIn.plugin" "$INPUT:h"

						EXIT="$?"

						if [ "$EXIT" = "0" ]
						then
							echo "	You can find the current app at '$INPUT:h/ZoomUsPlugIn.plugin' if you want to install it yourself."

						else
							echo "	You can find the current app at '$PWD/ZoomUsPlugIn.plugin' if you want to move it yourself."
						fi

					fi
			;;

		esac
	fi
fi

echo "\n\nI am done now. PWD is '$PWD' if you need anything from it. Otherwise you can delete this folder and probably '$TEMP_DIR' too."

echo "	But you don't have to. It will be cleared out the next time you reboot anyway. I hope you have a nice day.\n"

if [[ -d "$APP_INSTALLED_AT" ]]
then
	APP_VERSION=$(defaults read "$APP_INSTALLED_AT/Contents/Info" CFBundleShortVersionString 2>/dev/null)
fi

if [[ -d "$PLUGIN_INSTALLED_AT" ]]
then
	PLUGIN_VERSION=$(defaults read "$PLUGIN_INSTALLED_AT/Contents/Info" CFBundleShortVersionString 2>/dev/null)
fi

if [ "$APP_VERSION" != "" -a "$PLUGIN_VERSION" != "" ]
then

	if [[ "$APP_VERSION" == "$PLUGIN_VERSION" ]]
	then
		echo "\nYou have installed version '$APP_VERSION' of the zoom.us.app and its plugin."

	else
		echo "\nYou have installed: \n	zoom.us.app version: '$APP_VERSION' \n	plugin version: '$PLUGIN_VERSION'."
	fi

elif [ "$APP_VERSION" != "" ]
then

	echo "\n$NAME: You have installed zoom.us.app version '$APP_VERSION'."

elif [ "$PLUGIN_VERSION" != "" ]
then

	echo "\n$NAME: You have installed zoom.us.app's plugin version '$PLUGIN_VERSION'."

fi

exit 0
#EOF

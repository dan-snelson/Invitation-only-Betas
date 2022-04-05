#!/bin/sh

####################################################################################################
#
#	Property List Writer
#
#	Purpose: Leverages Jamf Pro Script Parameters to write a given string to the specified key
#	in a hard-coded filepath.
#
#	Reference: https://support.apple.com/guide/terminal/edit-property-lists-apda49a1bb2-577e-4721-8f25-ffc0836f6997/mac
#
####################################################################################################
#
# HISTORY
#
# 	Version 0.0.1, 19-Mar-2021, Dan K. Snelson (@dan-snelson)
#		Original version
#
####################################################################################################



####################################################################################################
#
# Variables
#
####################################################################################################

scriptVersion="0.0.1"
scriptResult="Version ${scriptVersion};"
filepath="/Library/Preferences/org.churchofjesuschrist.plist"	# Reverse Domain Name Notation (i.e., "org.churchofjesuschrist")
key="${4}"							# Name of the "key" for which the value will be set
value="${5}"							# The value to which "key" will be set



####################################################################################################
#
# Program
#
####################################################################################################



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Exit if either "key" or "value" are blank
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [ -z "${key}" ] || [ -z "${value}" ]; then

	scriptResult="${scriptResult} Error: Please provide data for both the \"key\" and \"value\";"
	echo "${scriptResult}"
	exit 1

fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Backup Plist File
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# scriptResult="${scriptResult} Backup Plist File; "
# /bin/cp -v ${filepath}{,-backup-$(date '+%Y-%m-%d-%H%M%S')}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Write Plist Value
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

scriptResult="${scriptResult} Write Plist Value;"
/usr/bin/defaults write "${filepath}" "${key}" -string "${value}"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Read Plist Value
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

scriptResult="${scriptResult} Read Plist Value;"
writtenValue=$( /usr/bin/defaults read "${filepath}" "${key}" "${value}" )
scriptResult="${scriptResult} \"${key}\" equals \"${writtenValue}\";"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Exit
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

scriptResult="${scriptResult} End-of-line."
echo "${scriptResult}"
exit 0

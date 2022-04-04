#!/bin/sh
####################################################################################################
#
# ABOUT
#
#	Set a computer's Extension Attribute via the Jamf Pro API
#	https://github.com/dan-snelson/Invitation-only-Betas/wiki
#
####################################################################################################
#
# HISTORY
#
#	Version 1.0, 30-Jul-2016, Dan K. Snelson (@dan-snelson)
#		Original
#	Version 1.1, 17-Oct-2016, Dan K. Snelson (@dan-snelson)
#		Updated to leverage an encyrpted API password
#	Version 1.2, 02-Feb-2022, Dan K. Snelson (@dan-snelson)
#		Updated for openssl 3.3.5 / macOS 12.3
#	Version 1.3, 02-Apr-2022, Dan K. Snelson (@dan-snelson)
#		Standardization updates
#	Version 1.4, 04-Apr-2022, Dan K. Snelson (@dan-snelson)
#		Updated to leverage Bearer Token
#
####################################################################################################



####################################################################################################
#
# Variables
#
####################################################################################################

scriptVersion="1.4"
scriptResult="Version ${scriptVersion};"
apiBearerToken=""
apiURL=$( /usr/bin/defaults read "/Library/Preferences/com.jamfsoftware.jamf.plist" jss_url )
apiUsername="${4}"					# API Username
apiPasswordEncrypted="${5}"				# API Encrypted Password
eaName="${6}"						# Name of Extension Attribute (i.e., "Testing Level")
eaValue="${7}"						# Value for Extension Attribute (i.e., "Gamma" or "None")
Salt="Salt_value_goes_here"				# Salt (generated from Encrypt Password)
Passphrase="Passphrase_value_goes_here"			# Passphrase (generated from Encrypt Password)
computerUDID=$(/usr/sbin/system_profiler SPHardwareDataType | /usr/bin/awk '/Hardware UUID:/ { print $3 }')
osProductVersion=$( /usr/bin/sw_vers -productVersion | /usr/bin/awk -F . '{print $1}' )



####################################################################################################
#
# Functions
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Decrypt Password
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

decryptPassword() {
	/bin/echo "${1}" | /usr/bin/openssl enc -aes256 -md sha256 -d -a -A -S "${2}" -k "${3}"
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Read API Value
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

readApiValue() {
	apiRead=$( curl -H "Accept: text/xml" -sfu "${apiUsername}":"${apiPassword}" "${apiURL}"/JSSResource/computers/udid/"${computerUDID}"/subset/extension_attributes | xmllint --format - | grep -A3 "<name>${eaName}</name>" | awk -F'>|<' '/value/{print $3}' | tail -n 1 )
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Parse JSON string ($1) and return the desired key ($2)
# https://paulgalow.com/how-to-work-with-json-api-data-in-macos-shell-scripts
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

getJsonValue() {
	JSON="$1" /usr/bin/osascript -l 'JavaScript' \
		-e 'const env = $.NSProcessInfo.processInfo.environment.objectForKey("JSON").js' \
		-e "JSON.parse(env).$2"
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Obtain Jamf Pro Bearer Token via Basic Authentication
# https://derflounder.wordpress.com/2022/01/05/
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

obtainJamfProAPIBearerToken() {

	if [ "${osProductVersion}" -lt 12 ]; then
		apiBearerToken=$( /usr/bin/curl -X POST --silent -u "${apiUsername}:${apiPassword}" "${apiURL}/api/v1/auth/token" | /usr/bin/python -c 'import sys, json; print json.load(sys.stdin)["token"]' )
	else
		apiBearerToken=$( /usr/bin/curl -X POST --silent -u "${apiUsername}:${apiPassword}" "${apiURL}/api/v1/auth/token" | /usr/bin/plutil -extract token raw - )
	fi

	# scriptResult="${scriptResult} apiBearerToken: ${apiBearerToken}; "

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Verify API authentication is using a valid Bearer Token; returns the HTTP status code
# https://derflounder.wordpress.com/2022/01/05/
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

validateJamfProAPIBearerToken() {

	apiBearerTokenCheck=$( /usr/bin/curl --write-out %{http_code} --silent --output /dev/null "${apiURL}/api/v1/auth" --request GET --header "Authorization: Bearer ${apiBearerToken}")

	scriptResult="${scriptResult} apiBearerTokenCheck: ${apiBearerTokenCheck}; "

	if [ "${apiBearerTokenCheck}" != 200 ]; then

		scriptResult="${scriptResult} Error: ${apiBearerTokenCheck}; exiting."
		jssLog "${scriptResult}"
		exit 1

	fi

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Validate and optionally renew the Bearer Token; returns the HTTP status code
# https://derflounder.wordpress.com/2022/01/05/
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

validateRenewBearerToken() {

	validateJamfProAPIBearerToken
	
	if [ "${apiBearerTokenCheck}" = "200" ]; then

		if [ "${osProductVersion}" -lt 12 ]; then
			apiBearerToken=$(/usr/bin/curl "${apiURL}/api/v1/auth/keep-alive" --silent --request POST --header "Authorization: Bearer ${apiBearerToken}" | python -c 'import sys, json; print json.load(sys.stdin)["token"]')
		else
			apiBearerToken=$(/usr/bin/curl "${apiURL}/api/v1/auth/keep-alive" --silent --request POST --header "Authorization: Bearer ${apiBearerToken}" | plutil -extract token raw -)
		fi

		scriptResult="${scriptResult} Renewed Bearer Token: ${apiBearerToken}; "


	else

		scriptResult="${scriptResult} Expired Bearer Token; renewing …"

		obtainJamfProAPIBearerToken

	fi

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Invalidate the Bearer Token
# https://derflounder.wordpress.com/2022/01/05/
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

invalidateJamfProAPIBearerToken() {
	
	validateJamfProAPIBearerToken

	if [ "${apiBearerTokenCheck}" == 200 ]; then

		scriptResult="${scriptResult} Bearer Token still valid; invalidate; "

		apiBearerToken=$( /usr/bin/curl "${apiURL}/api/v1/auth/invalidate-token" --silent  --header "Authorization: Bearer ${apiBearerToken}" -X POST )
		apiBearerToken=""

		scriptResult="${scriptResult} Bearer Token invalidated; "

	else

		scriptResult="${scriptResult} Bearer Token already expired; "

	fi

}



####################################################################################################
#
# Program
#
####################################################################################################



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Validate values have been specified for Script Parameters
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if	[ -n "${apiUsername}" ] && \
	[ -n "${apiPasswordEncrypted}" ] && \
	[ -n "${eaName}" ] && \
	[ -n "${eaValue}" ]; then
	# scriptResult="${scriptResult} All script parameters have been specified, proceeding;"

	# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
	# Decrypt API password
	# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

	apiPassword=$( decryptPassword "${apiPasswordEncrypted}" "${Salt}" "${Passphrase}" )

	# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
	# Obtain and validate Jamf Pro API Bearer Token
	# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

	obtainJamfProAPIBearerToken

	validateJamfProAPIBearerToken

	# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
	# Log Extension Attribute name and value 
	# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

	# scriptResult="${scriptResult} Extension Attribute Name: ${eaName};"
	# scriptResult="${scriptResult} Extension Attribute New Value: ${eaValue};"
	
	# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
	# Reset Extension Attribute value
	# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

	if [ "${eaValue}" = "None" ]; then
		scriptResult="${scriptResult} Extension Attribute Value is \"None\", remove value from: ${eaName};"
		eaValue=""
	fi

	# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
	# Read current Extension Attribute Value
	# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
	
	readApiValue

	# scriptResult="${scriptResult} Extension Attribute ${eaName}'s Current Value: ${apiRead};"

	# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
	# Construct the API data
	# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

	apiData="<computer><extension_attributes><extension_attribute><name>${eaName}</name><value>${eaValue}</value></extension_attribute></extension_attributes></computer>"
	
	apiPost=$(curl -H "Content-Type: text/xml" -sfu "${apiUsername}":"${apiPassword}" "${apiURL}"/JSSResource/computers/udid/"${computerUDID}" -d "${apiData}" -X PUT) 

	/bin/echo "${apiPost}" > /dev/null

	# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
	# Read the new Extension Attribute Value
	# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
	
	readApiValue

	# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
	# Log Extension Attribute name and value 
	# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

	if [ -z "${apiRead}" ]; then
		apiRead="None"
	fi
	scriptResult="${scriptResult} ${eaName} changed to ${apiRead};"
	
else
	
	scriptResult="${scriptResult} Error: Parameters 4, 5, 6 and 7 not all populated; exiting."
	echo "${scriptResult}"
	exit 1

fi

invalidateJamfProAPIBearerToken

scriptResult="${scriptResult} End-of-line."

echo "${scriptResult}"

exit 0

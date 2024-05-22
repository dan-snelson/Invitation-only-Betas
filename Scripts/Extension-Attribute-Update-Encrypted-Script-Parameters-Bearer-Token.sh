#!/bin/zsh --no-rcs
# shellcheck shell=bash

####################################################################################################
#
# ABOUT
#
#    Set a computer's Extension Attribute via the Jamf Pro API
#
####################################################################################################
#
# HISTORY
#
#    Version 2.0.0, 17-May-2024, Dan K. Snelson (@dan-snelson)
#        Updated to leverage Bearer Token with Jamf Pro 11.5.0
#
####################################################################################################



####################################################################################################
#
# Variables
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Global
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

export PATH=/usr/bin:/bin:/usr/sbin:/sbin

# Script Version
scriptVersion="2.0.0"

# Client-side Log
scriptLog="/var/log/org.churchofjesuschrist.log"

# Jamf Pro API URL
apiURL=$( defaults read /Library/Preferences/com.jamfsoftware.jamf.plist jss_url )



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Jamf Pro Script Parameters
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Parameter 4: Jamf Pro API Username
apiUser="${4:-"Jamf Pro API Username"}"

# Parameter 5: Jamf Pro API Encrypted Password (generated from Encrypt Password)
apiPasswordEncrypted="${5:-"Jamf Pro API Encrypted Password"}"

# Parameter 6: Extension Attribute Name
eaName="${6:-"Testing Level"}"

# Parameter 7: Extension Attribute Value
eaValue="${7:-"None"}"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Organization Variables
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Script Human-readable Name
humanReadableScriptName="Extension Attribute Update"

# Abbreviated Script Name
organizationScriptName="EA Update"

# Salt (generated from Encrypt Password)
Salt="salt_goes_here"

# Passphrase (generated from Encrypt Password)
Passphrase="passphrase_goes_here"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Operating System Variables
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

osVersion=$( sw_vers -productVersion )
osVersionExtra=$( sw_vers -productVersionExtra ) 
osBuild=$( sw_vers -buildVersion )
osMajorVersion=$( echo "${osVersion}" | awk -F '.' '{print $1}' )
if [[ -n $osVersionExtra ]] && [[ "${osMajorVersion}" -ge 13 ]]; then osVersion="${osVersion} ${osVersionExtra}"; fi
serialNumber=$( ioreg -rd1 -c IOPlatformExpertDevice | awk -F'"' '/IOPlatformSerialNumber/{print $4}' )



####################################################################################################
#
# Functions
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Client-side Logging
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function updateScriptLog() {
    echo "${organizationScriptName} ${scriptVersion}: $( date +%Y-%m-%d\ %H:%M:%S ) - ${1}" | tee -a "${scriptLog}"
}

function preFlight() {
    updateScriptLog "[PRE-FLIGHT]      ${1}"
}

function logComment() {
    updateScriptLog "                  ${1}"
}

function notice() {
    updateScriptLog "[NOTICE]          ${1}"
}

function info() {
    updateScriptLog "[INFO]            ${1}"
}

function debug() {
    if [[ "$operationMode" == "debug" ]]; then
        updateScriptLog "[DEBUG]           ${1}"
    fi
}

function errorOut(){
    updateScriptLog "[ERROR]           ${1}"
}

function error() {
    updateScriptLog "[ERROR]           ${1}"
    let errorCount++
}

function warning() {
    updateScriptLog "[WARNING]         ${1}"
    let errorCount++
}

function fatal() {
    updateScriptLog "[FATAL ERROR]     ${1}"
    exit 1
}

function quitOut(){
    updateScriptLog "[QUIT]            ${1}"
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Decrypt Password
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function decryptPassword() {
    echo "${1}" | openssl enc -aes256 -md sha256 -d -a -A -S "${2}" -k "${3}"
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Obtain Jamf Pro Bearer Token via Basic Authentication
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function obtainJamfProAPIBearerToken() {

    if [[ "${osVersion}" -lt 12 ]]; then
        apiBearerToken=$( curl -X POST --silent -u "${apiUsername}:${apiPassword}" "${apiURL}/api/v1/auth/token" | python -c 'import sys, json; print json.load(sys.stdin)["token"]' )
    else
        apiBearerToken=$( curl -X POST -s -u "${apiUser}:${apiPassword}" "${apiURL}/api/v1/auth/token" | plutil -extract token raw - )
    fi

	# logComment "apiBearerToken: ${apiBearerToken}"

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Verify API authentication is using a valid Bearer Token; returns the HTTP status code
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function validateJamfProAPIBearerToken() {

    apiBearerTokenCheck=$( curl --write-out %{http_code} --silent --output /dev/null "${apiURL}/api/v1/auth" --request GET --header "Authorization: Bearer ${apiBearerToken}")

    logComment "apiBearerTokenCheck: ${apiBearerTokenCheck}"

    if [[ "${apiBearerTokenCheck}" != 200 ]]; then
        fatal "Error: ${apiBearerTokenCheck}; exiting."
    fi

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Validate and optionally renew the Bearer Token; returns the HTTP status code
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function validateRenewBearerToken() {

    validateJamfProAPIBearerToken
    
    if [[ "${apiBearerTokenCheck}" = "200" ]]; then

        if [[ "${osProductVersion}" -lt 12 ]]; then
            apiBearerToken=$( curl "${apiURL}/api/v1/auth/keep-alive" --silent --request POST --header "Authorization: Bearer ${apiBearerToken}" | python -c 'import sys, json; print json.load(sys.stdin)["token"]')
        else
            apiBearerToken=$( curl "${apiURL}/api/v1/auth/keep-alive" --silent --request POST --header "Authorization: Bearer ${apiBearerToken}" | plutil -extract token raw -)
        fi

        logComment "Renewed Bearer Token: ${apiBearerToken}"


    else

        logComment "Expired Bearer Token; renewing …"

        obtainJamfProAPIBearerToken

    fi

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Invalidate the Bearer Token
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function invalidateJamfProAPIBearerToken() {
    
    validateJamfProAPIBearerToken

    if [[ "${apiBearerTokenCheck}" == 200 ]]; then

        logComment "Bearer Token still valid; invalidate …"

        apiBearerToken=$( curl "${apiURL}/api/v1/auth/invalidate-token" --silent  --header "Authorization: Bearer ${apiBearerToken}" -X POST )
        apiBearerToken=""

        logComment "Bearer Token invalidated"

    else

        logComment "Bearer Token already expired"

    fi

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Extension Attribute Read
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function extensionAttributeRead() {

    notice "Read Extension Attribute …"
    apiRead=$( curl -H "Authorization: Bearer ${apiBearerToken}" -H "Accept: text/xml" -s "${apiURL}"/JSSResource/computers/id/"${jssID}"/subset/extension_attributes | xmllint --format - | grep -A3 "<name>${eaName}</name>" | awk -F'>|<' '/value/{print $3}' | tail -n 1 )
    # logComment "${eaName}: ${eaValue}"

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Extension Attribute Write
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function extensionAttributeWrite() {

    notice "Write Extension Attribute '${eaName}' to '${eaValue}' …"
    apiData="<computer><extension_attributes><extension_attribute><name>${eaName}</name><value>${eaValue}</value></extension_attribute></extension_attributes></computer>"
    apiPost=$( curl -H "Authorization: Bearer ${apiBearerToken}" -H "Content-Type: text/xml" -s "${apiURL}"/JSSResource/computers/id/"${jssID}" -d "${apiData}" -X PUT )
    /bin/echo "${apiPost}" > /dev/null

}



####################################################################################################
#
# Pre-flight Checks
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Client-side Logging
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ ! -f "${scriptLog}" ]]; then
    touch "${scriptLog}"
    if [[ -f "${scriptLog}" ]]; then
        preFlight "Created specified scriptLog"
    else
        fatal "Unable to create specified scriptLog '${scriptLog}'; exiting.\n\n(Is this script running as 'root' ?)"
    fi
else
    preFlight "Specified scriptLog exists; writing log entries to it"
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Logging Preamble
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

preFlight "\n\n###\n# ${humanReadableScriptName} [${organizationScriptName} (${scriptVersion})]\n# Setting '${eaName}' to '${eaValue}'\n###\n"
preFlight "Initiating …"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Confirm script is running as root
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ $(id -u) -ne 0 ]]; then
    fatal "This script must be run as root; exiting."
else
	logComment "Running as root; proceeding …"
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Complete
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

preFlight "Complete!"



####################################################################################################
#
# Program
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Obtain Bearer Token
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

notice "Obtain Bearer Token …"

apiPassword=$( decryptPassword "${apiPasswordEncrypted}" "${Salt}" "${Passphrase}" )

obtainJamfProAPIBearerToken

validateJamfProAPIBearerToken



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Obtain the Computer’s Jamf Pro Computer ID via the API
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

jssID=$( curl -H "Authorization: Bearer ${apiBearerToken}" -s "${apiURL}"/JSSResource/computers/serialnumber/"${serialNumber}"/subset/general | xpath -e "/computer/general/id/text()" )

logComment "jssID: ${jssID}"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Read the Extension Attribute's Current Value
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

extensionAttributeRead
logComment "Extension Attribute ${eaName}'s Current Value: ${apiRead}"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Reset Extension Attribute value
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ "${eaValue}" = "None" ]]; then
    logComment "Extension Attribute Value is \"None\", remove value from: ${eaName}"
    eaValue=""
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Write the Extension Attribute's New Value
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

extensionAttributeWrite



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Read the Extension Attribute's New Value
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
    
extensionAttributeRead
logComment "Extension Attribute ${eaName}'s New Value: ${apiRead}"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Log Extension Attribute name and value 
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ -z "${apiRead}" ]]; then
    apiRead="None"
fi
logComment "${eaName} changed to ${apiRead}"




# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Exit
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

invalidateJamfProAPIBearerToken

logComment "End-of-line."

exit 0

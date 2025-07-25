#!/bin/bash


getCertSHA1() {
    # Get the SHA1 of the machine certs
    # This command lists all certificates in the System keychain that match the computer name
    # and outputs their SHA-1 hashes.
    /usr/bin/security find-certificate -a -c $CompName -p -Z "/Library/Keychains/System.keychain" | grep SHA-1
}

getOldCert() {
    # Get the SHA1 of the machine certs, skip the first line (which should be the newest cert)
    getCertSHA1 | awk '{print $3}' | tail -r | tail +2 | tail -r
}

# Declare variables
CompName=$(hostname)
CertCount=$(getCertSHA1 | wc | awk '{print $1}')

# Search for and clean up extra machine certificates until only the newest remains
if [ $CertCount == 1 ]; then
    exit 0          
elif [ $CertCount == 0 ]; then 
    echo "Computer does not have a machine cert for name $CompName"
    exit 0                  
else
    echo "Found $CertCount machine certs for name $CompName"
    echo "Deleting all but the newest:"        
    oldCert=$(getOldCert)
    while [ "$oldCert" != "" ]; do
        oldCert=$(getOldCert)
        echo "Deleting old machine cert: $oldCert"
        security delete-certificate -Z $oldCert /Library/Keychains/System.keychain &2>/dev/null
    done                                                                                            
fi
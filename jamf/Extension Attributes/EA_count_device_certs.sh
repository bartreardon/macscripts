#!/bin/bash
getCertSHA1() {
    /usr/bin/security find-certificate -a -c $CompName -p -Z "/Library/Keychains/System.keychain" | grep SHA-1
}

CompName=$(hostname)
CertCount=$(getCertSHA1 | wc | awk '{print $1}')

echo "<result>${CertCount}</result>"
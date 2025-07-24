#!/bin/bash

function getItem () {
	echo $(echo $1 | grep $2 | awk '{split($0,a,"="); print a[2]}' | sed -e 's/"//g')
}

echo "Enter the username to check for:"
read -p "Username: " username
echo "Enter the new password:"
read -s -p "Password: " password
echo ""

#get list of internet and general items
inetItems=$(security dump-keychain | grep inet -B1 -A21 | sed -e 's/--/;/g')
#genpItems=$(security dump-keychain | grep genp -B1 -A17 | sed -e 's/--/;/g')

IFS=";"

for item in $inetItems
do
    #extract acct  
    itemACCT=$(getItem $item acct)
    
    if [[ $itemACCT == "$username" ]]; then   	
		# item name
		itemName=$(getItem $item 0x00000007) 
		echo "processing $itemName"
		
		# item protocol
		itemPTCL=$(getItem $item ptcl)  
	
		# item server value
		itemSRVR=$(getItem $item srvr) 
		
		# item description, aka kind
		itemKIND=$(getItem $item desc)
		if [[ $itemKIND == "<NULL>" ]]; then
			itemKIND="Internet password"
		fi
		
		#should have everything we need now to update the password to what we want.
		security add-internet-password -a $username -s "$itemSRVR" -w "$password" -r "$itemPTCL" -l "$itemName" -j "default" -D "$itemKIND" -U  
		if [[ $? != 0 ]]; then
			echo "something went wrong"
		else
			echo "$itemName updated"
		fi
	fi    
done

echo "done"

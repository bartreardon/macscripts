on createAccount(theAccount, theAccountName, theAccountPassword)
       -- handler that creates an administrator account
      
       set userIcon to "/Library/User\\ Pictures/CustomUserPic.tiff"
       
       -- check to see if the account already exists
       
       set accountExists to false
       
       -- see if the account exists
       try
           set accountExists to true
           runCommand("dscl . -read /Users/" & theAccount & " UniqueID")
           on error
               set accountExists to false
               -- updateLogWindow("creating account " & theAccount)
       end try
       
       if accountExists then
           -- just change the password to the one specified
           -- updateLogWindow("account " & theAccount & " already exists - setting password")
           runCommand("/usr/bin/dscl . passwd /Users/" & theAccount & " '" & theAccountPassword & "'")
           -- updateLogWindow(theAccount &" password updated")
           return 1
       end if
       
       -- determine a valid available user id and group id starting at 400
       -- accounts with ID less than 500 will be hidden
       
       set new_uid to 0
       set new_gid to 0
       set i to 400
       set idvar to 0
       
       repeat while idvar = 0
           set i to i + 1
           set new_uid to (do shell script "/usr/bin/dscl . -search /Users uid " & i & " | grep " & i & "; exit 0")
           set new_gid to (do shell script "/usr/bin/dscl . -search /Groups gid " & i & " | grep " & i & "; exit 0")
           if (new_uid is "") and (new_gid is "") then
               set idvar to 1
               set new_uid to i
               set new_gid to i
               -- display dialog "new ID is " & i & return & "new group is " & i
           end if
       end repeat
       
       --check if the profile icon exists in the right location
       set userIcon to "/Library/User Pictures/CustomUserPic.tiff"
       try
           runCommand("ls /Library/User\\ Pictures/CustomUserPic.tiff")
           on error
           try
               runCommand("curl http://somewhere.org/some/location/CustomUserPic.tiff -o /Library/User\\ Pictures/CustomUserPic.tiff")
               on error
               set userIcon to "/Library/User Pictures/Animals/Butterfly.tif"
           end try
       end try
         
       -- Create the account
       
       runCommand("dscl . -create '/Users/" & theAccount & "'")
       runCommand("dscl . -append '/Users/" & theAccount & "' RealName \"" & theAccountName & "\"")
       runCommand("dscl . -append '/Users/" & theAccount & "' NFSHomeDirectory '/var/" & theAccount & "'")
       runCommand("dscl . -append '/Users/" & theAccount & "' UserShell /bin/bash")
       runCommand("dscl . -append '/Users/" & theAccount & "' PrimaryGroupID " & new_gid & "")
       runCommand("dscl . -append '/Users/" & theAccount & "' UniqueID " & new_uid & "")
       --runCommand("dscl . -append '/Users/" & theAccount & "' hint")
       runCommand("dscl . -append '/Users/" & theAccount & "' comment 'user account \"" & theAccountName & "\" created: " & date string of (current date) & "'")
       runCommand("dscl . -append '/Users/" & theAccount & "' picture '" & userIcon & "'")
       runCommand("dscl . -append '/Users/" & theAccount & "' sharedDir Public")
       runCommand("dscl . -passwd '/Users/" & theAccount & "' '" & theAccountPassword & "'")
       
       runCommand("dscl . -append /Groups/staff GroupMembership '" & theAccount & "'")
       
       # add the new user to the admin group
       runCommand("dscl . -append /Groups/admin GroupMembership '" & theAccount & "'")
       
       runCommand("/usr/sbin/createhomedir -l -u '" & theAccount & "'")
       
       
   end createAccount
  
  
   on runCommand(theCommand)
       -- handler for running commands as shell and determining if the user is root or not
       -- need to do this as we might be running this as system or a local admin and we need to diferentiate
       
       do shell script "echo $EUID"
       set theEUID to result
       
       if theEUID is "0" then
           set runningAsRoot to true
       else
           set runningAsRoot to false
       end if
       
       try
           if runningAsRoot then
               do shell script theCommand
           else
               do shell script theCommand with administrator privileges
           end if
           
           on error errMsg number errNum
               error errMsg number errNum
       end try
           
   end runCommand

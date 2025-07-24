#!/bin/zsh

# EA to check if MDM enrolment is working

logResults=$(sudo log show --style compact --predicate '(process CONTAINS "mdmclient")' --last 15m | grep "Unable to create MDM identity")
exitcode=$?

if [[ $exitcode -eq 0 ]] || [[ -n ${logResults} ]]; then
  echo "<result>MDM is Broken</result>"
else
  echo "<result>MDM is Healthy</result>"
fi
#!/bin/bash
# A script to convert a CSV (excel export) file into JSON
# Usage ./csv2json input.csv > output.json
# Slightly modified version of SECAGUY's: 
# http://blog.secaserver.com/2013/12/convert-csv-json-bash/

input=$1

[ -z $1 ] && echo "No CSV input file specified" && exit 1
[ ! -e $input ] && echo "Unable to locate $1" && exit 1

read first_line < $input
a=0
headings=`echo $first_line | awk -F, {'print NF'}`
lines=`cat $input | wc -l`
while [ $a -lt $headings ]
do
        head_array[$a]=$(echo $first_line | awk -v x=$(($a + 1)) -F"," '{print $x}')
        a=$(($a+1))
done

c=0
echo "["
while [ $c -lt $lines ]
do
        read each_line
        if [ $c -ne 0 ]; then
                d=0
                echo -n "{"
                while [ $d -lt $headings ]
                do
                        each_element=$(echo $each_line | awk -v y=$(($d + 1)) -F"," '{print $y}')
                        if [ $d -ne $(($headings-1)) ]; then
                                echo -n "\""${head_array[$d]}"\":\""$each_element"\","
                        else
                                echo -n "\""${head_array[$d]}"\":\""$each_element"\""
                        fi
                        d=$(($d+1))
                done
                if [ $c -eq $(($lines-1)) ]; then
                        echo "}"
                else
                        echo "},"
                fi
        fi
        c=$(($c+1))
done < $input
echo "]"
echo ""
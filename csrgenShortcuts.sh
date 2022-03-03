#!/bin/bash

testFunktion(){
    declare -g GLOBAL_VAR="GLOBAL VAR"
}
testFunktion
case $1 in
-t) printf "%s start testing ${GLOBAL_VAR} \n" ;;
*)  printf "normaler Weg" ;;
esac
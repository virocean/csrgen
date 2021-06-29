#!/bin/bash
# 
    FOLDER=~/Zertifikate/ #The .csr&.key files will be created here 
    USER=DWE           #Important for the "old_" Folder       
    echo "##WELCOME TO CSRGen##"
    echo ""
#
# 1) Reading the Name of the Domain the Cert is being made for
#
    echo "First name the Domain you want to create a csr for."
    echo "If its a SAN Certificate, just enter the name of the main domain."
    echo "Format: domain.de"
    echo -n "Domain: "
    read -r DOMAIN
    echo ""
# 
# 2) Choosing Cert Type and confirming
#
    echo "Now let's choose the certificate type."
    echo "These are the Options:"
    echo    "1.) AlphaSSL"      
    echo    "2.) Wildcard"      
    echo    "3.) SAN (Mit oder ohne EV)"           
    echo    "4.) LetsEncrypt"
    echo    "5.) GeoTrust EV"
    echo -n "1, 2 ,3, 4 or 5?: "
    read -r TYPE
    #
    if [ "${TYPE}" -eq 1 ] || [ "${TYPE}" -eq 5 ]; then
        PREFIX="www."
    elif [ "${TYPE}" -eq 2 ]; then
        PREFIX="wc."
        CN="*."
    #Now choosing if its an EV or not   
        echo "Is it an Certificate with Extended Validation (EV)?"
        echo -n "yes/no: "
        read -r EV
    elif [ "${TYPE}" -eq 3 ]; then
        PREFIX="san."
    elif [ "${TYPE}" -eq 4 ]; then
        echo "LetsEncrypt Zertifikate werden über service2 ausgestellt: "
        echo "https://service2.continum.net/services/ssl-certificates"
        nemo "https://service2.continum.net/services/ssl-certificates" #add asking feature
        exit
    else 
        echo "Number not betweeen 1 and 5, try again."
    fi
    #
    echo ""
    echo "Heres your inputs:"
    echo "Domain:    ""$DOMAIN"
    echo -n "Cert Type: "
        if [ "${TYPE}" -eq 1 ]; then
            echo "AlphaSSL"
        elif [ "${TYPE}" -eq 2 ]; then
            echo "Wildcard"
        elif [ "${TYPE}" -eq 3 ]; then
            echo "SAN"
        elif [ "${TYPE}" -eq 5 ]; then
            echo "Geotrust"
        fi
    echo -n "EV:        "
        if [ "${EV}" = yes ] || [ "${TYPE}" -eq 5 ]; then
            echo "Yes"
        else 
            echo "No"
        fi
    echo ""
#
# 3) Creating dedicated Folder an executing the keygen-commands in it
#
    DATE=$(date +"%Y.%m.%d")
    DIRECTORY=$FOLDER$DATE-$PREFIX$DOMAIN/
    mkdir "$DIRECTORY"
    cd "$DIRECTORY" || return
    if [ "${TYPE}" -eq 3 ]; then
        echo -n "Land: (Bsp: DE) "
        read -r LAND
        echo -n "Bundesland: "
        read -r BUNDESLAND
        echo -n "Stadt: "
        read -r STADT
        echo -n "Firmenname: "
        read -r FIRMENNAME
        echo -n "Abteilungsname: "
        read -r ABTEILUNGSNAME
        printf "[req]\ndistinguished_name = req_distinguished_name\nreq_extensions = v3_req\nprompt = no\n[req_distinguished_name]\nC = %s\nST = %s\nL = %s\nO = %s\nOU = %s\nCN = %s\n[v3_req]\nkeyUsage = keyEncipherment, dataEncipherment\nextendedKeyUsage = serverAuth\nsubjectAltName = @alt_names\n[alt_names]\n" "${LAND}" "${BUNDESLAND}" "${STADT}" "${FIRMENNAME}" "${ABTEILUNGSNAME}"  "${DOMAIN}" >> openssl.conf
        echo -n "Weitere Domainnamen getrennt mit einem Leerzeichen: "
        read -r SANDOMAINS
        COUNTER=0
        for DNS in ${SANDOMAINS}
        do
            (( COUNTER++ )) || true
            echo "DNS.${COUNTER} = ${DNS}" >> openssl.cnf
            openssl genrsa -out san."$DOMAIN".key 2048
            openssl req -new -out san."$DOMAIN".csr -key san."$DOMAIN".key -config openssl.cnf
            openssl req -text -noout -in san."$DOMAIN".csr
        done
    #
    # Goes here if its an "EV" or Type 5(Geotrust), asks for Parameters
    # and then gernerates csr & key with the last Command 
    elif [ "${EV}" = yes ] || [ "${TYPE}" -eq 5 ]; then
        echo -n "Land: (Bsp: DE) "
        read -r LAND
        echo -n "Bundesland: "
        read -r BUNDESLAND
        echo -n "Stadt: "
        read -r STADT
        echo -n "Firmenname: "
        read -r FIRMENNAME
        echo -n "Abteilungsname: "
        read -r ABTEILUNGSNAME
        openssl req -new -newkey rsa:2048 -nodes -sha256 -utf8 -subj "/C=${LAND}/ST=${BUNDESLAND}/L=${STADT}/O=${FIRMENNAME}/OU=${ABTEILUNGSNAME}/CN=${PREFIX}${DOMAIN}" -keyout  $PREFIX"$DOMAIN".key -out $PREFIX"$DOMAIN".csr
    #   
    # Goes here if type is AlphaSSl or Wildcard (if not EV nor SAN nor Geotrust)
    else    # elif [ "${EV}" = no ]; then
        openssl req -new -newkey rsa:2048 -nodes -sha256 -utf8 -subj "/C=DE/CN=$CN$PREFIX$DOMAIN" -keyout $PREFIX"$DOMAIN".key -out $PREFIX"$DOMAIN".csr
    fi
    touch "$DIRECTORY""$PREFIX""$DOMAIN".crt
    touch "$DIRECTORY""$PREFIX""$DOMAIN".pem
    touch "$DIRECTORY""$PREFIX""$DOMAIN".intermediate.crt
    mkdir "$DIRECTORY"old_"$DATE"_"$USER"
    touch "$DIRECTORY"Notizen
    printf "DOMAIN: ""$DOMAIN""%s\n\nTXT-Record: \n" | cat >> Notizen
    cat "$DIRECTORY""$PREFIX""$DOMAIN".key >> "$DIRECTORY""$PREFIX""$DOMAIN".pem
    echo ""
    echo ""
    cat "$DIRECTORY"*csr
    #
    #Opening the old cert file
    # find ~/git -name "*schuelerbefoerderung*.*"
    printf "\n\nIf its a Certrenewal the old files may be around here: "
    FINDINGS=$(find ~/git -name "*$DOMAIN*.*")
    echo "$FINDINGS"
    nemo "$FINDINGS"
    nemo "$DIRECTORY"
    printf "\n\nWant me to open the Directory in vscode and the Browser for you?\nyes/no: "
    read -r ANSWER
    if [ "${ANSWER}" == "yes" ]; then
    code "$DIRECTORY"
    firefox "$DOMAIN" 
    firefox https://gui.cps-datensysteme.de/group.php/sslcert/create/sslcert?step=0&
    elif [ "${ANSWER}" == "no" ]; then
    printf "Okay, i will not open them."
    else
    printf "This didnt work, but you should be able to do the last steps on your own. I believe in you."
    fi
    exit
#
# TO-Do: Create Notes
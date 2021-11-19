#!/bin/bash
#
# 0) Checks if configfile and Zertifikate-Folder exists and if not creates them
#
##### IF config exists then source it, else create it
#shellcheck source=/dev/null
    CONFIG=~/.csrgen.conf
    if [ ! -e ${CONFIG} ]; then touch ${CONFIG}
        printf "\nDu hast noch keine Konfig, wie ist dein MA-Kuerzel? (z.B CSI):  "; read -r USERKUERZEL
        printf "Wie ist dein Vorname? (Der kommt in das E-Mailtemplate):\t";         read -r VORNAME
        printf "Wie ist dein Nachname?: \t\t\t\t\t" ;                                read -r NACHNAME
        printf "In welchen Folder sollen die CSRs? (Pfad ab HOME angeben): ";        read -r FOLDER; FOLDER=~/${FOLDER}
        printf "Und jetzt noch kurz deine Sozialversicherungsnummer?:\t\t";          sleep 3s
        printf "\n\nSpaß, der Name hat gereicht.\n";                                 sleep 2s
        printf "#!/bin/bash\n%sFOLDER=$FOLDER\nUSERKUERZEL=${USERKUERZEL}\nUSER=\'${VORNAME} ${NACHNAME}'\n" \
        > ${CONFIG}
    fi 
    source ${CONFIG}
    clear
##### If Folder exists then do nothing (: = Do nothing) else create it
    if [[ -e ${FOLDER} ]]; then :
    else mkdir "$FOLDER"
    fi
##Function to ask for yes or no
askForYesOrNo () {
    if [ "${ALREADYASKED}" == "yes" ]; then :
    else printf "\nyes / no: "
    fi
    read -r INPUT
    if   [ "${INPUT}" == "yes" ] || [ "${INPUT}" == "y" ]; then ANSWER="yes"
    elif [ "${INPUT}" == "no" ]  || [ "${INPUT}" == "n" ]; then :
    else
    printf "\"yes\" or \"no\": "
    ALREADYASKED="yes"
    askForYesOrNo
    fi
}
#
# 1) Reading the Name of the Domain the Cert is being made for
#
    printf "\n\n##WELCOME TO CSRGen##\n"; sleep 0.5s
    printf "\n1) Is the csr for a subdomain? (Forexample cloud.domain.de)(not www.)"
    askForYesOrNo
    if [ "${ANSWER}" == "yes" ]
    then printf "\nFormat: subdomain.domain.tld"; SUBDOMAIN="yes"
    else printf "\nFormat: (NOT www.)domain.tld"; SUBDOMAIN="no"
    fi
    printf "\nName the Domainname: "; read -r DOMAIN
#
# 2) Choosing Cert type and determining prefix for Filename
#
    printf "\n\n2) Choose the certificate type.\n"
    printf "These are the Options:\n"
    printf "AlphaSSL          = 1\n"; AlphaSSL=1
    printf "Wildcard          = 2\n"; Wildcard=2
    printf "SAN               = 3\n"; SAN=3
    printf "LetsEncrypt       = 4\n"; LetsEncrypt=4
    printf "GeoTrust EV       = 5\n"; GeoTrust_and_EV=5
    printf "\nEnter 1 - 5: "        ; read -r CERTIFICATE_TYPE
####Checks what kind of Subdomain and Prefix have to be used
#### Subomain will be entered into the Cert, Prefix determines part of the Filename.
    if [ "${CERTIFICATE_TYPE}" -eq "${AlphaSSL}" ] || [ "${CERTIFICATE_TYPE}" -eq "${GeoTrust_and_EV}" ]; 
        then                                                #If Type AlphaSSl or Wildcard then check for a subdomain first,
        if [ "${SUBDOMAIN}" == "yes" ]; then PREFIX=""      #If theres a subdomain then leave prefix empty
	    else PREFIX="www." CN="www."                        #else just put www. as prefix and as CN
        fi
    elif [ "${CERTIFICATE_TYPE}" -eq "${SAN}" ];         then PREFIX="san."
    elif [ "${CERTIFICATE_TYPE}" -eq "${Wildcard}" ];    then PREFIX="wc." CN="*."
    printf "Is it an Certificate with Extended Validation (EV)?\nyes/no: "; read -r EV
    elif [ "${CERTIFICATE_TYPE}" -eq "${LetsEncrypt}" ]; then
####Promts to a Web-Link if its a LetsEncryptcertificate
        printf "\n\nYou can order LetsEncrypt Certificates via Service2"
	    printf "\nWant me to open firefox for you?\nyes/no: "
        askForYesOrNo
	    if  [ "${ANSWER}" == "yes" ]
        then firefox "https://service.continum.net/services/ssl-certificates\n\n" exit
        else printf "Alright, heres the Link:\nhttps://service.continum.net/services/ssl-certificates\n\nBye!"; exit
        fi
    else printf "Number not betweeen 1 and 5, try again.\n  exiting.."; exit
    fi
#
# 3) Creating dedicated Folder an executing the keygen-commands in it
#
    DATE=$(date +"%Y.%m.%d")
    DIRECTORY=$FOLDER$DATE-$PREFIX$DOMAIN/
    mkdir "$DIRECTORY"
    cd    "$DIRECTORY" || return
##If SAN
    if [ "${CERTIFICATE_TYPE}" -eq "${SAN}" ]; then
        printf "\nLand: (Bsp: DE) "; read -r LAND
        printf "Bundesland:     "  ; read -r BUNDESLAND
        printf "Stadt:          "  ; read -r STADT
        printf "Firmenname:     "  ; read -r FIRMENNAME
        printf "Abteilungsname: "  ; read -r ABTEILUNGSNAME
####This just prints the needed variables into the file openssl.conf, wich will be used to generate the SAN-csr
        printf "[req]\ndistinguished_name = req_distinguished_name\
        \nreq_extensions = v3_req\nprompt = no\n[req_distinguished_name]\
        \nC = %s\nST = %s\nL = %s\nO = %s\nOU = %s\nCN = %\
        s\n[v3_req]\nkeyUsage = keyEncipherment, dataEncipherment\
        \nextendedKeyUsage = serverAuth\nsubjectAltName = @alt_names\n[alt_names]\n" \
        "${LAND}" "${BUNDESLAND}" "${STADT}" "${FIRMENNAME}" "${ABTEILUNGSNAME}" "${DOMAIN}" >> openssl.cnf
        printf "\nWeitere Domainnamen getrennt mit einem Leerzeichen: " ; read -r SANDOMAINS
        COUNTER=0
        for FQDN in ${SANDOMAINS}
        do
            (( COUNTER++ )) || true
            printf "%sDNS.${COUNTER} = ${FQDN}" >> openssl.cnf
            openssl genrsa -out san."$DOMAIN".key 2048
            openssl req -new -out san."$DOMAIN".csr -key san."$DOMAIN".key -config openssl.cnf
            openssl req -text -noout -in san."$DOMAIN".csr
        done
##If EV or Geotrust
    elif [ "${EV}" = yes ] || [ "${CERTIFICATE_TYPE}" -eq "${GeoTrust_and_EV}" ]; then
        printf "\nLand: (Bsp: DE) "; read -r LAND
        printf "Bundesland:     ";   read -r BUNDESLAND
        printf "Stadt:          ";   read -r STADT
        printf "Firmenname:     ";   read -r FIRMENNAME
        printf "Abteilungsname: ";   read -r ABTEILUNGSNAME
        openssl req -new -newkey rsa:2048 -nodes -sha256 -utf8 -subj \
        "/C=${LAND}/ST=${BUNDESLAND}/L=${STADT}/O=${FIRMENNAME}/OU=${ABTEILUNGSNAME}/CN=$PREFIX${DOMAIN}" \
        -keyout  $PREFIX"$DOMAIN".key -out $PREFIX"$DOMAIN".csr
##If AlphaSSl or Wildcard (if not SAN nor EV nor Geotrust)
    else    # elif [ "${EV}" = no ]; then
        openssl req -new -newkey rsa:2048 -nodes -sha256 -utf8 -subj \
        "/C=DE/CN=$CN$DOMAIN" -keyout $PREFIX"$DOMAIN".key -out $PREFIX"$DOMAIN".csr
    fi
    clear
#####Prints out inputs
    printf "\nHeres your inputs:\n  Domain:       %s$DOMAIN""\n  Cert Type:    "
    if   [ "${CERTIFICATE_TYPE}" -eq "${AlphaSSL}" ];        then printf "AlphaSSL\n"
    elif [ "${CERTIFICATE_TYPE}" -eq "${Wildcard}" ];        then printf "AlphaSSL Wildcard\n"
    elif [ "${CERTIFICATE_TYPE}" -eq "${SAN}" ];             then printf "SAN\n"
    elif [ "${CERTIFICATE_TYPE}" -eq "${GeoTrust_and_EV}" ]; then printf "Geotrust\n"
    fi
    printf "  EV:           "
    if [ "${EV}" = yes ] || [ "${CERTIFICATE_TYPE}" -eq "${GeoTrust_and_EV}" ];
        then printf "Yes\n";
        else printf "No\n"
    fi
    printf ""
##Creates all the files in the dedicated directory
    FILENAME="$DIRECTORY""$PREFIX""$DOMAIN"
    touch \    
        "${FILENAME}".crt \
	    "${FILENAME}".pem \
	    "${FILENAME}".int \
	    "$DIRECTORY"Notizen
    mkdir "$DIRECTORY"old_"$DATE"_"$USERKUERZEL"
#####Adding right type into the notes
    if   [ "${CERTIFICATE_TYPE}" -eq "${AlphaSSL}" ];        then CERTIFICATE_TYPEWRITTEN="AlphaSSL"
    elif [ "${CERTIFICATE_TYPE}" -eq "${Wildcard}" ];        then CERTIFICATE_TYPEWRITTEN="AlphaSSL Wildcard"
    elif [ "${CERTIFICATE_TYPE}" -eq "${SAN}" ];             then CERTIFICATE_TYPEWRITTEN="SAN"
    elif [ "${CERTIFICATE_TYPE}" -eq "${GeoTrust_and_EV}" ]; then CERTIFICATE_TYPEWRITTEN="Geotrust EV"
    fi
#####Creating the text in the notes
    { printf "%sDomain: ""$CN$DOMAIN""%s\n\nTXT-Record: \n\n\nHallo, der Serviceauftrag wurde erledigt."; \
    printf "%s\n\n@BO Hier sind die zugehörigen SSL-Zertifikatsdaten für $CN$DOMAIN\n\n\tDomain:\t\t$CN$DOMAIN\n\t"; \
    printf "%sErstellt:\t\t\t\n\tExpire:\t\t\t\n\Type:\t\t\t${CERTIFICATE_TYPEWRITTEN}\n"; \
    printf "\tApprover-type:\t\n\tObjectID:\t\t\n\n<BILD>\n\n"; \
    printf "%sViele Grüße\n${USER} \n"; } >> Notizen
    cat "$DIRECTORY""$PREFIX""$DOMAIN".key >> "$DIRECTORY""$PREFIX""$DOMAIN".pem
    printf "\n\n"
    cat "$DIRECTORY"*csr
    printf "\n\n##Heres the Nameservers::\n "
    dig ns "$DOMAIN" | grep -A 2 'ANSWER SECTION'
#####Opening the old cert file
    printf "\n\nIf its a Certrenewal the old files may be around here: \n"
    FINDINGS=$(find ~/git/puppet/ -name "$DOMAIN*.*"  | grep -E 'prod|legacy' | grep -E 'pem|crt'); printf "%s$FINDINGS"
    printf "\n\nWant me to open the Directory in vscode and the Browser for you? "; 
    askForYesOrNo
    if [ "${ANSWER}" == "yes" ]; then
    	nemo --no-default-window "$DIRECTORY";
    	code "$DIRECTORY"
   	    firefox "$DOMAIN"
    	firefox "https://service.continum.net/services/dns/index"
    	firefox "https://gui.cps-datensysteme.de/group.php/sslcert/create/sslcert?step=0&"
    else
        printf "\nOkay, i will not open them.\n\n"
    fi
    exit

##ToDo
# Create Commands wich can be used again (yes/no  and certificatechoice)
# Beautify Note-Text
# Make Typechoice readable
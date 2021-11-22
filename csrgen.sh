#!/bin/bash
#
# 0) Checks if configfile and Zertifikate-Folder exists and if not creates them
#
##### Is config doesn't exist then source it, else create it
##### (-e checks for existing file and "!" negates)
#shellcheck source=/dev/null
    CONFIG=~/.csrgen.conf
    if [ ! -e ${CONFIG} ]; then touch ${CONFIG}
        printf "\nDu hast noch keine Konfig, wie ist dein MA-Kuerzel? (z.B CSI): "; read -r USERKUERZEL
        printf "Wie ist dein Vorname? (Der kommt in das E-Mailtemplate):         "; read -r FIRSTNAME
        printf "Wie ist dein Nachname?:                                          "; read -r LASTNAME
        printf "In welchen Folder sollen die CSRs? (Pfad ab HOME angeben):       "; read -r FOLDER; FOLDER=~/${FOLDER}
        printf "Und jetzt noch kurz deine Sozialversicherungsnummer?:            "; sleep 3s
        printf "\n\nSpaß, der Name hat gereicht.                                 "; sleep 2s
        printf "#!/bin/bash\n\
        %sFOLDER=$FOLDER\n\
        USERKUERZEL=${USERKUERZEL}\n\
        FULLNAME=\'${FIRSTNAME} ${LASTNAME}'\n" \
        > ${CONFIG}
    fi
    source ${CONFIG}
    clear
##### If Folder exists(-e) then do nothing (: = Do nothing) else create it
    if [[ -e ${FOLDER} ]]; then :
    else mkdir "$FOLDER"
    fi
##Function to ask for yes or no
askForYesOrNo () {
    ANSWER=""
    if [ "${ALREADYASKED}" == "yes" ]; then ALREADYASKED=""
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
# 1) Choosing Cert type and determining prefix for Filename
#
checktype () {
    printf "%b\n" "\n\n##WELCOME TO CSRGen##\n\n" \
    "1) Choose the certificate type." \
    "   These are the Options: " \
    "   AlphaSSL          = 1" \
    "   Wildcard          = 2" \
    "   SAN               = 3" \
    "   LetsEncrypt       = 4" \
    "   GeoTrust EV       = 5\n"
    AlphaSSL=1
    Wildcard=2
    SAN=3
    LetsEncrypt=4
    GeoTrust_and_EV=5
    printf "Enter 1 - 5: "; read -r CERTIFICATE_TYPE
    if [ "${CERTIFICATE_TYPE}" -eq "${LetsEncrypt}" ]; then
####Promts to a Web-Link and exits if its a LetsEncryptcertificate
        clear
        printf "%b\n" "\n" \
        "You can order LetsEncrypt-certificates via Service2" \
	    "Want me to open firefox for you?"
        askForYesOrNo
	    if  [ "${ANSWER}" == "yes" ]
        then firefox "https://service.continum.net/services/ssl-certificates"; exit
        else printf "\nAlright, heres the Link:\nhttps://service.continum.net/services/ssl-certificates\n\n"; exit
        fi
    else
#
# 2) Reading the Name of the Domain the Cert is being made for
#
    printf "\n2) Is the csr for a subdomain? (For example cloud.domain.de)(not www.)"
    askForYesOrNo
        if [ "${ANSWER}" == "yes" ]
        then printf "\nFormat: subdomain.domain.tld"; SUBDOMAIN="yes"
        else printf "\nFormat: (NOT www.)domain.tld"; SUBDOMAIN="no"
        fi
    printf "\n3) Name the Domainname: "; read -r DOMAIN
    fi
#### Checks what kind of Subdomain and Prefix have to be used
#### Subomain will be entered into the Cert, Prefix determines part of the Filename.
    if [ "${CERTIFICATE_TYPE}" -eq "${AlphaSSL}" ] || [ "${CERTIFICATE_TYPE}" -eq "${GeoTrust_and_EV}" ];
    then                                                #If Type AlphaSSl or Wildcard then check for a subdomain first,
        if [ "${SUBDOMAIN}" == "yes" ]; then PREFIX=""      #If theres a subdomain then leave prefix empty
	    else PREFIX="www." CN="www."                        #else just put www. as prefix and as CN
        fi
    elif [ "${CERTIFICATE_TYPE}" -eq "${SAN}" ];         then PREFIX="san."
    elif [ "${CERTIFICATE_TYPE}" -eq "${Wildcard}" ];    then PREFIX="wc." CN="*."
    printf "Is it an Certificate with Extended Validation (EV)?"
        askForYesOrNo
        if [ "${ANSWER}" == "yes" ]
        then EV="yes"
        else EV="no"
        fi
    else printf "Number not betweeen 1 and 5, try again.\n"; sleep 2s
    clear
    checktype
    fi
}
checktype
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
printf "%b\n" "[req]" \
        "distinguished_name = req_distinguished_name" \
        "req_extensions = v3_req" \
        "prompt = no" \
        "[req_distinguished_name]" \
        "C = ${LAND}" \
        "ST = ${BUNDESLAND}" \
        "L = ${STADT}" \
        "O = ${FIRMENNAME}" \
        "OU = ${ABTEILUNGSNAME}" \
        "CN = ${DOMAIN}" \
        "[v3_req]" \
        "keyUsage = keyEncipherment, dataEncipherment" \
        "extendedKeyUsage = serverAuth" \
        "subjectAltName = @alt_names" \
        "[alt_names]" >> openssl.cnf
        printf "\nWeitere Domainnamen getrennt mit einem Leerzeichen: " ; read -r SANDOMAINS
        COUNTER=0
        for FQDN in ${SANDOMAINS}
        do
            (( COUNTER++ )) || true
            printf "DNS.%s${COUNTER} = ${FQDN}\n" >> openssl.cnf
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
        "/C=${LAND}/ST=${BUNDESLAND}/L=${STADT}/O=${FIRMENNAME}/OU=${ABTEILUNGSNAME}/CN=${CN}${DOMAIN}" \
        -keyout  $PREFIX"$DOMAIN".key -out $PREFIX"$DOMAIN".csr
##If AlphaSSl or Wildcard (if not SAN nor EV nor Geotrust)
    else
        openssl req -new -newkey rsa:2048 -nodes -sha256 -utf8 -subj \
        "/C=DE/CN=$CN$DOMAIN" -keyout $PREFIX"$DOMAIN".key -out $PREFIX"$DOMAIN".csr
    fi
    clear
#####Prints out inputs
    printf "\nHeres your inputs:\n  Domain:       %s$DOMAIN""\n  Cert Type:    "
    if   [ "${CERTIFICATE_TYPE}" -eq "${AlphaSSL}" ];        then printf "AlphaSSL"
    elif [ "${CERTIFICATE_TYPE}" -eq "${Wildcard}" ];        then printf "AlphaSSL Wildcard"
    elif [ "${CERTIFICATE_TYPE}" -eq "${SAN}" ];             then printf "SAN"
    elif [ "${CERTIFICATE_TYPE}" -eq "${GeoTrust_and_EV}" ]; then printf "Geotrust"
    fi
    printf "\n  EV:           "
    if [ "${EV}" = yes ] || [ "${CERTIFICATE_TYPE}" -eq "${GeoTrust_and_EV}" ];
        then printf "Yes";
        else printf "No"
    fi
    printf "\n"
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
    printf "%b\n" \
    "Domain: ""$CN$DOMAIN""\n" \
    "TXT-Record: \n" \
    "Hallo, der Serviceauftrag wurde erledigt.\n" \
    "@BO Hier sind die zugehörigen SSL-Zertifikatsdaten für $CN$DOMAIN\n\t" \
    "Domain:            $CN$DOMAIN  " \
    "Erstellt:              " \
    "Expire:                " \
    "Type:          ${CERTIFICATE_TYPEWRITTEN}  " \
    "Approver-type:             " \
    "ObjectID:      \n" \
    "<BILD>\n" \
    "Viele Grüße" \
    "${FULLNAME} \n" >> Notizen
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
    	nemo --no-default-window "$DIRECTORY"
    	code "$DIRECTORY"
   	    firefox "$DOMAIN"
    	firefox "https://service.continum.net/services/dns/index"
    	firefox "https://gui.cps-datensysteme.de/group.php/sslcert/create/sslcert?step=0&"
    else
        printf "\nOkay, i will not open them.\n\n"
    fi
    exit

##ToDo
# Beautify Note-Text
# Make Typechoice readable
# Switch 1 & 2 because else Letsencrypt is creating csrs too
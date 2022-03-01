

#!/bin/bash

# 0) Checks if configfile and "Zertifikate"-Folder exists and if not creates them.

   # If config doesn't exist then source it, else create it.
    # (-e checks for existing file and "!" negates)
     #Next line is for Error handling
     #shellcheck source=/dev/null
        CONFIG=~/.csrgen.conf
        if [ ! -e ${CONFIG} ]; then touch ${CONFIG}
            printf "\n"
            read -rp "Du hast noch keine Konfig, wie ist dein MA-Kuerzel? (z.B CSI): " USERKUERZEL
            read -rp "Wie ist dein Vorname? (Der kommt in das E-Mailtemplate):       " FIRSTNAME
            read -rp "Wie ist dein Nachname?:                                        " LASTNAME
            read -rp "In welchen Folder sollen die CSRs? (Pfad ab HOME angeben):     " FOLDER; FOLDER=~/${FOLDER}
            printf "\n\
            %sFOLDER=$FOLDER/\n\
            USERKUERZEL=${USERKUERZEL}\n\
            FULLNAME=\'${FIRSTNAME} ${LASTNAME}'\n" \
           > ${CONFIG}
        fi
        source ${CONFIG}
        clear

     # If ("Zertifikate")-Folder exists(-e) then do nothing (: = Do nothing) else create it
       if [[ -e ${FOLDER} ]]; then :
       else mkdir "$FOLDER"
       fi

   # --------- Some functions that will be called later
    ##Function(Mini-program) to ask for yes or no
    askForYesOrNo () {
        ANSWER=""
        if [ "${ALREADYASKED}" == "yes" ]; then ALREADYASKED=""
        else printf "\nyes / no: "
        fi
        read -r INPUT
        ## Case statement to format the answers so theyre always "yes" or "no" and nothing else
        case "${INPUT}" in
            yes|y|Y) ANSWER="yes" ;;
            no|n|N)  ANSWER="no"  ;;
            *) #(else)
                printf "\"yes\" or \"no\": "
                ALREADYASKED="yes"
                askForYesOrNo   ;;
        esac
    }
    ##---------
    # Function to ask for Subdomains
    askForSubdomain() {
        printf "\nHat die domain eine Subdomain? (Nicht www.)"
        askForYesOrNo
        clear
        case ${ANSWER} in
            yes) printf "\nFormat:                               subdomain.domain.tld"; SUBDOMAIN="yes" ;;
            no)  printf "\nFormat:                               (Nicht www.)domain.tld"; SUBDOMAIN="no"  ;;
        esac
    }
    ##---------
    # Function to ask for EV-Data
    getEVdata() {
        printf "\n"
        read -rp "Land: (Bsp: DE) " LAND
        read -rp "Bundesland:     " BUNDESLAND
        read -rp "Stadt:          " STADT
        read -rp "Firmenname:     " FIRMENNAME
        read -rp "Abteilungsname: " ABTEILUNGSNAME
    }
    ##---------
    # Function to generate standard csr
    generateStandardcsr() {
        openssl req -new -newkey rsa:2048 -nodes -sha256 -utf8 -subj \
        "/C=DE/CN=$CN$DOMAIN"\
        -keyout "$PREFIX""$DOMAIN".key -out "$PREFIX""$DOMAIN".csr
    }
    ##---------
    generateEVcsr() {
        getEVdata
        openssl req -new -newkey rsa:2048 -nodes -sha256 -utf8 -subj \
            "/C=${LAND}/ST=${BUNDESLAND}/L=${STADT}/O=${FIRMENNAME}/OU=${ABTEILUNGSNAME}/CN=${CN}${DOMAIN}" \
            -keyout  $PREFIX"$DOMAIN".key -out $PREFIX"$DOMAIN".csr
    }
   ##---------

# 1) Choosing Cert type and determining prefix for Filename
#    Its put as a function so you call it again if theres a wrong input

    getType () {
        printf "%b\n" "\n\n##This is CSRgen##\n\n" \
        "   Wähle den Zertifikatstyp" \
        "   AlphaSSL          = 1"        \
        "   Wildcard          = 2"        \
        "   SAN               = 3"        \
        "   LetsEncrypt       = 4"        \
        "   GeoTrust EV       = 5\n"
        AlphaSSL=1
        Wildcard=2
        SAN=3
        LetsEncrypt=4
        GeoTrust=5

        read -rp "Wähle 1 - 5: " CERTIFICATE_TYPE

        case ${CERTIFICATE_TYPE} in
            ![1-5] ) # Number not between 1-5:           ---Ask again
                printf "\nDas ist keine Nummer zwischen 1-5, versuchs nochmal.\n"; sleep 2s
                clear
                getType ;;

            "${AlphaSSL}" | "${GeoTrust}" ) #           ---Ask if its for a subdomain before changing the prefix
                askForSubdomain
                if [ "${CERTIFICATE_TYPE}" = "${GeoTrust}" ]; then EV="yes"; fi
                case ${SUBDOMAIN} in
                    yes) PREFIX="" ;;
                    no)   PREFIX="www." CN="www." ;;
                esac ;;

            "${Wildcard}" ) #:                          ---Ask if its a certificate with EV
                PREFIX="wc." CN="*."
                printf "\n\nIst es ein Zertifikat mit Extended Validation (EV)?"
                    askForYesOrNo
                    EV=${ANSWER}
                askForSubdomain
                ;;

            "${SAN}") #:                                ---Only change the prefix
                PREFIX="san." ;;

            "${LetsEncrypt}") #:                        ---Optionally prompts to the SB2-Website and then exits
                SB2LINK="https://service.continum.net/services/ssl-certificates"
                printf "%b\n\n" \
                "LetsEncrypt-Zertifikate kannst du über den Service2 bestellen: ${SB2LINK}" \
                "Soll ich ihn in Firefox öffnen?"
                askForYesOrNo
                case ${ANSWER} in
                    yes) firefox "${SB2LINK}"; exit 1 ;;
                    no)  printf "\nOkay, bye! \n\n"; exit 1 ;;
                esac ;;
        esac
    }
    getType

    # Reading the Name of the Domain the Cert is being made for
    printf "\n"
    read -rp "Nenne mir jetzt den Namen der Domain: " DOMAIN_UNCONVERTED

    #Converts umlauts with idn
    case $DOMAIN_UNCONVERTED in
        *[äÄöÖüÜ]*) DOMAIN=$(idn "$DOMAIN_UNCONVERTED");
            # Exits in case its not installed
            if [  "$?" -eq 127  ]; then printf "\nInstalliere idn um Umlaute zu konvertieren\n\n"; exit 127; fi
        ;;
        *) DOMAIN=$DOMAIN_UNCONVERTED ;;
    esac

# 3) Creating dedicated folder and generating the csr-files with openssl.

    # Format: 2022.02.24
    DATE=$(date +"%Y.%m.%d")
    DIRECTORY=$FOLDER$DATE-$PREFIX$DOMAIN/
    mkdir "$DIRECTORY"
    cd    "$DIRECTORY" || return


    case ${CERTIFICATE_TYPE} in

        "${AlphaSSL}" ) generateStandardcsr;;

        "${Wildcard}" ) if [ "${EV}" = "yes" ]; then generateEVcsr; else generateStandardcsr; fi ;;

        "${SAN}" ) getEVdata

            # (Prints the needed variables into the file openssl.conf, wich will be used to generate the SAN-csr)
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

            # This part puts the Domainnames into the openssl.conf. Format:  DNS.x = domain.tld
            read -rp "\n\nWeitere Domainnamen getrennt mit einem Leerzeichen: " SANDOMAINS
            COUNTER=0
            for FQDN in ${SANDOMAINS}
            do
                (( COUNTER++ )) || true
                printf "DNS.%s${COUNTER} = ${FQDN}\n" >> openssl.cnf
                openssl genrsa -out san."$DOMAIN".key 2048
                openssl req -new -out san."$DOMAIN".csr -key san."$DOMAIN".key -config openssl.cnf
                openssl req -text -noout -in san."$DOMAIN".csr
            done
            ;;

        "${GeoTrust}" )
            generateEVcsr
            clear
            ;;

    esac


# 4) Creating the notes in the created folder

    #Prints out inputs and assigns the types for he Notes
        printf "\nHier sind deine Inputs:\n  Domain:         %s$DOMAIN""\n  Zertifikatstyp: "
        case ${CERTIFICATE_TYPE} in
           "${AlphaSSL}" ) printf "AlphaSSL";            CERTIFICATE_TYPEWRITTEN="AlphaSSL" ;;
           "${Wildcard}" ) printf "AlphaSSL Wildcard";   CERTIFICATE_TYPEWRITTEN="AlphaSSL Wildcard" ;;
           "${SAN}" )      printf "SAN";                 CERTIFICATE_TYPEWRITTEN="SAN" ;;
           "${GeoTrust}" ) printf "Geotrust";            CERTIFICATE_TYPEWRITTEN="Geotrust EV" ;;
        esac

        printf "%s\n  EV:             ${EV}"
        if [ ! ${EV} = "yes" ]; then printf "no"; fi

   #Creates all the files in the dedicated directory
        FILENAME="$DIRECTORY""$PREFIX""$DOMAIN"
        touch "${FILENAME}".crt "${FILENAME}".pem "${FILENAME}".int "$DIRECTORY"Notizen
        mkdir "$DIRECTORY"old_"$DATE"_"$USERKUERZEL"

    printf "%b\n"                                     \
    "Domain: ""$CN$DOMAIN""\n"                        \
    "TXT-Record: \n"                                  \
    "Hallo, der Serviceauftrag wurde erledigt.\n"     \
    "@BO Hier sind die zugehörigen SSL-Zertifikatsdaten für $CN$DOMAIN\n\t" \
    "Domain:            $CN$DOMAIN  "                 \
    "Erstellt:          "                             \
    "Expire:            "                             \
    "Type:              ${CERTIFICATE_TYPEWRITTEN}  " \
    "Approver-type:     "                             \
    "ObjectID:          \n"                           \
    "<BILD>\n"                                        \
    "Viele Grüße"                                     \
    "${FULLNAME} \n" >> Notizen

    cat "$DIRECTORY""$PREFIX""$DOMAIN".key >> "$DIRECTORY""$PREFIX""$DOMAIN".pem

    printf "\n\n"
    cat "$DIRECTORY"*csr
    printf "\n\n##Hier sind die Nameserver:\n "
    dig ns "$DOMAIN" | grep -A 2 'ANSWER SECTION'

    #Checking for and opening the old cert files in the File Explorer if thats wanted
    printf "\n\nBei einer Zertifikatserneuerung findest du das alte Zertifikat vielleicht hier: \n"
    FINDINGS=$(find ~/git/puppet/ -name "$DOMAIN*.*"  | grep -E 'prod|legacy' | grep -E 'pem|crt'); printf "%s$FINDINGS"
    printf "\n\nSoll ich die Ordner und Seiten öffnen? ";
    askForYesOrNo
    if [ "${ANSWER}" == "yes" ]; then
    	nemo --no-default-window "$DIRECTORY"
    	code "$DIRECTORY"
   	    firefox "$DOMAIN"
    	firefox "https://service.continum.net/services/dns/index"
    	firefox "https://gui.cps-datensysteme.de/group.php/sslcert/create/sslcert?step=0&"
    else
        printf "\nOkay, ich öffne sie nicht. Bye!\n\n"
    fi
    exit
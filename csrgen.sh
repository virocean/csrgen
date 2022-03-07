#!/bin/bash
#-eax
AlphaSSL=1
Wildcard=2
SAN=3
LetsEncrypt=4
GeoTrust=5
#
# 0) Checks if configfile and "Zertifikate"-Folder exists and if not creates them.
#
    # If config doesn't exist then source it, else create it.
     # (-e checks for existing file and "!" negates)
        CONFIG=~/.csrgen.conf
        if [ ! -e "${CONFIG}" ]; then
            touch "${CONFIG}"
            printf "\n"
            read -rp "Du hast noch keine Konfig, wie ist dein MA-Kuerzel? (z.B CSI): " USERKUERZEL
            read -rp "Wie ist dein Vorname? (Der kommt in das E-Mailtemplate):       " FIRSTNAME
            read -rp "Wie ist dein Nachname?:                                        " LASTNAME
            read -rp "In welchen Folder sollen die CSRs? (Pfad ab HOME angeben):     " FOLDER; FOLDER=~/${FOLDER}
            printf "\n                              \
            %sFOLDER=$FOLDER/\n                     \
            USERKUERZEL=${USERKUERZEL}\n            \
            FULLNAME=\'${FIRSTNAME} ${LASTNAME}'\n" \
            > ${CONFIG}
        fi
        #Next line exists so shellcheck wont throw an error
        #shellcheck source=/dev/null
        source ${CONFIG}
        clear

     # If ("Zertifikate")-Folder doesn't (! negates) exist(-e) then create it
       if [ ! -e "${FOLDER}" ]; then mkdir "${FOLDER}"; fi

    ##Function(Mini-program) to ask for yes or no
    askForYesOrNo() {
        ANSWER=""
        if [ "${ALREADYASKED}" == "yes" ]; then ALREADYASKED=""
        else printf "\nyes / no: "
        fi
        read -r INPUT
        ## Format the answers so they're always "yes" or "no" and nothing else
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
        printf "\nHat die Domain eine Subdomain? (Nicht www.)"
        askForYesOrNo
        case ${ANSWER} in
            yes) printf "\nFormat: subdomain.domain.tld"; SUBDOMAIN="yes" ;;
            no)  printf "\nFormat: (Nicht www.)domain.tld"; SUBDOMAIN="no"  ;;
        esac
    }
    ##---------

#
# 1) Functions to choose the Cert type and determining prefix for Filename
#
    askForCertType() {
        printf "%b\n" "ᵀʰᵃⁿᵏ ʸᵒᵘ ᶠᵒʳ ᵘˢⁱⁿᵍ \n𝘾𝙎𝙍𝙜𝙚𝙣\n" \
        "Wähle den Zertifikatstyp" \
        "   AlphaSSL          = 1" \
        "   Wildcard          = 2" \
        "   SAN               = 3" \
        "   LetsEncrypt       = 4" \
        "   GeoTrust EV       = 5"
        read -rp "                     ↳ " CERTIFICATE_TYPE
    }

    setPrefixAndCN(){
        case "${CERTIFICATE_TYPE}" in
            "${AlphaSSL}" | "${GeoTrust}" )
                if [ "${CERTIFICATE_TYPE}" = "${GeoTrust}" ]; then EV="yes"; fi
                #If it has a subdomain the prefix is not needed
                if [ "${SUBDOMAIN}" = "yes" ]; then PREFIX=""; else PREFIX="www." CN="www."; fi
                ;;
            "${Wildcard}" )
                PREFIX="wc." CN="*."
                # Ask if its a certificate with EV
                printf "\n\nIst es ein Zertifikat mit Extended Validation (EV)?"
                askForYesOrNo; EV=${ANSWER}
                askForSubdomain
                ;;
            "${SAN}")
                PREFIX="san."
                ;;
            "${LetsEncrypt}")
                # prompts to the SB2-Website and then exits
                SB2LINK="https://service.continum.net/services/ssl-certificates"
                printf "%b\n\n" \
                "LetsEncrypt-Zertifikate kannst du über den Service2 bestellen: ${SB2LINK}"; exit 1
                ;;
            *)
                printf "\nDas ist keine Nummer zwischen 1-5, versuchs nochmal.\n"
                sleep 2s; clear; askForCertType ;;
        esac
    }

    #Converts umlauts with idn
    convertUmlauts() {
        case "${DOMAIN_UNCONVERTED}" in
            *[äÄöÖüÜ]*) DOMAIN=$(idn "${DOMAIN_UNCONVERTED}");
                # 127 is the exitcode($?) in case a command is not installed. In this case csrgen will exit.
                if [  "$?" -eq 127  ]; then printf "\nInstalliere idn um Umlaute zu konvertieren\n\n"; exit 127; fi
            ;;
            *) DOMAIN="${DOMAIN_UNCONVERTED}" ;;
        esac
    }

    askForDomainname(){
        printf "\n"
        read -rp "Nenne mir jetzt den Namen der Domain: " DOMAIN_UNCONVERTED
        printf "↳"
        convertUmlauts
    }


#
# 2) Functions to generate the csr-, and keyfiles with openssl.
#
    # Generates standard csr
    opensslStandardcsr() {
        openssl req -new -newkey rsa:2048 -nodes -sha256 -utf8 -subj \
        "/C=DE/CN=$CN$DOMAIN"\
        -keyout "$PREFIX""$DOMAIN".key -out "$PREFIX""$DOMAIN".csr
    }

    # We need this Data for SAN or EV Certificates
    askForEVdata() {
        printf "\n"
        read -rp "Land: (Bsp: DE) " LAND
        read -rp "Bundesland:     " BUNDESLAND
        read -rp "Stadt:          " STADT
        read -rp "Firmenname:     " FIRMENNAME
        read -rp "Abteilungsname: " ABTEILUNGSNAME
    }

    # Generates Extended Validation(EV) csr
    opensslEVcsr() {
        askForEVdata
        openssl req -new -newkey rsa:2048 -nodes -sha256 -utf8 -subj \
            "/C=${LAND}/ST=${BUNDESLAND}/L=${STADT}/O=${FIRMENNAME}/OU=${ABTEILUNGSNAME}/CN=${CN}${DOMAIN}" \
            -keyout  $PREFIX"$DOMAIN".key -out $PREFIX"$DOMAIN".csr
    }

    # Generates SAN csr
    opensslSANcsr() {
        askForEVdata
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

        # Puts the Domainnames into the openssl.conf. Format:  DNS.x = domain.tld
        printf "\n\nWeitere Domainnamen getrennt mit einem Leerzeichen: "; read -r SANDOMAINS
        COUNTER=0
        for FQDN in ${SANDOMAINS}
        do
            (( COUNTER++ )) || true
            printf "DNS.%s${COUNTER} = ${FQDN}\n" >> openssl.cnf
            openssl genrsa -out san."$DOMAIN".key 2048
            openssl req -new -out san."$DOMAIN".csr -key san."$DOMAIN".key -config openssl.cnf
            openssl req -text -noout -in san."$DOMAIN".csr
        done
    }

    # Generates the csr based on the certificate type
    generateCSR(){
        # Format:   2022.02.24
        DATE=$(date +"%Y.%m.%d")
        DIRECTORY=$FOLDER$DATE-$PREFIX$DOMAIN/
        mkdir "$DIRECTORY"; cd "$DIRECTORY" || return

        case ${CERTIFICATE_TYPE} in
            "${AlphaSSL}" ) opensslStandardcsr ;;
            "${Wildcard}" ) if [ "${EV}" = "yes" ]; then opensslEVcsr; else opensslStandardcsr; fi ;;
            "${SAN}" )      opensslSANcsr ;;
            "${GeoTrust}" ) opensslEVcsr  ;;
        esac
    }


#
# 3) Functions to create all the files in the dedicated directory
#
    createFilesAndDirectorys(){
        FILENAME="$DIRECTORY""$PREFIX""$DOMAIN"
        touch "${FILENAME}".crt "${FILENAME}".pem "${FILENAME}".int "$DIRECTORY"Notizen
        mkdir "$DIRECTORY"old_"$DATE"_"$USERKUERZEL"
        cat "${FILENAME}".key >> "$DIRECTORY""$PREFIX""$DOMAIN".pem
    }

    printInputs(){
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
    }

    printOutputs(){
        printf "\n\n"
        cat "$DIRECTORY"*csr
        printf "\n\n##Hier sind die Nameserver:\n "
        dig ns "$DOMAIN" | grep -A 2 'ANSWER SECTION'

        printf "\n\nBei einer Zertifikatserneuerung findest du das alte Zertifikat vielleicht hier: \n"
        FINDINGS=$(find ~/git/puppet/ -name "$DOMAIN*.*" | grep -E 'prod|legacy' | grep -E 'pem|crt'); printf "%s$FINDINGS"
    }

#
# 4) Functions for creating the notes in the created folder
#
    createNotes(){
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
    }

    #Checking for and opening the old cert files in the File Explorer if thats wanted
    openOptionals(){
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
    }

    createAndPrint(){
        generateCSR
        createFilesAndDirectorys
        printInputs
        printOutputs
        createNotes
    }

    # This controls the order of execution in the script in case you want to shortcut it with optional parameters
    OPTIONS=$1
    case ${OPTIONS} in
        -f) # (-f)ast creation of AlphaSSL certificate
            CERTIFICATE_TYPE=1
            DOMAIN_UNCONVERTED="${2}"
            DOMAIN=${DOMAIN_UNCONVERTED}
            # Order of execution
            setPrefixAndCN
            createAndPrint
            ;;
        -a|*)
            askForCertType
            setPrefixAndCN
            askForDomainname
            createAndPrint
            openOptionals
    esac
exit
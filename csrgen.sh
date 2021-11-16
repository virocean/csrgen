#!/bin/bash
####Checks if configfile and Zertifikate-Folder exists and if not creates them
    if [ -e ~/.csrgen.conf ]; then source ~/.csrgen.conf;
    else touch ~/.csrgen.conf
        printf "\nDu hast noch keine Konfig, wie ist dein MA-Kuerzel? (z.B CSI):  " ; read -r USERKUERZEL
        printf "Wie ist dein Vorname? (Der kommt in das E-Mailtemplate):\t" ; read -r VORNAME
        printf "Wie ist dein Nachname?: \t\t\t\t\t" ; read -r NACHNAME
        printf "Und jetzt noch kurz deine Sozialversicherungsnummer?:\t\t"; sleep 3s
        printf "\n\nSpaß, der Name hat gereicht.\n"; sleep 2s
        printf "#!/bin/bash\nFOLDER=~/Zertifikate/\n%sUSERKUERZEL=${USERKUERZEL}\nUSER=\'${VORNAME} ${NACHNAME}'\n" > ~/.csrgen.conf
        source ~/.csrgen.conf
    fi
    if [ -e ~/Zertifikate/ ]
    then
        :
    else
        mkdir ~/Zertifikate/
    fi
#
# 1) Reading the Name of the Domain the Cert is being made for
#
    clear
    printf "\n\n##WELCOME TO CSRGen##\n"
    sleep 1s
    printf "\n1) Is the csr for a subdomain? (For example cloud.domain.de)(not www.)"
    printf "\ny/n: " ; read -r SUBDOMAIN
    if [ "${SUBDOMAIN}" == "yes" ] || [ "${SUBDOMAIN}" == "y" ]; then
        printf "\nFormat: subdomain.domain.tld"
    elif [ "${SUBDOMAIN}" == "no" ] || [ "${SUBDOMAIN}" == "n" ]; then
        printf "\nFormat: (NOT www.)domain.tld"
    else
        printf "You have to type \"y\" or \"n\" \nexiting.."
        exit
    fi
    printf "\nName the Domainname: " ; read -r DOMAIN
#
# 2) Choosing Cert Type and confirming
#
    printf "\n\n2) Choose the certificate type.\n"
    printf "These are the Options:\n"
    printf    "1.) AlphaSSL\n"
    printf    "2.) AlphaSSL Wildcard\n"
    printf    "3.) SAN\n"
    printf    "4.) LetsEncrypt\n"
    printf    "5.) GeoTrust EV\n"
    printf "\n1, 2 ,3, 4 or 5?: " ; read -r TYPE
    #
    if [ "${TYPE}" -eq 1 ] || [ "${TYPE}" -eq 5 ];                              #If Type AlphaSSl or Wildcard then check for a subdomain first,
        then                                                                    #else just put www. as prefix and as CN
            if [ "${SUBDOMAIN}" == "yes" ] || [ "${SUBDOMAIN}" == "y" ]; then
                PREFIX=""
	        else
                PREFIX="www."
		        CN="www."
            fi
    elif [ "${TYPE}" -eq 2 ]; then
        PREFIX="wc."
        CN="*."
#####Now choosing if its an EV or not
        printf "Is it an Certificate with Extended Validation (EV)?\n"
        printf "yes/no: " ; read -r EV
    elif [ "${TYPE}" -eq 3 ]; then
        PREFIX="san."
    elif [ "${TYPE}" -eq 4 ]; then
        printf "\n\nYou can order LetsEncrypt Certificates via Service2"
	    printf "\nWant me to open firefox for you?\nyes/no: " ; read -r OPENBROWSER
	    if [ "${OPENBROWSER}" = "yes" ] || [ "${OPENBROWSER}" = "y" ]; then
            firefox "https://service2.continum.net/services/ssl-certificates\n\n"
	        exit
	    elif [ "${OPENBROWSER}" = "no" ] || [ "${OPENBROWSER}" = "n" ]; then
            printf "Alright, heres the Link:\nhttps://service2.continum.net/services/ssl-certificates\n\nBye!"
	        exit
	    else
		    printf "You have to type "yes" or "no". \nAnyways.. heres the Link; \nhttps://service2.continum.net/services/ssl-certificates\n\nBye!"
	    exit
	    fi
    else
        printf "Number not betweeen 1 and 5, try again.\n  exiting.."
        exit
    fi
#
# 3) Creating dedicated Folder an executing the keygen-commands in it
#
    DATE=$(date +"%Y.%m.%d")
    DIRECTORY=$FOLDER$DATE-$PREFIX$DOMAIN/
    mkdir "$DIRECTORY"
    cd "$DIRECTORY" || return
#### If SAN
    if [ "${TYPE}" -eq 3 ]; then
        printf "\nLand: (Bsp: DE) " ; read -r LAND
        printf "Bundesland:     " ; read -r BUNDESLAND
        printf "Stadt:          " ; read -r STADT
        printf "Firmenname:     " ; read -r FIRMENNAME
        printf "Abteilungsname: " ; read -r ABTEILUNGSNAME
        printf "[req]\ndistinguished_name = req_distinguished_name\nreq_extensions = v3_req\nprompt = no\n[req_distinguished_name]\nC = %s\nST = %s\nL = %s\nO = %s\nOU = %s\nCN = %s\n[v3_req]\nkeyUsage = keyEncipherment, dataEncipherment\nextendedKeyUsage = serverAuth\nsubjectAltName = @alt_names\n[alt_names]\n" "${LAND}" "${BUNDESLAND}" "${STADT}" "${FIRMENNAME}" "${ABTEILUNGSNAME}" "${DOMAIN}" >> openssl.cnf
        printf "\nWeitere Domainnamen getrennt mit einem Leerzeichen: " ; read -r SANDOMAINS
        COUNTER=0
        for DNS in ${SANDOMAINS}
        do
            (( COUNTER++ )) || true
            printf "DNS.%s${COUNTER} = %s${DNS}" >> openssl.cnf
            openssl genrsa -out san."$DOMAIN".key 2048
            openssl req -new -out san."$DOMAIN".csr -key san."$DOMAIN".key -config openssl.cnf
            openssl req -text -noout -in san."$DOMAIN".csr
        done
##### If "EV" or Geotrust(Type 5)
    elif [ "${EV}" = yes ] || [ "${TYPE}" -eq 5 ]; then
        printf "\nLand: (Bsp: DE) " ; read -r LAND
        printf "Bundesland:     " ; read -r BUNDESLAND
        printf "Stadt:          " ; read -r STADT
        printf "Firmenname:     " ; read -r FIRMENNAME
        printf "Abteilungsname: " ; read -r ABTEILUNGSNAME
        openssl req -new -newkey rsa:2048 -nodes -sha256 -utf8 -subj "/C=${LAND}/ST=${BUNDESLAND}/L=${STADT}/O=${FIRMENNAME}/OU=${ABTEILUNGSNAME}/CN=$PREFIX${DOMAIN}" -keyout  $PREFIX"$DOMAIN".key -out $PREFIX"$DOMAIN".csr
##### If AlphaSSl or Wildcard (if not SAN nor SEV nor Geotrust)
    else    # elif [ "${EV}" = no ]; then
        openssl req -new -newkey rsa:2048 -nodes -sha256 -utf8 -subj "/C=DE/CN=$CN$DOMAIN" -keyout $PREFIX"$DOMAIN".key -out $PREFIX"$DOMAIN".csr
    fi
    clear
#####Prints out inputs
    printf "\nHeres your inputs:\n"
    printf "  Domain:       %s$DOMAIN"
    printf "\n  Cert Type:    "
        if [ "${TYPE}" -eq 1 ]; then
            printf "AlphaSSL\n"
        elif [ "${TYPE}" -eq 2 ]; then
            printf "AlphaSSL Wildcard\n"
        elif [ "${TYPE}" -eq 3 ]; then
            printf "SAN\n"
        elif [ "${TYPE}" -eq 5 ]; then
            printf "Geotrust\n"
        fi
    printf "  EV:           "
        if [ "${EV}" = yes ] || [ "${TYPE}" -eq 5 ]; then
            printf "Yes\n"
        else
            printf "No\n"
        fi
    printf ""
#####Creates all the files in the dedicated directory
    touch "$DIRECTORY""$PREFIX""$DOMAIN".crt "$DIRECTORY""$PREFIX""$DOMAIN".pem "$DIRECTORY""$PREFIX""$DOMAIN".int
    mkdir "$DIRECTORY"old_"$DATE"_"$USERKUERZEL"
    touch "$DIRECTORY"Notizen
#####Adding right Type into the notes
        if [ "${TYPE}" -eq 1 ]; then
            TYPEWRITTEN="AlphaSSL"
        elif [ "${TYPE}" -eq 2 ]; then
            TYPEWRITTEN="AlphaSSL Wildcard"
        elif [ "${TYPE}" -eq 3 ]; then
            TYPEWRITTEN="SAN"
        elif [ "${TYPE}" -eq 5 ]; then
            TYPEWRITTEN="Geotrust EV"
        fi
    printf "Domain: ""$CN$DOMAIN""%s\n\nTXT-Record: \n\n\nHallo, der Serviceauftrag wurde erledigt.\n\n@BO Hier sind die zugehörigen SSL-Zertifikatsdaten für $CN$DOMAIN\n\n\tDomain:\t\t$CN$DOMAIN\n\tErstellt:\t\t\t\n\tExpire:\t\t\t\n\tType:\t\t\t${TYPEWRITTEN}\n\tApprover-Type:\t\n\tObjectID:\t\t\n\n<BILD>\n\nViele Grüße\n${USER} \n" | cat >> Notizen
    cat "$DIRECTORY""$PREFIX""$DOMAIN".key >> "$DIRECTORY""$PREFIX""$DOMAIN".pem
    printf "\n\n"
    cat "$DIRECTORY"*csr
    printf "\n\n##Heres the Nameservers::\n "
    dig ns "$DOMAIN" | grep -A 2 'ANSWER SECTION'
#####Opening the old cert file
    printf "\n\nIf its a Certrenewal the old files may be around here: \n"
    FINDINGS=$(find ~/git -name "*$DOMAIN*.*"  | grep prod | grep 'pem\|crt')
    printf "%s$FINDINGS"
    printf "\n\nWant me to open the Directory in vscode and the Browser for you?\nyes/no: " ; read -r ANSWER
    if [ "${ANSWER}" == "yes" ] || [ "${ANSWER}" == "y" ]; then
    	nemo "$DIRECTORY"
    	code "$DIRECTORY"
   	firefox "$DOMAIN"
    	firefox "service2.continum.net/services/dns/"
    	firefox https://gui.cps-datensysteme.de/group.php/sslcert/create/sslcert?step=0&
    elif [ "${ANSWER}" == "no" ] || [ "${ANSWER}" == "n" ]; then
    	printf "\nOkay, i will not open them.\n\n"
    else
    	printf "\nThis didnt work, but you should be able to do the last steps on your own. I believe in you.\n\n"
    fi
    exit
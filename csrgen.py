#!/usr/bin/env python3

#import subprocess
from time import sleep


AlphaSSL=1
Wildcard=2
SAN=3
LetsEncrypt=4
GeoTrust=5

#process = subprocess.Popen([''])

#yes or no optional functions
def askForYesOrNo(question):
    reply = str(input(question+' (y/n): ')).lower().strip()
    if reply[0] == 'y': return True
    if reply[0] == 'n': return False
    else: return askForYesOrNo("Uhhhh... please enter ")

def askForSubdomain():
    reply = askForYesOrNo('Hat die Domain eine Subdomain? (Nicht www.)')
    if reply == True: print('Format: subdomain.domain.tld'); SUBDOMAIN=True
    else: print('ok, hat keine'); SUBDOMAIN=False

def askForCertType():
    CERTIFICATE_TYPE = str(input("""
    ᵀʰᵃⁿᵏ ʸᵒᵘ ᶠᵒʳ ᵘˢⁱⁿᵍ, 𝘾𝙎𝙍𝙜𝙚𝙣
    Wähle den Zertifikatstyp
       AlphaSSL          = 1
       Wildcard          = 2
       SAN               = 3
       LetsEncrypt       = 4
       GeoTrust EV       = 5
                           ↳ """))
    return CERTIFICATE_TYPE

def setPrefixAndCN(CERTIFICATE_TYPE):
    match CERTIFICATE_TYPE:
        case AlphaSSL | GeoTrust:
            if CERTIFICATE_TYPE = GeoTrust: EV="yes"
            #If it has a subdomain the prefix is not needed
            if SUBDOMAIN=True: PREFIX=""
            else: PREFIX="www."; CN="www."
        case Wildcard:
            PREFIX="wc."; CN="*."
            # Ask if its a certificate with EV
            print(' , , Ist es ein Zertifikat mit Extended Validation (EV)?')
            EV=askForYesOrNo()
            askForSubdomain()
        case SAN:
            PREFIX="san."
        case LetsEncrypt:
            # prompts to the SB2-Website and then exits
            SB2LINK='https://service.continum.net/services/ssl-certificates'
            print('LetsEncrypt-Zertifikate kannst du über den Service2 bestellen:' +SB2LINK)
        case _:
            print('Das ist keine Nummer zwischen 1-5, versuchs nochmal.')
            sleep(2); askForCertType()

#!/usr/bin/env python3
from logging import exception
import sys # sys.stdout.write('Hello World')
import datetime
from pathlib import Path
from time import sleep
import subprocess  #process = subprocess.check_output(['command1', 'command2'])
import re

AlphaSSL = 1
Wildcard = 2
SAN = 3
LetsEncrypt = 4
GeoTrust = 5
SUBDOMAIN = False
CN = "placeholder"
PREFIX = "placeholder"
DOMAIN_UNCONVERTED = "placeholder"
DOMAIN = "placeholder"
#global LAND
#global STADT
#global BUNDESLAND
#global FIRMENNAME
#global ABTEILUNGSNAME
#global FQDN

#yes or no optional functions
def askForYesOrNo(question):
    reply = str(input(question+' (y/n): ')).lower().strip()
    if reply[0] == 'y': return True
    if reply[0] == 'n': return False
    else: return askForYesOrNo("Uhhhh... please enter ")

def askForSubdomain():
    global SUBDOMAIN
    reply = askForYesOrNo('Hat die Domain eine Subdomain? (Nicht www.)')
    if reply == True: print('Format:   subdomain.domain.tld');    SUBDOMAIN=True
    else:             print('Format: (Nicht www.)domain.tld');  SUBDOMAIN=False

def askForCertType():
    try:
        CERTIFICATE_TYPE = int(input("""
        ᵀʰᵃⁿᵏ ʸᵒᵘ ᶠᵒʳ ᵘˢⁱⁿᵍ, 𝘾𝙎𝙍𝙜𝙚𝙣
        Wähle den Zertifikatstyp
           AlphaSSL          = 1
           Wildcard          = 2
           SAN               = 3
           LetsEncrypt       = 4
           GeoTrust EV       = 5
                             ↳ """))
        return CERTIFICATE_TYPE
    except: print('Das ist keine Nummer zwischen 1-5, versuchs nochmal.')

def setPrefixAndCN(CERTIFICATE_TYPE):
    global SUBDOMAIN
    match CERTIFICATE_TYPE:
        case 1 | 5:
            if CERTIFICATE_TYPE == 5: EV="yes"
            #If it has a subdomain the prefix is not needed
            if SUBDOMAIN == True: PREFIX=""
            else: PREFIX="www."; CN="www."
        case 2:
            PREFIX="wc."; CN="*."
            # Ask if its a certificate with EV
            print(' , , Ist es ein Zertifikat mit Extended Validation (EV)?')
            EV=askForYesOrNo()
            askForSubdomain()
        case 3:
            PREFIX="san."
        case 4:
            # prompts to the SB2-Website and then exits
            SB2LINK='https://service.continum.net/services/ssl-certificates'
            print('LetsEncrypt-Zertifikate kannst du über den Service2 bestellen:' +SB2LINK)
        case _:
            print('Das ist keine Nummer zwischen 1-5, versuchs nochmal.')
            sleep(2); askForCertType()

#Converts umlauts with idn
def convertUmlauts():
    global DOMAIN_UNCONVERTED
    convertDomain = subprocess.run(['idn', DOMAIN_UNCONVERTED], stdout=subprocess.PIPE) #Doesnt have error handling yet
    Umlaute = re.search(pattern="*[äÄöÖüÜ]*")
    match DOMAIN_UNCONVERTED:
        case Umlaute: DOMAIN=convertDomain
            # 127 is the exitcode($?) in case a command is not installed. In this case csrgen will exit.
            if $? == 127: print('Installiere idn um Umlaute zu konvertieren'); exit 127
        case _: DOMAIN=DOMAIN_UNCONVERTED

#def createAndPrint():
#    generateCSR()
#    createFilesAndDirectorys()
#    printInputs()
#    printOutputs()
#    createNotes()
#
#if __name__ == '__main__':
#    askForCertType()
#    askForSubdomain()
#    setPrefixAndCN()
#    askForDomainname()
#    createAndPrint()
#    openOptionals()
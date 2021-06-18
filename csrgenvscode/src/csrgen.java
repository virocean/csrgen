package csrgen;
import java.util.Scanner;

public class csrgen {
/*
1) Reading the Name of the Domain the Cert is being made for
*/
    String MAINFOLDER = "~/Zertifikate/";
    String USER = "DWE";
    String DOMAIN;
    int TYPE;
    String EV;
    String PREFIX;
    String CN;
    String DIRECTORY;
    Scanner read = new Scanner(System.in);

    public void domainEingeben(){
        System.out.print("Domain: ");
        DOMAIN = read.nextLine();

    }
/*
2) Choosing Cert Type and confirming
*/
    public void typeEingeben(){
        System.out.printf("%nNow let's choose the certificate type.%nThese are the Options:%n1.) AlphaSSL%n2.) Wildcard%n3.) SAN (Mit oder ohne EV)%n4.) LetsEncrypt%n5.) GeoTrust EV");
        TYPE = read.nextInt();
        while(true){
            switch(TYPE){
                case 1:    //AlphaSSL
                    continue;              
                case 2:    //Wildcard                       
                    PREFIX=("wc.");
                    CN=("*.");
                    System.out.println("Extended Validation? yes/no: ");
                    EV = read.nextLine();
                    continue;
                case 3:     //SAN
                    PREFIX=("san.");
                    continue;
                case 4:     //LetsEncrypt
                    System.out.println("LetsEncrypt Certificates can be installed over Service2:");
                    System.out.println("https://service2.continum.net/services/ssl-certificates");
                    System.exit(0);
                    continue;
                case 5:    //GeotrustEV                     
                    PREFIX=("www.");
                    continue;
                default:
                    System.out.println("%nNumber not between 1 and 5.%nTry again:%n");
            }    
        }
    }
    public void confirmInput(String String) {

        System.out.printf("%nHeres your inputs:%nDomain: "+DOMAIN+"%nCert Type: "+TYPE+"%n%");
        switch(TYPE){
            case 1:
                System.out.println("AlphaSSL");
            case 2:
                System.out.println("Wildcard");
            case 3:
                System.out.println("SAN");
            case 5:
                System.out.println("Geotrust");
        }
        System.out.println("EV: ");
            if (EV.equals("yes")){
                System.out.printf("yes");
            }else{
                System.out.printf("no");
            }
        }
    }
/*
3) Creating dedicated Folder an executing the keygen-commands in it
*/

}
package csrgen;
import java.util.Scanner;

public class csrgen {
 
        public static void main(String [] args){
        
        domainEingeben();
        typeEingeben();
        confirmInput();
}    
/*
1) Reading the Name of the Domain the Cert is being made for
*/
    static String MAINFOLDER = "~/Zertifikate/";
    static String USER = "DWE";
    static String DOMAIN;
    static int TYPE;
    static String EV;
    static String PREFIX;
    static String CN;
    static String DIRECTORY;
    static Scanner read = new Scanner(System.in);

    public static void domainEingeben(){
        System.out.print("Domain: ");
        DOMAIN = read.nextLine();

    }
/*
2) Choosing Cert Type and confirming
*/
    public static void typeEingeben(){
        System.out.printf("%nNow let's choose the certificate type.%nThese are the Options:%n1.) AlphaSSL%n2.) Wildcard%n3.) SAN (Mit oder ohne EV)%n4.) LetsEncrypt%n5.) GeoTrust EV%n1, 2, 3, 4 or 5?: ");
        boolean running = true;
        TYPE = read.nextInt();
        while(running){
            switch(TYPE){
                case 1:     //AlphaSSL
                case 5:     //GeotrustEV                     
                    PREFIX=("www.");      
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
                default:
                    System.out.println("%nNumber not between 1 and 5.%nTry again:%n");
            }
            if  (TYPE >= 1 && TYPE <= 5){
                confirmInput();
                break;
                
            }
        }
    }
    public static void confirmInput() {

        System.out.printf("%n%nHeres your inputs:%nDomain: "+DOMAIN+"%nCert Type: "+TYPE+"%n");
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
        System.out.println("EV? yes/no: ");
            if (EV.equals("yes")){
                System.out.printf("yes%n");
            }else{
                System.out.printf("no%n");
            }
        }
    }
/*
3) Creating dedicated Folder an executing the keygen-commands in it
*/

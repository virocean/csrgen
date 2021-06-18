package csrgen;
import java.util.Scanner;
public class Zertifikat {
    
    String FOLDER = "~/Zertifikate/";
    String KUERZEL = "DWE";
    int TYPE;
    String DOMAIN;
    String DIRECTORY;
    Scanner read = new Scanner(System.in);

    public void domainEingeben(){
        System.out.print("Domain: ");
        DOMAIN = read.nextLine();

    }

    public void typeEingeben(){
        System.out.prinf("%nNow let's choose the certificate type.%nThese are the Options:%n1.) AlphaSSL%n2.) Wildcard%n3.) SAN (Mit oder ohne EV)%n4.) LetsEncrypt%n5.) GeoTrust EV");
        TYPE = read.nextInt();
        String PREFIX;
        String CN;
        switch(TYPE){
            case 1:    //AlphaSSL
            case 5:    //GeotrustEV                     
                PREFIX=("www.");              
            case 2:    //Wildcard
                PREFIX=("wc.");
                CN=("*.");
                System.out.println("EV? yes/no: ");
                String EV;
                EV = read.nextLine();
            case 3:     //SAN
                PREFIX=("san.");
            case 4:     //LetsEncrypt
                System.out.println("LetsEncrypt Zertifikate werden über service2 ausgestellt:");
                System.out.println("https://service2.continum.net/services/ssl-certificates");
        
            default:
                System.out.println("Nummer nicht zwischen 1 und 5.");
        }

    public void datenBestätigen() {
        System.out.println("Typ des Zertifikates: "+TYPE);
    } 
}



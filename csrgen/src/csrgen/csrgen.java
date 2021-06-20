package csrgen;
import java.util.*;
import java.io.*;

public class csrgen {
 
        public static void main(String [] args){
        
        inputDomain();
        inputType();
        confirmInput();
        makeDirectorys();
}    
/*
1) Reading the Name of the Domain the Cert is being made for
*/
    static String DOMAIN;
    static int TYPE;
    static String EV;
    static String CN;
    static String PREFIX;
    static String MAINFOLDER = "~/Zertifikate/";
    static String DIRECTORY;
    static String USER = "DWE";


    static Scanner read = new Scanner(System.in);

    public static void inputDomain(){
        System.out.print("Domain: ");
        DOMAIN = read.nextLine();

    }
/*
2) Choosing Cert Type and confirming
*/
    public static void inputType(){
        System.out.printf("%nNow let's choose the certificate type."
                + "%nThese are the Options:"
                + "%n1.) AlphaSSL"
                + "%n2.) Wildcard"
                + "%n3.) SAN%n4.) LetsEncrypt"
                + "%n5.) GeoTrust EV"
                + "%n1, 2, 3, 4 or 5?: ");
        TYPE = read.nextInt();
            switch(TYPE){
                case 1: //AlphaSSL
                    PREFIX=("www.");
                    EV = ("No");
                    break;
                case 2: //Wildcard                       
                    PREFIX=("wc.");
                    CN=("*.");
                    System.out.print("Extended Validation? yes/no: ");
                    read.nextLine(); //catches the \n
                    EV = read.nextLine();
                    break;
                case 3: //SAN
                    PREFIX=("san.");
                    System.out.print("Extended Validation? yes/no: ");
                    read.nextLine(); //catches the \n
                    EV = read.nextLine();
                    break;
                case 4: //LetsEncrypt
                    System.out.printf("%nLetsEncrypt Certificates can be installed over Service2:"
                    + "%nhttps://service2.continum.net/services/ssl-certificates");
                    System.exit(0);
                    break;
                case 5: //GeotrustEV                     
                    PREFIX=("www.");     
                    EV = ("yes");
                default:
                    System.out.printf("%nNumber not between 1 and 5.%n"
                            + "Try again: "
                            + "%n"); 
                    inputType();        
            }
            System.out.printf("%n");       
        }
    
    public static void confirmInput() {

        System.out.printf("%n%nHeres your inputs:%nDomain:    "+DOMAIN+"%nCert Type: ");
        switch(TYPE){
            case 1:
                System.out.println("AlphaSSL");
                break;                
            case 2:
                System.out.println("Wildcard");
                break;                
            case 3:
                System.out.println("SAN");
                break;                
            case 5:
                System.out.println("Geotrust");
                break;                
        }
        System.out.print("EV:        ");
        if (EV.equals("yes") || TYPE == 5){
            System.out.printf("yes%n");
        }else{
            System.out.printf("no%n");
        }
    }

/*
3) Creating dedicated Folder an executing the keygen-commands in it
*/
    public static void makeDirectorys() {
        
    //static String PREFIX;
    //static String MAINFOLDER = "~/Zertifikate/";
    //static String DIRECTORY;
    //static String USER = "DWE";

        
        //date dir = new java.util.Date(System.currentTimeMillis());
        String DIRECTORYNAME;
        DIRECTORYNAME = (MAINFOLDER+"DATUM"+"-"+PREFIX+DOMAIN);
        File DIRECTORY;
        DIRECTORY = new File(DIRECTORYNAME);
        
        if (DIRECTORY.mkdir()){
            System.out.println("Directory is created");
        }else{
            System.out.println("Directory cannot be created");
        }
    }   
}
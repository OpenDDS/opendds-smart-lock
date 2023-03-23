package org.opendds.smartlock;

public enum OpenDDSSecEnum {

    AUTH_IDENTITY_CA("identity_ca.pem"),
    AUTH_IDENTITY_CERTIFICATE("identity.pem"),
    AUTH_PRIVATE_KEY("identity_key.pem"),
    ACCESS_PERMISSIONS_CA("permissions_ca.pem"),
    ACCESS_GOVERNANCE("governance.xml.p7s"),
    ACCESS_PERMISSIONS("permissions.xml.p7s");

    private String filename;

    OpenDDSSecEnum(String certFilename){
        this.filename = certFilename;
    }

    public String getFilename() {
        return filename;
    }
}

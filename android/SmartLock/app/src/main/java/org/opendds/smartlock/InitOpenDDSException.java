package org.opendds.smartlock;

public class InitOpenDDSException extends Exception {
    public InitOpenDDSException(String msg) {
        super(msg);
    }

    public InitOpenDDSException(String msg, Throwable e) {
        super(msg, e);
    }
}

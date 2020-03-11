package org.opendds.smartlock;

import java.io.Serializable;

public class SmartLockStatus implements Serializable {
    public String id = "Unknown";

    public enum State {
        UNLOCKED, PENDING_UNLOCK, LOCKED, PENDING_LOCK
    }

    State state;

    public boolean enabled = false;

    @Override
    public String toString() {
        return "SmartLockStatus: id: " + id + ", state: " + state;
    }

    private static final long serialVersionUID = 17L;
}

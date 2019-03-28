package org.opendds.smartlock;

public class SmartLockStatus {
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
}

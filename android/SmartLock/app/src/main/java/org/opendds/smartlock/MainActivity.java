package org.opendds.smartlock;

import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.ServiceConnection;
import android.net.ConnectivityManager;
import android.net.Network;
import android.os.IBinder;
import android.support.v4.app.FragmentTransaction;
import android.support.v7.app.AppCompatActivity;
import android.os.Bundle;
import android.util.Log;
import android.view.View;
import android.widget.LinearLayout;

import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.locks.ReentrantLock;

public class MainActivity extends AppCompatActivity {
    public static final String EXTRA_MESSAGE = "org.opendds.smartlock.MESSAGE";

    private final String LOG_TAG = "SmartLock_Main_Activity";

    private HashMap<String, SmartLockFragment> locks = new HashMap<String, SmartLockFragment>();

    // flag for network changes.
    private boolean networkLost = false;

    final private ReentrantLock locksLock = new ReentrantLock();

    private OpenDdsService svc = null;

    private ServiceConnection ddsServiceConnection = new ServiceConnection() {
        @Override
        public void onServiceConnected(ComponentName name, IBinder service) {

            Log.i(LOG_TAG, "calling onServiceConnected");

            OpenDdsService.OpenDdsBinder binder = (OpenDdsService.OpenDdsBinder) service ;
            svc = binder.getService();

            if (svc == null) {
                Log.e(LOG_TAG, "onServiceConnected() DDS reference is null");
            }
            else {

                // update lock models refs to service
                for (Map.Entry<String, SmartLockFragment> item : locks.entrySet()) {
                    item.getValue().svc = svc;
                }

                // update reference
                svc.setActivity(MainActivity.this);

            }
        }

            @Override
        public void onServiceDisconnected(ComponentName name) {
            Log.i(LOG_TAG, "calling onServiceDisconnected");
        }
    };

    private SmartLockFragment addLock (Context context) {
        LinearLayout list = (LinearLayout) findViewById(R.id.list);
        LinearLayout container = new LinearLayout(context);
        int container_id = View.generateViewId();
        container.setId(container_id);
        FragmentTransaction ft = getSupportFragmentManager().beginTransaction();
        SmartLockFragment frag = new SmartLockFragment();

        // it's okay if dds is null here, since service may not be started yet.
        if (svc != null) {
            frag.svc = svc;
        }


        ft.add(container_id, frag, frag.id_string);
        ft.commit();
        list.addView(container);

        return frag;
    }

    private SmartLockFragment addLock (Context context, SmartLockStatus status) {
        SmartLockFragment frag = addLock(context);
        frag.setStatus(status);

        locks.put(status.id, frag);

        return frag;
    }

    public SmartLockFragment addLock (SmartLockStatus status) {
        return addLock(this, status);
    }

    public SmartLockFragment updateLock (SmartLockStatus status) {
        SmartLockFragment frag = null;

        locksLock.lock();

        try {
            Log.i(LOG_TAG, "id = " + status.id + " contains " + locks.containsKey(status.id));
            if (locks.containsKey(status.id)) {
                frag = locks.get(status.id);
                frag.setStatus(status);
            }
        } finally {
            locksLock.unlock();
        }
        return frag;
    }

    public void tryToUpdateLock (SmartLockStatus status) {
        Log.i(LOG_TAG, "tryToUpdatelock 1");
        if (locksLock.tryLock()) {
            Log.i(LOG_TAG, "tryToUpdatelock 2");
            updateLock(status);
        }
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        if (savedInstanceState == null) {
            if (getResources().getBoolean(R.bool.add_fake_locks)) {
                addFakeLocks();
            }

            // Set locks that we will show
            String[] locks = getResources().getStringArray(R.array.locks);
            for (int i = 0; i < locks.length; i++) {
                SmartLockStatus status = new SmartLockStatus();
                status.id = locks[i];
                status.enabled = false;
                addLock(status);
            }
        }
    }

    @Override
    protected void onStart() {
        super.onStart();

        Log.i(LOG_TAG, "calling onStart");

        // create DDS Entities
        if (getResources().getBoolean(R.bool.init_opendds)) {

            Intent i = new Intent(getApplicationContext(), OpenDdsService.class);
            bindService(i, ddsServiceConnection, Context.BIND_AUTO_CREATE);
        }

        // install network change listener
        ConnectivityManager cm = (ConnectivityManager) getSystemService(CONNECTIVITY_SERVICE);
        cm.registerDefaultNetworkCallback(new ConnectivityManager.NetworkCallback() {

            @Override
            public void onAvailable(Network network) {
                super.onAvailable(network);
                Log.i(LOG_TAG, "Network Connection Available " + network.getNetworkHandle());

                if (networkLost) {
                    Log.i(LOG_TAG, "Network Connection Restored " + network.getNetworkHandle());
                }

                networkLost = false;
            }

            @Override
            public void onLost(Network network) {
                super.onLost(network);
                Log.i(LOG_TAG, "Network Connection Lost " + network.getNetworkHandle());
                networkLost = true;
            }
        });

    }

    @Override
    protected void onStop() {
        Log.i(LOG_TAG, "onStop()");

        Log.i(LOG_TAG, "calling unbindService()");
        unbindService(ddsServiceConnection);

        super.onStop();
    }

    @Override
    public void onDestroy() {
        Log.i(LOG_TAG, "onDestroy()");

        super.onDestroy();
    }

    // screen orientation change handling if needed
    @Override
    protected void onSaveInstanceState(final Bundle outState) {
        super.onSaveInstanceState(outState);

        Log.i(LOG_TAG, "onSaveInstanceState()");
    }

    @Override
    protected void onRestoreInstanceState(final Bundle savedInstanceState) {
        super.onRestoreInstanceState(savedInstanceState);

        Log.i(LOG_TAG, "onRestoreInstanceState()");
    }

    private void addFakeLocks () {
        {
            SmartLockStatus status = new SmartLockStatus();
            status.id = "Alice's House";
            status.enabled = true;
            addLock(status);
        }

        {
            SmartLockStatus status = new SmartLockStatus();
            status.id = "Bob's House";
            status.enabled = false;
            addLock(status);
        }
    }
}

package org.opendds.smartlock;

import android.content.Context;
import android.net.ConnectivityManager;
import android.net.Network;
import androidx.fragment.app.FragmentTransaction;
import androidx.appcompat.app.AppCompatActivity;

import android.os.AsyncTask;
import android.os.Bundle;
import android.util.Log;
import android.view.View;
import android.widget.LinearLayout;

import org.opendds.smartlock.ui.login.LoginFragment;

import java.util.HashMap;
import java.util.concurrent.locks.ReentrantLock;

public class MainActivity extends AppCompatActivity {
    private final String LOG_TAG = "SmartLock_Main_Activity";

    private final HashMap<String, SmartLockFragment> locks = new HashMap<>();
    final private ReentrantLock locksLock = new ReentrantLock();

    private static OpenDdsBridge ddsBridge = null;

    protected static OpenDdsBridge getDdsBridge() { return ddsBridge; }

    // flag for network changes.
    private boolean networkLost = false;

    private SmartLockFragment addLock(Context context) {
        LinearLayout list = findViewById(R.id.list);
        LinearLayout container = new LinearLayout(context);
        int container_id = View.generateViewId();
        container.setId(container_id);

        FragmentTransaction ft = getSupportFragmentManager().beginTransaction();
        SmartLockFragment frag = new SmartLockFragment();

        ft.add(container_id, frag, frag.id_string);
        ft.commit();
        list.addView(container);

        return frag;
    }

    private void addLogin(Context context) {
        LinearLayout list = findViewById(R.id.list);
        LinearLayout container = new LinearLayout(context);
        int container_id = View.generateViewId();
        container.setId(container_id);

        FragmentTransaction fragmentTransaction = getSupportFragmentManager().beginTransaction();
        LoginFragment loginFragment = new LoginFragment();

        fragmentTransaction.add(container_id, loginFragment, "login");
        fragmentTransaction.commit();
        list.addView(container);
    }

    private void addLock(Context context, SmartLockStatus status) {
        SmartLockFragment frag = addLock(context);
        frag.setStatus(status);
        locks.put(status.id, frag);
    }

    public void addLock(SmartLockStatus status) {
         addLock(this, status);
    }

    public void updateLock (SmartLockStatus status) {
        SmartLockFragment frag = locks.get(status.id);
        if (frag != null) {
            Log.i(LOG_TAG, "updateLock " + status.id + " set to " + status.state);
            locksLock.lock();
            frag.setStatus(status);
            locksLock.unlock();
        } else {
            Log.e(LOG_TAG, "updateLock " + status.id + " failed. Lock not found.");
        }
    }

    public void tryToUpdateLock(SmartLockStatus status) {
        Log.i(LOG_TAG, "tryToUpdatelock ");
        if (locksLock.tryLock()) {
            updateLock(status);
        }
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        if (savedInstanceState == null) {
            OpenDDSSec.setCacheDir(getBaseContext().getCacheDir());
            if (!OpenDDSSec.hasFiles()) {
                new OpenDDSSec.Download("dpm.unityfoundation.io","54", "WNg97wLeR7Rk5eHz", "NONCE").executeOnExecutor(AsyncTask.THREAD_POOL_EXECUTOR);
            } else {
                if (getResources().getBoolean(R.bool.add_fake_locks)) {
                    addFakeLocks();
                }
                // Set locks that we will show
                String[] locks = getResources().getStringArray(R.array.locks);
                for (String lock : locks) {
                    SmartLockStatus status = new SmartLockStatus();
                    status.id = lock;
                    status.enabled = false;
                    addLock(status);
                }

                // create DDS Entities
                if (getResources().getBoolean(R.bool.init_opendds)) {
                    ddsBridge = new OpenDdsBridge(this);
                    ddsBridge.start();
                }
            }
        } else {
            if (ddsBridge == null) {
                Log.e(LOG_TAG, "onCreate() DDS reference is null");
                boolean flag = false;
            }
        }
    }

    @Override
    protected void onStart() {
        super.onStart();

        Log.i(LOG_TAG, "calling onStart");


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

        super.onStop();
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        OpenDdsBridge.shutdown();
        Log.i(LOG_TAG, "onDestroy()");
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

    private void addFakeLocks() {
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

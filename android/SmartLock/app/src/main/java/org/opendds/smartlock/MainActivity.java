package org.opendds.smartlock;

import android.content.Context;
import android.net.ConnectivityManager;
import android.net.Network;

import androidx.annotation.NonNull;
import androidx.fragment.app.FragmentTransaction;
import androidx.appcompat.app.AppCompatActivity;

import android.os.Bundle;
import android.util.Log;
import android.view.View;
import android.widget.ImageButton;
import android.widget.LinearLayout;

import org.opendds.smartlock.ui.login.LoginFragment;

import java.util.HashMap;
import java.util.concurrent.locks.ReentrantLock;

public class MainActivity extends AppCompatActivity {
    private final String LOG_TAG = "SmartLock_Main_Activity";
    private final String LOGIN_FRAGMENT_TAG = "login";
    private final HashMap<String, SmartLockFragment> locks = new HashMap<>();
    final private ReentrantLock locksLock = new ReentrantLock();

    private static OpenDdsBridge ddsBridge = null;

    protected static OpenDdsBridge getDdsBridge() { return ddsBridge; }

    // flag for network changes.
    private boolean networkLost = false;
    private LinearLayout parentLinearLayout = null;

    private SmartLockFragment addLock(Context context) {
        LinearLayout container = new LinearLayout(context);
        int container_id = View.generateViewId();
        container.setId(container_id);

        FragmentTransaction fragmentTransaction = getSupportFragmentManager().beginTransaction();
        fragmentTransaction.setReorderingAllowed(true);
        SmartLockFragment smartLockFragment = new SmartLockFragment();
        fragmentTransaction.add(container_id, smartLockFragment, smartLockFragment.id_string);

        fragmentTransaction.commit();
        parentLinearLayout.addView(container, parentLinearLayout.getChildCount() - 1);


        return smartLockFragment;
    }

    private void addLogin(Context context) {
        setAddLoginButtonVisibility(false);
        LinearLayout container = new LinearLayout(context);
        int container_id = View.generateViewId();
        container.setId(container_id);

        FragmentTransaction fragmentTransaction = getSupportFragmentManager().beginTransaction();
        fragmentTransaction.setReorderingAllowed(true);
        LoginFragment loginFragment = new LoginFragment();

        fragmentTransaction.add(container_id, loginFragment, LOGIN_FRAGMENT_TAG);
        fragmentTransaction.commit();
        parentLinearLayout.addView(container, parentLinearLayout.getChildCount() - 1);
    }

    private void setAddLoginButtonVisibility(boolean visible) {
        final ImageButton button = findViewById(R.id.showLoginButton);
        button.setVisibility(visible ? View.VISIBLE : View.GONE);
    }

    public void removeLogin(){
        Log.d(LOG_TAG, "removeLogin");
        parentLinearLayout.removeAllViews();
        setAddLoginButtonVisibility(true);
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
            try {
                frag.setStatus(status);
            } catch (IllegalStateException e) {
                Log.e(LOG_TAG, "updateLock " + status.id + " unable to set status.");
            }
            locksLock.unlock();
        } else {
            Log.e(LOG_TAG, "updateLock " + status.id + " failed. Lock not found.");
        }
    }

    public void tryToUpdateLock(SmartLockStatus status) {
        Log.i(LOG_TAG, "tryToUpdateLock ");
        if (locksLock.tryLock()) {
            updateLock(status);
        }
    }

    public void startDDSBridge() {
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

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        parentLinearLayout = findViewById(R.id.list);

        final Context context = this;
        final ImageButton button = findViewById(R.id.showLoginButton);
        button.setOnClickListener(v -> addLogin(context));

        if (savedInstanceState == null) {
            OpenDDSSec.setMainActivity(this);
            OpenDDSSec.setCacheDir(getBaseContext().getCacheDir());
            if (!OpenDDSSec.hasFiles()) {
                addLogin(context);
            } else {
                startDDSBridge();
            }
        } else {
            if (ddsBridge == null) {
                Log.e(LOG_TAG, "onCreate() DDS reference is null");
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
    protected void onSaveInstanceState(@NonNull final Bundle outState) {
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

package org.opendds.smartlock;

import android.content.Intent;
import android.content.Context;
import android.net.ConnectivityManager;
import android.net.Network;
import android.support.v4.app.FragmentTransaction;
import android.support.v7.app.AppCompatActivity;
import android.os.Bundle;
import android.util.Log;
import android.view.View;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.Toast;

import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.locks.ReentrantLock;

import DDS.*;
import OpenDDS.DCPS.*;

import SmartLock.*;

public class MainActivity extends AppCompatActivity {
    public static final String EXTRA_MESSAGE = "org.opendds.smartlock.MESSAGE";

    private final String LOG_TAG = "SmartLock_Main_Activity";
    private final int DOMAIN = 42;

    public DomainParticipant participant;
    private DataWriter dw;
    private HashMap<String, SmartLockFragment> locks = new HashMap<String, SmartLockFragment>();

    // flag for network changes.
    private boolean networkLost = false;

    final private ReentrantLock locksLock = new ReentrantLock();

    private OpenDDSApplication getApp() {
        return (OpenDDSApplication) getApplication();
    }

    private SmartLockFragment addLock (Context context) {
        LinearLayout list = (LinearLayout) findViewById(R.id.list);
        LinearLayout container = new LinearLayout(context);
        int container_id = View.generateViewId();
        container.setId(container_id);
        FragmentTransaction ft = getSupportFragmentManager().beginTransaction();
        SmartLockFragment frag = new SmartLockFragment();
        frag.dw = dw;
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
        if (locksLock.tryLock()) {
            updateLock(status);
        }
    }

    // Used to load the 'native-lib' library on application startup.
    static {
        System.loadLibrary("native-lib");
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

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

    @Override
    protected void onStart() {
        // (Re-)Create DDS Entities
        if (getResources().getBoolean(R.bool.init_opendds)) {
            try {
                initParticipant();
                for (Map.Entry<String, SmartLockFragment> item : locks.entrySet()) {
                    item.getValue().dw = dw;
                }
            } catch (InitOpenDDSException exception) {
                final String error_message = "Error Initializing OpenDDS Participant";
                Log.e(LOG_TAG, error_message, exception);
                Toast.makeText(getApplicationContext(), error_message, Toast.LENGTH_LONG).show();
            }
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

        super.onStart();
    }

    @Override
    protected void onStop() {
        // backgrounded app
        super.onStop();
    }

    @Override
    public void onDestroy() {
        // Delete DDS Entities
        if (getResources().getBoolean(R.bool.init_opendds)) {
            deleteParticipant();
        }

        // Disable GUI
        for (Map.Entry<String, SmartLockFragment> item : locks.entrySet()) {
            item.getValue().disable();
            item.getValue().dw = null;
        }
        super.onDestroy();
    }

    public void initParticipant() throws InitOpenDDSException {
        if (participant != null) {
            return;
        }

        DomainParticipantFactory participantFactory = getApp().participantFactory;
        DomainParticipantQos participantQos = getApp().participantQos;

        participant = participantFactory.create_participant(
                DOMAIN, participantQos, null, DEFAULT_STATUS_MASK.value);

        if (participant == null) {
            throw new InitOpenDDSException("ERROR: Domain participant creation failed");
        }

        // Create DDS Entities That Read Status

        StatusTypeSupportImpl status_servant = new StatusTypeSupportImpl();
        if (status_servant.register_type(participant, "") != RETCODE_OK.value) {
            throw new InitOpenDDSException("ERROR: Status register_type failed");
        }

        Topic status_topic = participant.create_topic("SmartLock Status",
                status_servant.get_type_name(),
                TOPIC_QOS_DEFAULT.get(),
                null,
                DEFAULT_STATUS_MASK.value);
        if (status_topic == null) {
            throw new InitOpenDDSException("ERROR: Status Topic creation failed");
        }

        SubscriberQosHolder subscriberQos = new SubscriberQosHolder(
                                                    getApp().newDefaultSubscriberQos(participant));
        getApp().copyPartitionQos(subscriberQos.value.partition);
        Subscriber sub = participant.create_subscriber(subscriberQos.value,
                null, DEFAULT_STATUS_MASK.value);
        if (sub == null) {
            throw new InitOpenDDSException("ERROR: Subscriber creation failed");
        }

        DataReaderQosHolder qosh = new DataReaderQosHolder(getApp().newDefaultDataReaderQos(sub));
        sub.get_default_datareader_qos(qosh);
        qosh.value.reliability.kind = ReliabilityQosPolicyKind.RELIABLE_RELIABILITY_QOS;
        qosh.value.history.kind = HistoryQosPolicyKind.KEEP_ALL_HISTORY_QOS;
        DataReaderListenerImpl listener = new DataReaderListenerImpl(this);
        DataReader reader = sub.create_datareader(status_topic,
                qosh.value,
                listener,
                DEFAULT_STATUS_MASK.value);

        if (reader == null) {
            throw new InitOpenDDSException("ERROR: DataReader creation failed");
        }

        // location BIT subscriber
        Subscriber builtinSubscriber = participant.get_builtin_subscriber();
        if (builtinSubscriber == null) {
            System.err.println("ERROR: could not get built-in subscriber");
            return;
        }

        DataReader bitDr = builtinSubscriber.lookup_datareader(BuiltinTopicUtils.BUILT_IN_PARTICIPANT_LOCATION_TOPIC);
        if (bitDr == null) {
            System.err.println("ERROR: could not lookup datareader");
            return;
        }

        ParticipantLocationListener locationListener = new ParticipantLocationListener(this);
        assert (locationListener != null);

        int ret = bitDr.set_listener(locationListener, OpenDDS.DCPS.DEFAULT_STATUS_MASK.value);
        assert (ret == DDS.RETCODE_OK.value);

        // Create DDS Entities That Write Control

        ControlTypeSupportImpl control_servant = new ControlTypeSupportImpl();
        if (control_servant.register_type(participant, "") != RETCODE_OK.value) {
            throw new InitOpenDDSException("ERROR: Control register_type failed");
        }
        Topic control_topic = participant.create_topic("SmartLock Control",
                control_servant.get_type_name(),
                TOPIC_QOS_DEFAULT.get(),
                null,
                DEFAULT_STATUS_MASK.value);

        if (control_topic == null) {
            throw new InitOpenDDSException("ERROR: Control Topic creation failed");
        }

        PublisherQosHolder publisherQos = new PublisherQosHolder(
                                                getApp().newDefaultPublisherQos(participant));
        getApp().copyPartitionQos(publisherQos.value.partition);
        Publisher pub = participant.create_publisher(publisherQos.value,
                null, DEFAULT_STATUS_MASK.value);
        if (pub == null) {
            throw new InitOpenDDSException("ERROR: Publisher creation failed");
        }
        dw = pub.create_datawriter(control_topic,
                DATAWRITER_QOS_DEFAULT.get(),
                null,
                DEFAULT_STATUS_MASK.value);

        if (dw == null) {
            throw new InitOpenDDSException("ERROR: DataWriter creation failed");
        }
    }

    public void deleteParticipant() {
        if (participant != null) {
            participant.delete_contained_entities();
            getApp().participantFactory.delete_participant(participant);
            participant = null;
        }
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

    /**
     * A native method that is implemented by the 'native-lib' native library,
     * which is packaged with this application.
     */
    public native String stringFromJNI();
}

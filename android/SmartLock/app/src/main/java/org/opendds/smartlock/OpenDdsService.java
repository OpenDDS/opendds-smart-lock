package org.opendds.smartlock;

import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.res.AssetManager;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;
import android.os.Binder;
import android.os.IBinder;
import android.support.annotation.Nullable;
import android.util.Log;
import android.widget.Toast;

import org.omg.CORBA.StringSeqHolder;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.List;
import java.util.ArrayList;

import DDS.*;
import OpenDDS.DCPS.BuiltinTopicUtils;
import OpenDDS.DCPS.DEFAULT_STATUS_MASK;
import OpenDDS.DCPS.TheParticipantFactory;
import OpenDDS.DCPS.TheServiceParticipant;
import OpenDDS.DCPS.transport.TheTransportRegistry;
import SmartLock.ControlTypeSupportImpl;
import SmartLock.StatusTypeSupportImpl;

public class OpenDdsService extends Service {

    final static String LOG_TAG = "SmartLock_OpenDDS_Service";

    final static String LOCK_UPDATE_MESSAGE = "LockUpdateMessage";
    final static String LOCK_STATUS_DATA = "LockStatus";


    public boolean secure = false;

    public DomainParticipantFactory participantFactory;
    public DomainParticipantQos participantQos;

    private final int DOMAIN = 42;

    private final IBinder binder = new OpenDdsBinder();

    private static DomainParticipant participant = null;

    // need a persistent reference to datawriter to avoid GC
    private static DataWriter dw = null;

    protected static DataWriter getDataWriter() {
        return dw;
    }

    private String[] groups;

    // Used to load the 'native-lib' library on application startup.
    static {
        System.loadLibrary("native-lib");
    }

    public class OpenDdsBinder extends Binder {
        OpenDdsService getService() {
            return OpenDdsService.this;
        }
    }

    public void copyPartitionQos(PartitionQosPolicy partitionQosPolicy) {
        partitionQosPolicy.name = groups;
    }

    public DataReaderQos newDefaultDataReaderQos(Subscriber subscriber) {
        DataReaderQos dr_qos = new DataReaderQos();
        dr_qos.durability = new DurabilityQosPolicy();
        dr_qos.durability.kind = DurabilityQosPolicyKind.from_int(0);
        dr_qos.deadline = new DeadlineQosPolicy();
        dr_qos.deadline.period = new Duration_t();
        dr_qos.latency_budget = new LatencyBudgetQosPolicy();
        dr_qos.latency_budget.duration = new Duration_t();
        dr_qos.liveliness = new LivelinessQosPolicy();
        dr_qos.liveliness.kind = LivelinessQosPolicyKind.from_int(0);
        dr_qos.liveliness.lease_duration = new Duration_t();
        dr_qos.reliability = new ReliabilityQosPolicy();
        dr_qos.reliability.kind = ReliabilityQosPolicyKind.from_int(0);
        dr_qos.reliability.max_blocking_time = new Duration_t();
        dr_qos.destination_order = new DestinationOrderQosPolicy();
        dr_qos.destination_order.kind = DestinationOrderQosPolicyKind.from_int(0);
        dr_qos.history = new HistoryQosPolicy();
        dr_qos.history.kind = HistoryQosPolicyKind.from_int(0);
        dr_qos.resource_limits = new ResourceLimitsQosPolicy();
        dr_qos.user_data = new UserDataQosPolicy();
        dr_qos.user_data.value = new byte[0];
        dr_qos.ownership = new OwnershipQosPolicy();
        dr_qos.ownership.kind = OwnershipQosPolicyKind.from_int(0);
        dr_qos.time_based_filter = new TimeBasedFilterQosPolicy();
        dr_qos.time_based_filter.minimum_separation = new Duration_t();
        dr_qos.reader_data_lifecycle = new ReaderDataLifecycleQosPolicy();
        dr_qos.reader_data_lifecycle.autopurge_nowriter_samples_delay = new Duration_t();
        dr_qos.reader_data_lifecycle.autopurge_disposed_samples_delay = new Duration_t();

        DataReaderQosHolder holder = new DataReaderQosHolder(dr_qos);
        subscriber.get_default_datareader_qos(holder);

        return holder.value;
    }

    public PublisherQos newDefaultPublisherQos(DomainParticipant participant) {
        PublisherQos qos = new PublisherQos();
        qos.entity_factory = new EntityFactoryQosPolicy();
        qos.presentation = new PresentationQosPolicy();
        qos.presentation.access_scope = PresentationQosPolicyAccessScopeKind.from_int(0);
        qos.partition = new PartitionQosPolicy();
        qos.partition.name = new String[]{};
        qos.group_data = new GroupDataQosPolicy();
        qos.group_data.value = new byte[]{};

        PublisherQosHolder holder = new PublisherQosHolder(qos);
        participant.get_default_publisher_qos(holder);

        return holder.value;
    }

    public SubscriberQos newDefaultSubscriberQos(DomainParticipant participant) {
        SubscriberQos qos = new SubscriberQos();
        qos.entity_factory = new EntityFactoryQosPolicy();
        qos.presentation = new PresentationQosPolicy();
        qos.presentation.access_scope = PresentationQosPolicyAccessScopeKind.from_int(0);
        qos.partition = new PartitionQosPolicy();
        qos.partition.name = new String[]{};
        qos.group_data = new GroupDataQosPolicy();
        qos.group_data.value = new byte[]{};

        SubscriberQosHolder holder = new SubscriberQosHolder(qos);
        participant.get_default_subscriber_qos(holder);

        return qos;
    }

    private String copyAsset(String asset_path) throws InitOpenDDSException {
        File new_file = new File(getFilesDir(), asset_path);
        final String full_path = new_file.getAbsolutePath();
        Log.d(LOG_TAG, "Writing Asset File ".concat(asset_path));
        Throwable exception = null;
        try {
            InputStream in = getAssets().open(asset_path, AssetManager.ACCESS_BUFFER);
            byte[] buffer = new byte[in.available()];
            in.read(buffer);
            in.close();
            FileOutputStream out = new FileOutputStream(new_file);
            out.write(buffer);
            out.close();
        } catch (FileNotFoundException e) {
            exception = e;
        } catch (IOException e) {
            exception = e;
        }
        if (exception != null) {
            throw new InitOpenDDSException("Error copying asset: " + asset_path, exception);
        }
        return full_path;
    }

    private void initParticipantFactory() throws InitOpenDDSException {
        if (participantFactory != null) {
            return;
        }

        secure = getResources().getBoolean(R.bool.secure_opendds);

        // Ensure Config File and Security Files Exist
        final String config_file = copyAsset("opendds_config.ini");

        final String gov_file = copyAsset("gov_signed.p7s");
        final String id_ca_cert = copyAsset("identity_ca_cert.pem");
        final String perm_ca_cert = copyAsset("permissions_ca_cert.pem");
        final String user_cert = copyAsset("tablet_cert.pem");
        final String user_private_cert = copyAsset("private_key.pem");
        final String user_perm_file = copyAsset("house1_signed.p7s");

        // Initialize OpenDDS by getting the Participant Factory
        ArrayList<String> args = new ArrayList<String>();
        args.add("-DCPSTransportDebugLevel");
        args.add("3");
        args.add("-DCPSDebugLevel");
        args.add("10");
        args.add("-DCPSConfigFile");
        args.add(config_file);

        if (secure) {
            args.add("-DCPSSecurity");
            args.add("1");
        }
        StringSeqHolder argsHolder = new StringSeqHolder(args.toArray(new String[args.size()]));
        participantFactory = TheParticipantFactory.WithArgs(argsHolder);
        if (participantFactory == null) {
            throw new InitOpenDDSException("ERROR: failed to get Domain Participant Factory");
        }

        // Determine Participant QOS
        List<Property_t> properties_list = new ArrayList<>();
        groups = getResources().getStringArray(R.array.groups);
        properties_list.add(new Property_t("OpenDDS.RtpsRelay.Groups",
                String.join(",", groups), true));

        if (secure) {
            final String f = "file://";
            properties_list.add(new Property_t("dds.sec.auth.identity_ca", f + id_ca_cert, false));
            properties_list.add(new Property_t("dds.sec.auth.identity_certificate", f + user_cert, false));
            properties_list.add(new Property_t("dds.sec.auth.private_key", f + user_private_cert, false));
            properties_list.add(new Property_t("dds.sec.access.permissions_ca", f + perm_ca_cert, false));
            properties_list.add(new Property_t("dds.sec.access.governance", f + gov_file, false));
            properties_list.add(new Property_t("dds.sec.access.permissions", f + user_perm_file, false));
        }
        participantQos = new DomainParticipantQos(
                PARTICIPANT_QOS_DEFAULT.get().user_data,
                PARTICIPANT_QOS_DEFAULT.get().entity_factory,
                new PropertyQosPolicy(
                        properties_list.toArray(new Property_t[properties_list.size()]),
                        new BinaryProperty_t[] {}));
    }

    private void startDds() {
        // Start OpenDDS
        String error_message = null;
        Throwable exception = null;
        if (getResources().getBoolean(R.bool.init_opendds)) {
            ConnectivityManager cm = (ConnectivityManager) getSystemService(CONNECTIVITY_SERVICE);
            NetworkInfo network = cm.getActiveNetworkInfo();
            boolean has_network = network != null && network.isConnectedOrConnecting();
            if (has_network) {
                try {
                    initParticipantFactory();
                } catch (InitOpenDDSException e) {
                    error_message = "Error Initializing OpenDDS";
                    exception = e;
                }
            } else {
                error_message = "No Network Connection, could not start OpenDDS, restart this app when connected to a network";
            }
        }
        if (error_message != null) {
            Toast.makeText(getApplicationContext(), error_message, Toast.LENGTH_LONG).show();
            if (exception != null) {
                Log.e(LOG_TAG, error_message, exception);
            } else {
                Log.e(LOG_TAG, error_message);
            }
        }

    }

    private void initParticipant() throws InitOpenDDSException {
        if (participant != null) {
            return;
        }

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
                newDefaultSubscriberQos(participant));
        copyPartitionQos(subscriberQos.value.partition);
        Subscriber sub = participant.create_subscriber(subscriberQos.value,
                null, DEFAULT_STATUS_MASK.value);
        if (sub == null) {
            throw new InitOpenDDSException("ERROR: Subscriber creation failed");
        }

        DataReaderQosHolder qosh = new DataReaderQosHolder(newDefaultDataReaderQos(sub));
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


        ParticipantLocationListener locationListener = new ParticipantLocationListener();
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
                newDefaultPublisherQos(participant));
        copyPartitionQos(publisherQos.value.partition);
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
            participantFactory.delete_participant(participant);
            participant = null;
        }
    }


    @Override
    public void onCreate() {
        startDds();

        if (getResources().getBoolean(R.bool.init_opendds)) {
            try {
                initParticipant();
            } catch (InitOpenDDSException exception) {
                final String error_message = "Error Initializing OpenDDS Participant";
                Log.e(LOG_TAG, error_message, exception);
                Toast.makeText(getApplicationContext(), error_message, Toast.LENGTH_LONG).show();
            }
        }
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        Log.i(LOG_TAG, "onStartCommand()");
        return START_NOT_STICKY;
    }

    @Override
    public IBinder onBind(Intent intent) {
        Log.i(LOG_TAG, "onBind()");
        return binder;
    }

    @Override
    public void onRebind(Intent intent) {
        Log.i(LOG_TAG, "onRebind()");
        super.onRebind(intent); }


    @Override
    public void onDestroy() {
        super.onDestroy();
        Log.i(LOG_TAG, "onDestroy()");

        // TODO: Cleanup service before destruction
        //participant.delete_contained_entities();
        //dw = null;
        //participantFactory.delete_participant(participant);
        //participant = null;

        //TheServiceParticipant.shutdown();

        stopSelf();
    }
}

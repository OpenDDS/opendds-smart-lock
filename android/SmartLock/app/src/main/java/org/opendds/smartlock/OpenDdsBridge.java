package org.opendds.smartlock;

import android.content.Context;
import android.content.res.AssetManager;
import android.content.res.Resources;
import android.net.ConnectivityManager;
import android.os.Handler;
import android.os.Looper;
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
import SmartLock.Control;
import SmartLock.ControlDataWriter;
import SmartLock.ControlDataWriterHelper;
import SmartLock.ControlTypeSupportImpl;
import SmartLock.StatusTypeSupportImpl;
import SmartLock.lock_t;
import SmartLock.vec2;

public class OpenDdsBridge extends Thread {
    private final static String LOG_TAG = "SmartLock_OpenDDS_Bridge";

    // need a persistent reference to avoid GC
    private static DomainParticipantFactory participantFactory;
    private static DomainParticipant participant = null;
    private static ParticipantLocationListener locationListener = null;
    private static DataWriter dw = null;

    private DomainParticipantQos participantQos;

    public boolean secure = false;
    private String debug_level = "3";
    private String transport_debug_level = "3";
    private final int DOMAIN = 1;
    private String[] groups;

    private final MainActivity activity;
    private final Context context;

    public OpenDdsBridge(MainActivity activity) {
        this.activity = activity;
        this.context = activity.getApplicationContext();
    }

    public void updateLockState(SmartLockStatus lockState)
    {
        boolean ret = false;
        if (dw != null) {
            Log.e("SmartLockFragment", "Writing Control Update " +
                    lockState.toString());
            ControlDataWriter control_dw = ControlDataWriterHelper.narrow(dw);

            Control control_message = new Control();
            control_message.lock = new lock_t();
            control_message.lock.id = lockState.id;
            control_message.lock.locked = (
                    lockState.state == SmartLockStatus.State.PENDING_LOCK ||
                    lockState.state == SmartLockStatus.State.LOCKED);
            control_message.lock.position = new vec2();

            int return_code = control_dw.write(control_message,
                    control_dw.register_instance(control_message));
            if (return_code != RETCODE_OK.value) {
                Log.e(LOG_TAG,
                        "Error writing control update, return code was" + return_code);
            }
            else {
                ret = true;
            }

        } else {
            Log.e(LOG_TAG, "Cant Send Control Update because Datawriter is null");
        }
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
        dr_qos.representation = new DataRepresentationQosPolicy();
        dr_qos.representation.value = new short[0];
        dr_qos.type_consistency = new TypeConsistencyEnforcementQosPolicy();
        dr_qos.type_consistency.kind = 2;
        dr_qos.type_consistency.ignore_member_names = false;
        dr_qos.type_consistency.force_type_validation = false;

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
        File new_file = new File(context.getFilesDir(), asset_path);
        final String full_path = new_file.getAbsolutePath();
        Log.d(LOG_TAG, "Writing Asset File ".concat(asset_path));
        Throwable exception = null;
        try {
            InputStream in = context.getAssets().open(asset_path, AssetManager.ACCESS_BUFFER);
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

    private String verifyCacheFileExists(String cache_path) throws InitOpenDDSException {
        File new_file = new File(context.getCacheDir().getPath() + File.separator + cache_path);
        Log.d(LOG_TAG, "verifyCacheFileExists: ".concat(new_file.getAbsolutePath()));
        if (!new_file.exists()){
            throw new InitOpenDDSException("Missing Cache File: " + new_file.getAbsolutePath());
        }
        return new_file.getAbsolutePath();
    }

    private void initParticipantFactory() throws InitOpenDDSException {
        if (participantFactory != null) {
            return;
        }

        try {
            secure = context.getResources().getBoolean(R.bool.secure_opendds);
        } catch (Resources.NotFoundException e) {
            Log.d(LOG_TAG, "Could not read 'secure_opendds' from config. Using default, 'false'");
            secure = false;
        }

        try {
            debug_level = context.getResources().getString(R.string.dcps_debug_level);
        } catch (Resources.NotFoundException e) {
            Log.d(LOG_TAG, "Could not read 'dcps_debug_level' from config. Using default, '3'");
            debug_level = "3";
        }

        try {
            debug_level = context.getResources().getString(R.string.dcps_transport_debug_level);
        } catch (Resources.NotFoundException e) {
            Log.d(LOG_TAG, "Could not read 'dcps_transport_debug_level' from config. Using default, '3'");
            transport_debug_level = "3";
        }

        // Ensure Config File and Security Files Exist
        final String config_file = copyAsset("opendds_config.ini");
        final String gov_file = verifyCacheFileExists(OpenDDSSecEnum.ACCESS_GOVERNANCE.getFilename());
        final String id_ca_cert = verifyCacheFileExists(OpenDDSSecEnum.AUTH_IDENTITY_CA.getFilename());
        final String perm_ca_cert = verifyCacheFileExists(OpenDDSSecEnum.ACCESS_PERMISSIONS_CA.getFilename());
        final String user_cert = verifyCacheFileExists(OpenDDSSecEnum.AUTH_IDENTITY_CERTIFICATE.getFilename());
        final String user_private_cert = verifyCacheFileExists(OpenDDSSecEnum.AUTH_PRIVATE_KEY.getFilename());
        final String user_perm_file = verifyCacheFileExists(OpenDDSSecEnum.ACCESS_PERMISSIONS.getFilename());

        // Initialize OpenDDS by getting the Participant Factory
        ArrayList<String> args = new ArrayList<String>();
        args.add("-DCPSTransportDebugLevel");
        args.add(transport_debug_level);
        args.add("-DCPSDebugLevel");
        args.add(debug_level);
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
        groups = context.getResources().getStringArray(R.array.groups);
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
        if (participant == null) {
            // Start OpenDDS
            String error_message = null;
            Throwable exception = null;
            if (context.getResources().getBoolean(R.bool.init_opendds)) {
                ConnectivityManager cm = (ConnectivityManager) context.getSystemService(Context.CONNECTIVITY_SERVICE);
                if (cm.getActiveNetwork() != null) {
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
                final String err = error_message;
                new Handler(Looper.getMainLooper()).post(new Runnable() {
                    @Override
                    public void run() {
                        Toast.makeText(context.getApplicationContext(), err, Toast.LENGTH_LONG).show();
                    }
                });

                if (exception != null) {
                    Log.e(LOG_TAG, error_message, exception);
                } else {
                    Log.e(LOG_TAG, error_message);
                }
            }
        }
    }

    private void initParticipant() throws InitOpenDDSException {
        if (participant != null) {
            return;
        }

        if (participantQos == null) {
            throw new InitOpenDDSException("ERROR: Domain participant QOS is not initialized");
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

        Topic status_topic = participant.create_topic("C.53.SmartLock Status",
                status_servant.get_type_name(),
                TOPIC_QOS_DEFAULT.get(),
                null,
                DEFAULT_STATUS_MASK.value);
        if (status_topic == null) {
            throw new InitOpenDDSException("ERROR: Status Topic creation failed");
        }

        SubscriberQosHolder subscriberQos = new SubscriberQosHolder(
                newDefaultSubscriberQos(participant));
        Subscriber sub = participant.create_subscriber(subscriberQos.value,
                null, DEFAULT_STATUS_MASK.value);
        if (sub == null) {
            throw new InitOpenDDSException("ERROR: Subscriber creation failed");
        }

        DataReaderQosHolder qosh = new DataReaderQosHolder(newDefaultDataReaderQos(sub));
        sub.get_default_datareader_qos(qosh);
        qosh.value.reliability.kind = ReliabilityQosPolicyKind.RELIABLE_RELIABILITY_QOS;
        qosh.value.history.kind = HistoryQosPolicyKind.KEEP_ALL_HISTORY_QOS;
        DataReaderListenerImpl listener = new DataReaderListenerImpl(activity);
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

        locationListener = new ParticipantLocationListener();

        int ret = bitDr.set_listener(locationListener, OpenDDS.DCPS.DEFAULT_STATUS_MASK.value);
        assert (ret == DDS.RETCODE_OK.value);

        // Create DDS Entities That Write Control

        ControlTypeSupportImpl control_servant = new ControlTypeSupportImpl();
        if (control_servant.register_type(participant, "") != RETCODE_OK.value) {
            throw new InitOpenDDSException("ERROR: Control register_type failed");
        }
        Topic control_topic = participant.create_topic("C.53.SmartLock Control",
                control_servant.get_type_name(),
                TOPIC_QOS_DEFAULT.get(),
                null,
                DEFAULT_STATUS_MASK.value);

        if (control_topic == null) {
            throw new InitOpenDDSException("ERROR: Control Topic creation failed");
        }

        PublisherQosHolder publisherQos = new PublisherQosHolder(
                newDefaultPublisherQos(participant));
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

    public void run() {
        startDds();
        try {
            initParticipant();
        } catch (InitOpenDDSException e) {
            e.printStackTrace();
        }
    }

    public static void shutdown() {
        Log.i(LOG_TAG, "Shutting down");

        // Cleanup service before destruction
        participant.delete_contained_entities();
        dw = null;
        participantFactory.delete_participant(participant);
        participant = null;
        TheServiceParticipant.shutdown();
    }
}

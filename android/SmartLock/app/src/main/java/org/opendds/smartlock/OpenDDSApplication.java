package org.opendds.smartlock;

import android.app.Application;
import android.content.res.AssetManager;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;
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
import OpenDDS.DCPS.TheParticipantFactory;

public class OpenDDSApplication extends Application {

    final static String LOG_TAG = "SmartLock_OpenDDSApplication";

    public boolean secure = false;

    public DomainParticipantFactory participantFactory;
    public DomainParticipantQos participantQos;

    private String[] groups;
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
        File new_file = new File(this.getFilesDir(), asset_path);
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

    @Override
    public void onCreate() {

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

        super.onCreate();
    }
}

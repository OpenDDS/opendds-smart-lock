package org.opendds.smartlock;

import android.util.Log;

import DDS.DataReader;
import DDS.LivelinessChangedStatus;
import DDS.RequestedDeadlineMissedStatus;
import DDS.RequestedIncompatibleQosStatus;
import DDS.SampleInfo;
import DDS.SampleInfoHolder;
import DDS.SampleLostStatus;
import DDS.SampleRejectedStatus;
import DDS.SubscriptionMatchedStatus;
import DDS._DataReaderListenerLocalBase;
import OpenDDS.DCPS.*;

public class ParticipantLocationListener extends _DataReaderListenerLocalBase {

    private static final String LOGTAG = "SmartLock_LocationListenerImpl";

    private String guidFormatter(byte[] guid) {
        StringBuilder g = new StringBuilder();
        for (int ctr = 0; ctr < guid.length; ++ctr) {
            g.append(String.format("%02x", guid[ctr]));
            if ((ctr + 1) %4 == 0 && ctr + 1 < guid.length) {
                g.append(".");
            }
        }
        return g.toString();
    }

    private String locationConverter(int loc)
    {
        String location = "";

        if ((loc & LOCATION_LOCAL.value) != 0) {
            location += "LOCAL ";
        }
        if ((loc & LOCATION_RELAY.value) != 0) {
            location += "RELAY ";
        }
        if ((loc & LOCATION_ICE.value) != 0) {
            location += "ICE ";
        }

        return location;
    }

    public ParticipantLocationListener() {
        super();
    }
    
    @Override
    public void on_requested_deadline_missed(DataReader dataReader, RequestedDeadlineMissedStatus requestedDeadlineMissedStatus) {
        Log.i(LOGTAG, "ParticipantLocationListener.on_requested_deadline_missed");
    }

    @Override
    public void on_requested_incompatible_qos(DataReader dataReader, RequestedIncompatibleQosStatus requestedIncompatibleQosStatus) {
        Log.i(LOGTAG, "ParticipantLocationListener.on_requested_incompatible_qos");
    }

    @Override
    public void on_sample_rejected(DataReader dataReader, SampleRejectedStatus sampleRejectedStatus) {
        Log.i(LOGTAG, "ParticipantLocationListener.on_sample_rejected");
    }

    @Override
    public void on_liveliness_changed(DataReader dataReader, LivelinessChangedStatus livelinessChangedStatus) {
        Log.i(LOGTAG, "ParticipantLocationListener.on_liveliness_changed");
    }

    @Override
    public synchronized void on_data_available(DataReader reader) {
        Log.i(LOGTAG, "ParticipantLocationListener.on_data_available");

        ParticipantLocationBuiltinTopicDataDataReader bitDataReader =
                ParticipantLocationBuiltinTopicDataDataReaderHelper.narrow(reader);

        if (bitDataReader == null)
        {
            System.err.println("ParticipantLocationListener on_data_available: narrow failed.");;
            System.exit(1);
        }

        ParticipantLocationBuiltinTopicDataHolder participant =
                new ParticipantLocationBuiltinTopicDataHolder(
                        new ParticipantLocationBuiltinTopicData(new byte[16], 0, 0, "", 0, "", 0, "", 0));
        SampleInfoHolder si = new SampleInfoHolder(new SampleInfo(0, 0, 0,
                new DDS.Time_t(), 0, 0, 0, 0, 0, 0, 0, false, 0));

        for (int status = bitDataReader.read_next_sample(participant, si);
             status == DDS.RETCODE_OK.value;
             status = bitDataReader.read_next_sample(participant, si)) {

            Log.i(LOGTAG, "Received ParticipantLocation " + locationConverter(participant.value.location) + " change = " +
                    participant.value.change_mask + " connection. GUID = " + guidFormatter(participant.value.guid) +
                    " local ip: " + participant.value.local_addr + " ice ip: " + participant.value.ice_addr + " relay ip: " + participant.value.relay_addr);
        }
    }

    @Override
    public void on_subscription_matched(DataReader dataReader, SubscriptionMatchedStatus subscriptionMatchedStatus) {
        Log.i(LOGTAG, "DataReaderListenerImpl.on_subscription_matched");
    }

    @Override
    public void on_sample_lost(DataReader dataReader, SampleLostStatus sampleLostStatus) {
        Log.i(LOGTAG, "DataReaderListenerImpl.on_sample_lost");
    }
}

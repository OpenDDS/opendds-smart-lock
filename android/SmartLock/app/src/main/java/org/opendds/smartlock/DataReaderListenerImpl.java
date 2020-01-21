package org.opendds.smartlock;

import DDS.DataReader;
import DDS.LivelinessChangedStatus;
import DDS.NOT_ALIVE_DISPOSED_INSTANCE_STATE;
import DDS.NOT_ALIVE_NO_WRITERS_INSTANCE_STATE;
import DDS.RETCODE_NO_DATA;
import DDS.RETCODE_OK;
import DDS.RequestedDeadlineMissedStatus;
import DDS.RequestedIncompatibleQosStatus;
import DDS.SampleInfo;
import DDS.SampleInfoHolder;
import DDS.SampleLostStatus;
import DDS.SampleRejectedStatus;
import DDS.SubscriptionMatchedStatus;
import DDS._DataReaderListenerLocalBase;

import SmartLock.*;

import android.app.Application;
import android.content.Context;
import android.content.Intent;
import android.os.Handler;
import android.support.v4.content.LocalBroadcastManager;
import android.util.Log;

public class DataReaderListenerImpl extends _DataReaderListenerLocalBase {

    private static final String LOGTAG = "SmartLock_DataReaderListenerImpl";

    private Context context;

    public DataReaderListenerImpl(OpenDdsService svc) {
        super();
        this.context = svc.getApplicationContext();
    }
    
    @Override
    public void on_requested_deadline_missed(DataReader dataReader, RequestedDeadlineMissedStatus requestedDeadlineMissedStatus) {
        Log.i(LOGTAG, "DataReaderListenerImpl.on_requested_deadline_missed");
    }

    @Override
    public void on_requested_incompatible_qos(DataReader dataReader, RequestedIncompatibleQosStatus requestedIncompatibleQosStatus) {
        Log.i(LOGTAG, "DataReaderListenerImpl.on_requested_incompatible_qos");
    }

    @Override
    public void on_sample_rejected(DataReader dataReader, SampleRejectedStatus sampleRejectedStatus) {
        Log.i(LOGTAG, "DataReaderListenerImpl.on_sample_rejected");
    }

    @Override
    public void on_liveliness_changed(DataReader dataReader, LivelinessChangedStatus livelinessChangedStatus) {
        Log.i(LOGTAG, "DataReaderListenerImpl.on_liveliness_changed");
    }

    @Override
    public synchronized void on_data_available(DataReader reader) {
        StatusDataReader mdr = StatusDataReaderHelper.narrow(reader);
        if (mdr == null) {
            Log.e(LOGTAG, "ERROR: read: narrow failed.");
            return;
        }

        lock_t lock_holder = new lock_t();
        lock_holder.position = new vec2();
        StatusHolder mh = new StatusHolder(new Status(lock_holder));
        SampleInfoHolder sih = new SampleInfoHolder(new SampleInfo(0, 0, 0,
                new DDS.Time_t(), 0, 0, 0, 0, 0, 0, 0, false, 0));
        int status = mdr.take_next_sample(mh, sih);

        if (status == RETCODE_OK.value) {

            Log.d(LOGTAG, "SampleInfo.sample_rank = " + sih.value.sample_rank);
            Log.d(LOGTAG, "SampleInfo.instance_state = " + sih.value.instance_state);

            final SmartLockStatus lock_status = new SmartLockStatus();
            lock_status.id = mh.value.lock.id;

            if (sih.value.valid_data) {
                lock_status.state = mh.value.lock.locked ? SmartLockStatus.State.LOCKED :
                                        SmartLockStatus.State.UNLOCKED;
                lock_status.enabled = true;

                Log.d(LOGTAG, "Got: " + lock_status.toString());
            }
            else if (sih.value.instance_state ==
                    NOT_ALIVE_DISPOSED_INSTANCE_STATE.value) {
                lock_status.enabled = false;
                Log.i(LOGTAG, "instance is disposed");

            }
            else if (sih.value.instance_state ==
                    NOT_ALIVE_NO_WRITERS_INSTANCE_STATE.value) {
                lock_status.enabled = false;
                Log.i(LOGTAG, "instance is unregistered");
            }
            else {
                lock_status.enabled = false;
                Log.e(LOGTAG, "DataReaderListenerImpl::on_data_available: "
                        + "ERROR: received unknown instance state "
                        + sih.value.instance_state);
            }

            // use local broadcast to communicate between service and UI
            Intent intent = new Intent(OpenDdsService.LOCK_UPDATE_MESSAGE);
            intent.putExtra(OpenDdsService.LOCK_STATUS_DATA, lock_status);
            LocalBroadcastManager.getInstance(context).sendBroadcast(intent);

        } else if (status == RETCODE_NO_DATA.value) {
            Log.e(LOGTAG, "ERROR: reader received DDS::RETCODE_NO_DATA!");
        } else {
            Log.e(LOGTAG, "ERROR: read Message: Error: " + status);
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

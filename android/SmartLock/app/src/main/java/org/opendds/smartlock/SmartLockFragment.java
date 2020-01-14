package org.opendds.smartlock;

import android.arch.lifecycle.ViewModelProviders;
import android.os.Bundle;
import android.support.annotation.NonNull;
import android.support.annotation.Nullable;
import android.support.v4.app.Fragment;
import android.support.v4.app.FragmentManager;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.util.Log;
import android.widget.CompoundButton;
import android.widget.EditText;
import android.widget.ImageView;
import android.widget.Switch;
import android.widget.TextView;

import DDS.DataWriter;
import DDS.RETCODE_OK;
import SmartLock.Control;
import SmartLock.ControlDataWriter;
import SmartLock.ControlDataWriterHelper;
import SmartLock.lock_t;
import SmartLock.vec2;

public class SmartLockFragment extends Fragment {
    public static int count = 0;

    private SmartLockViewModel mViewModel;
    public String id_string;
    public int id_int;
    private SmartLockStatus set_status = null;
    public DataWriter dw;

    // use a local copy of view since calls to getView()
    // after a screen orientation change can be null
    private View mView;

    public static SmartLockFragment newInstance() {
        return new SmartLockFragment();
    }

    public void disable() {
        mViewModel.value.enabled = false;
        updateView();
    }

    public void enable() {
        mViewModel.value.enabled = true;
        updateView();
    }

    private void updateView() {
//        getView().findViewById(R.id.container).setVisibility(
//                mViewModel.value.enabled ? View.GONE : View.VISIBLE);
//
//        if (! mViewModel.value.enabled) return;

        boolean enabled = mViewModel.value.enabled;

        if (enabled) {
            if (isHidden()) {
                FragmentManager fm = getFragmentManager();
                fm.beginTransaction()
                        .setCustomAnimations(android.R.animator.fade_in, android.R.animator.fade_out)
                        .show(this)
                        .commit();
            }
            TextView lock_id_tv = (TextView) mView.findViewById(R.id.lock_id);
            lock_id_tv.setText(mViewModel.value.id);

            ImageView lock_status_img = mView.findViewById(R.id.lock_status);
            Switch lock_sw = (Switch) mView.findViewById(R.id.lock_switch);

            if (mViewModel.value.state == SmartLockStatus.State.LOCKED) {
                lock_status_img.setImageResource(R.drawable.fa_lock_closed);
                lock_sw.setChecked(true);

            } else if (mViewModel.value.state == SmartLockStatus.State.UNLOCKED){
                lock_status_img.setImageResource(R.drawable.fa_lock_open);
                lock_sw.setChecked(false);

            } else if (mViewModel.value.state == SmartLockStatus.State.PENDING_LOCK) {
                lock_sw.setChecked(true);

            } else if (mViewModel.value.state == SmartLockStatus.State.PENDING_UNLOCK) {
                lock_sw.setChecked(false);
            }

        } else {
            if (! isHidden()) {
                FragmentManager fm = getFragmentManager();
                fm.beginTransaction()
                        .setCustomAnimations(android.R.animator.fade_in, android.R.animator.fade_out)
                        .hide(this)
                        .commitAllowingStateLoss ();
            }
        }
    }

    private void updateControl() {
        if (dw != null) {
            Log.e("SmartLockFragment", "Writing Control Update " +
                                                    mViewModel.value.toString());
            ControlDataWriter control_dw = ControlDataWriterHelper.narrow(dw);

            Control control_message = new Control();
            control_message.lock = new lock_t();
            control_message.lock.id = mViewModel.value.id;
            boolean lockthis = mViewModel.value.state == SmartLockStatus.State.PENDING_LOCK ||
                    mViewModel.value.state == SmartLockStatus.State.LOCKED;

            control_message.lock.locked = lockthis;
            control_message.lock.position = new vec2();

            int return_code = control_dw.write(control_message,
                                                control_dw.register_instance(control_message));
            if (return_code != RETCODE_OK.value) {
                Log.e("SmartLockFragment",
                        "Error writing control update, return code was" + String.valueOf(return_code));
            }
        } else {
            Log.e("SmartLockFragment", "Cant Send Control Update because Datawriter is null");
        }
    }

    public void setStatus(SmartLockStatus status) {
        if (mViewModel == null) {
            set_status = status;
        } else {
            mViewModel.value = status;
            updateView();
        }
    }

    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container,
                             @Nullable Bundle savedInstanceState) {
        id_int = count++;
        id_string = "smart_lock_fragment_".concat(String.valueOf(id_int));
        mView = inflater.inflate(R.layout.smart_lock_fragment, container, false);
        return mView;
    }

    @Override
    public void onActivityCreated(@Nullable Bundle savedInstanceState) {
        super.onActivityCreated(savedInstanceState);
        mViewModel = ViewModelProviders.of(this).get(SmartLockViewModel.class);

        if (set_status == null) {
            updateView();
        } else {
            setStatus(set_status);
        }

        final SmartLockFragment fragment = this;

        Switch sw = (Switch) mView.findViewById(R.id.lock_switch);

        sw.setOnCheckedChangeListener(new CompoundButton.OnCheckedChangeListener() {
            @Override
            public void onCheckedChanged(CompoundButton buttonView, boolean isChecked) {
                if (isChecked) {
                    // Toggle enabled
                    mViewModel.value.state = SmartLockStatus.State.PENDING_LOCK;

                } else {
                    // Toggle disabled
                    mViewModel.value.state = SmartLockStatus.State.PENDING_UNLOCK;
                }
                updateView();
                updateControl();
            }
        });
//        sw.setOnClickListener(new View.OnClickListener() {
//            public void onClick(View v) {
//                Switch s = (Switch) v;
//                s.toggle();
//                lock_toggle();
//            }
//        });
    }

}

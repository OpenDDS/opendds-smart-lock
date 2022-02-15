package org.opendds.smartlock;

import androidx.lifecycle.ViewModelProviders;
import android.os.Bundle;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import androidx.fragment.app.FragmentManager;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.util.Log;
import android.widget.CompoundButton;
import android.widget.ImageView;
import android.widget.Switch;
import android.widget.TextView;

public class SmartLockFragment extends Fragment {
    public static int count = 0;

    private SmartLockViewModel mViewModel;
    public String id_string;
    public int id_int;
    private SmartLockStatus set_status = null;
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
        boolean enabled = mViewModel.value.enabled;

        if (enabled) {
            if (isHidden()) {
                FragmentManager fm = getFragmentManager();
                fm.beginTransaction()
                        .setCustomAnimations(android.R.animator.fade_in, android.R.animator.fade_out)
                        .show(this)
                        .commit();
            }
            TextView lock_id_tv = mView.findViewById(R.id.lock_id);
            lock_id_tv.setText(mViewModel.value.id);

            ImageView lock_status_img = mView.findViewById(R.id.lock_status);
            Switch lock_sw = mView.findViewById(R.id.lock_switch);

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
        if (MainActivity.getDdsBridge() != null) {
            MainActivity.getDdsBridge().updateLockState(mViewModel.value);
        } else {
            Log.e("SmartLockFragment", "Cant Send Control Update because DDS reference is null");
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

        Switch sw = mView.findViewById(R.id.lock_switch);

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
    }
}

package org.opendds.smartlock.data;

import android.os.AsyncTask;

import org.opendds.smartlock.OpenDDSSec;
import org.opendds.smartlock.data.model.LoggedInUser;

import java.io.IOException;

/**
 * Class that handles authentication w/ login credentials and retrieves user information.
 */
public class LoginDataSource {

    public Result<LoggedInUser> login(String username, String password, String dpm_url, String nonce) {

        try {
            new OpenDDSSec.Download(dpm_url,username, password, nonce).executeOnExecutor(AsyncTask.THREAD_POOL_EXECUTOR);
            LoggedInUser fakeUser = new LoggedInUser(java.util.UUID.randomUUID().toString(), "54");
            return new Result.Success<>(fakeUser);
        } catch (Exception e) {
            return new Result.Error(new IOException("Error logging in", e));
        }
    }

    public void logout() {
        // TODO: revoke authentication
    }
}
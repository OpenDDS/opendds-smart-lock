package org.opendds.smartlock;

import static java.net.HttpURLConnection.HTTP_OK;
import static java.net.HttpURLConnection.HTTP_SEE_OTHER;

import android.os.AsyncTask;
import android.text.TextUtils;
import android.util.Log;

import org.json.JSONException;
import org.json.JSONObject;

import java.io.BufferedOutputStream;
import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.io.OutputStreamWriter;
import java.net.CookiePolicy;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Map;
import java.net.HttpCookie;

import javax.net.ssl.HttpsURLConnection;

public class OpenDDSSec {
    private static final String LOG_TAG = "SmartLock_OpenDDSSec";
    private static final String COOKIES_HEADER = "Set-Cookie";
    private static final String KEYPAIR = "key_pair";
    private static java.net.CookieManager cookieManager = new java.net.CookieManager(null, CookiePolicy.ACCEPT_ALL);
    private static File cacheDir_ = null;

    public static void setCacheDir(File cacheDir) {
        cacheDir_ = cacheDir;
    }

    public static File getCacheDir() {
        return cacheDir_;
    }

    public static boolean hasFiles() {
        if (cacheDir_ != null) {
            File cacheDir = getCacheDir();
            for (OpenDDSSecEnum secfile : OpenDDSSecEnum.values()) {
                File tmpFile = new File(cacheDir.getPath() + File.separator + secfile.getFilename());
                if (!tmpFile.exists()) {
                    Log.d(LOG_TAG, "Can't find file " + tmpFile.getAbsolutePath());
                    return false;
                }
            }
            return true; // all filenames exist
        }
        return false; // cacheDir_ is null
    }

    public static void setMainActivity(MainActivity mainActivity) {
        OpenDDSSec.mainActivity = mainActivity;
    }

    public static MainActivity getMainActivity() {
        return mainActivity;
    }

    private static MainActivity mainActivity;

    private static boolean login(String dpm_url, String username, String password) {
        boolean rc = false;
        HttpsURLConnection urlConnection = null;
        try {
            JSONObject postData = new JSONObject();
            postData.put("username", username);
            postData.put("password", password);

            String sb = "https://" + dpm_url + "/api/login";
            URL url = new URL(sb);

            urlConnection = (HttpsURLConnection) url.openConnection();
            urlConnection.setRequestProperty("Content-Type", "application/json");
            urlConnection.setRequestProperty("Accept", "*/*");
            urlConnection.setRequestMethod("POST");
            urlConnection.setDoOutput(true);
            urlConnection.setDoInput(true);
            urlConnection.setChunkedStreamingMode(0);
            urlConnection.setInstanceFollowRedirects(false);

            OutputStream out = new BufferedOutputStream(urlConnection.getOutputStream());
            BufferedWriter writer = new BufferedWriter(new OutputStreamWriter(out, StandardCharsets.UTF_8));
            writer.write(postData.toString());
            writer.flush();

            int code = urlConnection.getResponseCode();
            if (code != HTTP_SEE_OTHER) {
                throw new IOException("Invalid response from server: " + code);
            }

            Map<String, List<String>> headerFields = urlConnection.getHeaderFields();
            List<String> cookiesHeader = headerFields.get(COOKIES_HEADER);

            if (cookiesHeader != null) {
                for (String cookie : cookiesHeader) {
                    cookieManager.getCookieStore().add(null, HttpCookie.parse(cookie).get(0));
                }
                Log.d(LOG_TAG, "login cookies found");
                rc = true;
            } else {
                Log.d(LOG_TAG, "login cookies not found");
            }

        } catch (IOException | JSONException e) {
            Log.e(LOG_TAG, "login exception" + e.toString());
        } finally {
            if (urlConnection != null) {
                urlConnection.disconnect();
            }
        }
        return rc;
    }
    private static void writeSecurityFile(String filename, String content) throws IOException {
        File new_file = new File(getCacheDir().getPath() + File.separator + filename);
        FileOutputStream out = new FileOutputStream(new_file);
        out.write(content.getBytes(StandardCharsets.UTF_8));
        out.close();
        Log.i(new_file.getAbsolutePath(), content);
    }

    private static void download(String dpm_url, String filename, String nonce) {
        HttpsURLConnection urlConnection = null;
        try {

            StringBuilder sb = new StringBuilder("https://");
            sb.append(dpm_url);
            sb.append("/api/applications/");
            sb.append(filename);
            if (nonce != null) {
                sb.append("?nonce=");
                sb.append(nonce);
            }
            URL url = new URL(sb.toString());

            urlConnection = (HttpsURLConnection) url.openConnection();

            if (cookieManager.getCookieStore().getCookies().size() > 0) {
                // While joining the Cookies, use ',' or ';' as needed. Most of the servers are using ';'
                urlConnection.setRequestProperty("Cookie", TextUtils.join(";", cookieManager.getCookieStore().getCookies()));
            }

            int responseCode = urlConnection.getResponseCode();
            if (responseCode != HTTP_OK) {
                throw new IOException("Invalid response from server: " + responseCode);
            }

            BufferedReader rd = new BufferedReader(new InputStreamReader(urlConnection.getInputStream()));
            String line;
            StringBuilder response = new StringBuilder();
            while ((line = rd.readLine()) != null) {
                response.append(line);
                response.append(System.lineSeparator());
            }
            rd.close();
            if (KEYPAIR.equals(filename)) {
                JSONObject keypair_json = new JSONObject(response.toString());
                writeSecurityFile(OpenDDSSecEnum.AUTH_PRIVATE_KEY.getFilename(), keypair_json.optString("private"));
                writeSecurityFile(OpenDDSSecEnum.AUTH_IDENTITY_CERTIFICATE.getFilename(), keypair_json.optString("public"));
            } else {
                writeSecurityFile(filename, response.toString());
            }
        } catch (IOException | JSONException e) {
            Log.e(LOG_TAG, "download exception " + e.toString());
        } finally {
            if (urlConnection != null) {
                urlConnection.disconnect();
            }
        }
    }

    public static class Download extends AsyncTask<Void, Void, Void> {
        private String username_ = "54";
        private String password_ = "AlEMeGU3y45G1hIu";
        private String nonce_ = "NONCE";
        private String dpm_url_ = "dpm.unityfoundation.io";

        public Download(String dpm_url, String username, String password, String nonce) {

            if (dpm_url != null && !dpm_url.isEmpty()) {
                this.dpm_url_ = dpm_url;
            }
            if (username != null && !username.isEmpty()) {
                this.username_ = username;
            }
            if (password != null && !password.isEmpty()) {
                this.password_ = password;
            }
            if (nonce != null && !nonce.isEmpty()) {
                this.nonce_ = nonce;
            }
        }

        @Override
        protected Void doInBackground(Void... params) {
            if (login(this.dpm_url_, this.username_, this.password_)) {
                download(this.dpm_url_, OpenDDSSecEnum.AUTH_IDENTITY_CA.getFilename(), null);
                download(this.dpm_url_, OpenDDSSecEnum.ACCESS_PERMISSIONS_CA.getFilename(), null);
                download(this.dpm_url_, OpenDDSSecEnum.ACCESS_GOVERNANCE.getFilename(), null);
                download(this.dpm_url_, KEYPAIR, this.nonce_);
                download(this.dpm_url_, OpenDDSSecEnum.ACCESS_PERMISSIONS.getFilename(), this.nonce_);
            }
            return null;
        }


        @Override
        protected void onPostExecute(Void unused) {
            super.onPostExecute(unused);
            Log.d(LOG_TAG, "onPostExecute called");
            if (getMainActivity() != null) {
                getMainActivity().removeLogin();
                getMainActivity().startDDSBridge();
            }
        }
    }
}

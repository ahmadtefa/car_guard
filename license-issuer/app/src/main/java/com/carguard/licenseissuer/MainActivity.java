package com.carguard.licenseissuer;

import android.app.Activity;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.text.InputType;
import android.view.View;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.Spinner;
import android.widget.TextView;
import android.widget.Toast;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.Arrays;

/** Offline admin/owner-only issuer UI. */
public final class MainActivity extends Activity {
    private static final int REQUEST_OPEN_PRIVATE_KEY = 4101;
    private static final int MAX_KEY_FILE_BYTES = 65536;

    private EditText serialInput;
    private Spinner typeInput;
    private EditText monthsInput;
    private TextView keyStatus;
    private TextView creationDateStatus;
    private TextView resultMetadata;
    private TextView codeOutput;
    private Button generateButton;
    private Button copyButton;

    // Deliberately held only in the Activity instance. It is never serialized,
    // written to preferences, copied to a file, or sent over the network.
    private LicenseProtocol.LoadedKey loadedKey;
    private String generatedCode;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        serialInput = findViewById(R.id.serial_input);
        typeInput = findViewById(R.id.type_input);
        monthsInput = findViewById(R.id.months_input);
        keyStatus = findViewById(R.id.key_status);
        creationDateStatus = findViewById(R.id.creation_date_status);
        resultMetadata = findViewById(R.id.result_metadata);
        codeOutput = findViewById(R.id.code_output);
        generateButton = findViewById(R.id.generate_button);
        copyButton = findViewById(R.id.copy_button);

        serialInput.setText("KCG_005B6EAC");
        monthsInput.setText("1");
        creationDateStatus.setText("Creation date metadata: current UTC date at generation");
        codeOutput.setTextIsSelectable(true);

        ArrayAdapter<CharSequence> adapter = ArrayAdapter.createFromResource(
                this, R.array.license_types, android.R.layout.simple_spinner_item);
        adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
        typeInput.setAdapter(adapter);
        typeInput.setSelection(0);
        typeInput.setOnItemSelectedListener(new SimpleItemSelectedListener() {
            @Override
            public void onItemSelected(int position) {
                boolean temporary = position == 0;
                monthsInput.setEnabled(temporary);
                if (!temporary) {
                    monthsInput.setText("0");
                } else if ("0".contentEquals(monthsInput.getText())) {
                    monthsInput.setText("1");
                }
            }
        });

        findViewById(R.id.import_key_button).setOnClickListener(v -> openPrivateKeyPicker());
        generateButton.setOnClickListener(v -> generateCode());
        copyButton.setOnClickListener(v -> copyCode());
        findViewById(R.id.clear_button).setOnClickListener(v -> clearForm());

        setKeyUnavailable();
        setResultUnavailable();
    }

    private void openPrivateKeyPicker() {
        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        // PEM files are commonly reported with text/plain or application/octet-stream;
        // validate the selected bytes ourselves instead of relying on MIME metadata.
        intent.setType("*/*");
        startActivityForResult(intent, REQUEST_OPEN_PRIVATE_KEY);
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode != REQUEST_OPEN_PRIVATE_KEY || resultCode != RESULT_OK || data == null) {
            return;
        }
        Uri uri = data.getData();
        if (uri == null) {
            showError("No key file was selected");
            return;
        }

        byte[] pemBytes = null;
        try {
            pemBytes = readAtMost(uri, MAX_KEY_FILE_BYTES);
            LicenseProtocol.LoadedKey candidate =
                    LicenseProtocol.loadAndValidatePrivateKey(pemBytes);
            // Only retain the parsed key object after the production fingerprint
            // has already been checked by loadAndValidatePrivateKey().
            loadedKey = candidate;
            keyStatus.setText("Production P-256 key loaded; fingerprint verified");
            keyStatus.setTextColor(0xff197a30);
            generateButton.setEnabled(true);
            showInfo("Key imported in memory only");
        } catch (Exception e) {
            loadedKey = null;
            setKeyUnavailable();
            showError("Key rejected: invalid P-256 key or production fingerprint mismatch");
        } finally {
            if (pemBytes != null) {
                Arrays.fill(pemBytes, (byte) 0);
            }
        }
    }

    private void generateCode() {
        if (loadedKey == null) {
            showError("Import and verify the production private key first");
            return;
        }
        try {
            String serial = serialInput.getText().toString().trim();
            int type = typeInput.getSelectedItemPosition() == 0
                    ? LicenseProtocol.LICENSE_TEMPORARY
                    : LicenseProtocol.LICENSE_PERMANENT;
            int months = parseMonths(monthsInput.getText().toString(), type);
            LocalDate creationDate = LocalDate.now(ZoneOffset.UTC);
            LicenseProtocol.LicenseResult result = LicenseProtocol.generate(
                    serial, type, months, creationDate, loadedKey);

            generatedCode = result.code;
            resultMetadata.setText(
                    "Device Serial: " + result.serial + "\n" +
                    "License Type: " + (result.type == LicenseProtocol.LICENSE_TEMPORARY
                            ? "TEMPORARY" : "PERMANENT") + "\n" +
                    "Months: " + result.months + "\n" +
                    "Creation Date (UTC metadata): " + result.creationDateUtc + "\n" +
                    "Binary length: 83 bytes\n" +
                    "Code length: 133 characters");
            codeOutput.setText(generatedCode);
            copyButton.setEnabled(true);
            showInfo("Code generated locally; nothing was uploaded");
        } catch (LicenseProtocol.ProtocolException | NumberFormatException e) {
            generatedCode = null;
            copyButton.setEnabled(false);
            codeOutput.setText("");
            showError(e.getMessage() == null ? "Could not generate code" : e.getMessage());
        }
    }

    private int parseMonths(String text, int type) throws LicenseProtocol.ProtocolException {
        if (type == LicenseProtocol.LICENSE_PERMANENT) {
            return LicenseProtocol.validateMonths(type, 0);
        }
        if (text == null || text.trim().isEmpty()) {
            throw new LicenseProtocol.ProtocolException("Months is required for TEMPORARY");
        }
        return LicenseProtocol.validateMonths(type, Integer.parseInt(text.trim()));
    }

    private void copyCode() {
        if (generatedCode == null || generatedCode.isEmpty()) {
            showError("Generate a code first");
            return;
        }
        ClipboardManager clipboard = (ClipboardManager) getSystemService(CLIPBOARD_SERVICE);
        clipboard.setPrimaryClip(ClipData.newPlainText("Car Guard activation code", generatedCode));
        showInfo("Activation code copied to clipboard");
    }

    private void clearForm() {
        // Best-effort clearing: Java/Android providers do not expose a way to
        // wipe the internals of an already-parsed PrivateKey object.
        loadedKey = null;
        generatedCode = null;
        serialInput.setText("");
        typeInput.setSelection(0);
        monthsInput.setText("1");
        codeOutput.setText("");
        resultMetadata.setText("");
        copyButton.setEnabled(false);
        setKeyUnavailable();
        showInfo("Form cleared; key was discarded from app state");
    }

    private void setKeyUnavailable() {
        keyStatus.setText("No production key loaded");
        keyStatus.setTextColor(0xff9b1c1c);
        generateButton.setEnabled(false);
    }

    private void setResultUnavailable() {
        resultMetadata.setText("");
        codeOutput.setText("");
        copyButton.setEnabled(false);
    }

    private byte[] readAtMost(Uri uri, int maxBytes) throws IOException {
        try (InputStream input = getContentResolver().openInputStream(uri)) {
            if (input == null) {
                throw new IOException("Cannot open selected file");
            }
            ByteArrayOutputStream output = new ByteArrayOutputStream();
            byte[] buffer = new byte[4096];
            int total = 0;
            int count;
            while ((count = input.read(buffer)) != -1) {
                total += count;
                if (total > maxBytes) {
                    throw new IOException("Selected key file is too large");
                }
                output.write(buffer, 0, count);
            }
            return output.toByteArray();
        }
    }

    private void showInfo(String message) {
        Toast.makeText(this, message, Toast.LENGTH_SHORT).show();
    }

    private void showError(String message) {
        Toast.makeText(this, message, Toast.LENGTH_LONG).show();
    }

    @Override
    protected void onDestroy() {
        loadedKey = null;
        generatedCode = null;
        super.onDestroy();
    }

    private abstract static class SimpleItemSelectedListener
            implements android.widget.AdapterView.OnItemSelectedListener {
        @Override
        public void onNothingSelected(android.widget.AdapterView<?> parent) {
            // No action.
        }

        public abstract void onItemSelected(int position);

        @Override
        public final void onItemSelected(android.widget.AdapterView<?> parent, View view,
                                         int position, long id) {
            onItemSelected(position);
        }
    }
}

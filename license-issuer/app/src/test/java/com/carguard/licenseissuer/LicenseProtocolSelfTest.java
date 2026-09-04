package com.carguard.licenseissuer;

import java.nio.charset.StandardCharsets;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.spec.ECGenParameterSpec;
import java.time.LocalDate;
import java.util.Arrays;
import java.util.Base64;

/** Plain-JVM, dependency-free protocol tests. Never prints a generated code. */
public final class LicenseProtocolSelfTest {
    private static final String OLD_PRODUCTION_FINGERPRINT =
            "413c36ade83f4fc43207e4434cc3c0099692ee217134c3d47ad8bcc223481a94";
    private static final String NEW_PRODUCTION_FINGERPRINT =
            "d0de642207cab1f8a88f4e6d6bd120dd05497fb2b3652df0e161beec0ad35e5f";
    private static int passed;

    public static void main(String[] args) throws Exception {
        KeyPairGenerator generator = KeyPairGenerator.getInstance("EC");
        generator.initialize(new ECGenParameterSpec("secp256r1"));
        KeyPair testKey = generator.generateKeyPair();
        check("expected production fingerprint format",
                LicenseProtocol.EXPECTED_PUBLIC_KEY_FINGERPRINT.matches("[0-9a-f]{64}"));
        check("new production fingerprint is configured",
                LicenseProtocol.EXPECTED_PUBLIC_KEY_FINGERPRINT.equals(NEW_PRODUCTION_FINGERPRINT));
        check("old production fingerprint is rejected",
                !LicenseProtocol.EXPECTED_PUBLIC_KEY_FINGERPRINT.equals(OLD_PRODUCTION_FINGERPRINT));

        byte[] payload = LicenseProtocol.buildPayload(
                "KCG_005B6EAC", LicenseProtocol.LICENSE_TEMPORARY,
                LocalDate.of(2026, 9, 5), 1);
        check("payload length = 19", payload.length == 19);
        check("target serial bytes", new String(payload, 1, 12, StandardCharsets.US_ASCII)
                .equals("KCG_005B6EAC"));
        check("temporary type = 0", (payload[13] & 0xff) == 0);
        check("months = 1", (payload[18] & 0xff) == 1);

        byte[] signature = LicenseProtocol.signPayload(payload, testKey.getPrivate());
        check("signature length = 64", signature.length == 64);
        check("signature verifies", LicenseProtocol.verifySignature(
                payload, signature, testKey.getPublic()));

        byte[] decoded = new byte[LicenseProtocol.DECODED_LENGTH];
        System.arraycopy(payload, 0, decoded, 0, payload.length);
        System.arraycopy(signature, 0, decoded, payload.length, signature.length);
        check("final binary length = 83", decoded.length == 83);
        String code = LicenseProtocol.encodeBase32(decoded);
        check("Base32 length = 133", code.length() == 133);
        check("Base32 uppercase/no padding", code.matches("[A-Z2-7]{133}"));
        check("Base32 round-trip", Arrays.equals(decoded, LicenseProtocol.decodeBase32(code)));

        byte[] tamperedSignature = signature.clone();
        tamperedSignature[0] ^= 0x01;
        check("invalid signature rejected", !LicenseProtocol.verifySignature(
                payload, tamperedSignature, testKey.getPublic()));

        expectProtocolError("invalid private key", () ->
                LicenseProtocol.loadAndValidatePrivateKey("not a PEM key".getBytes(StandardCharsets.US_ASCII)));
        String pemDashes = "-----";
        String pemBegin = "BEGIN";
        String pemEnd = "END";
        String pemLabel = "PRIVATE" + " " + "KEY";
        String testPem = pemDashes + pemBegin + " " + pemLabel + pemDashes + "\n"
                + Base64.getMimeEncoder(64, new byte[]{'\n'}).encodeToString(
                testKey.getPrivate().getEncoded())
                + "\n" + pemDashes + pemEnd + " " + pemLabel + pemDashes + "\n";
        expectProtocolError("wrong public-key fingerprint", () ->
                LicenseProtocol.loadAndValidatePrivateKey(testPem.getBytes(StandardCharsets.US_ASCII)));
        expectProtocolError("wrong serial", () -> LicenseProtocol.buildPayload(
                "KCG_005B6EaC", LicenseProtocol.LICENSE_TEMPORARY,
                LocalDate.of(2026, 9, 5), 1));
        expectProtocolError("temporary months = 0", () -> LicenseProtocol.validateMonths(
                LicenseProtocol.LICENSE_TEMPORARY, 0));
        expectProtocolError("temporary months = 121", () -> LicenseProtocol.validateMonths(
                LicenseProtocol.LICENSE_TEMPORARY, 121));

        String testPointFingerprint = LicenseProtocol.firmwarePointFingerprint(testKey.getPublic());
        String testSpkiFingerprint = LicenseProtocol.subjectPublicKeyInfoFingerprint(testKey.getPublic());
        check("fingerprint helper accepts firmware point", LicenseProtocol.fingerprintMatches(
                testKey.getPublic(), testPointFingerprint));
        check("fingerprint helper accepts SPKI DER", LicenseProtocol.fingerprintMatches(
                testKey.getPublic(), testSpkiFingerprint));
        check("wrong public-key fingerprint rejected", !LicenseProtocol.fingerprintMatches(
                testKey.getPublic(), "0000000000000000000000000000000000000000000000000000000000000000"));
        check("old production fingerprint rejected by matcher", !LicenseProtocol.fingerprintMatches(
                testKey.getPublic(), OLD_PRODUCTION_FINGERPRINT));

        byte[] wrongSerialPayload = LicenseProtocol.buildPayload(
                "KCG_00000000", LicenseProtocol.LICENSE_TEMPORARY,
                LocalDate.of(2026, 9, 5), 1);
        check("wrong serial is not target binding", !Arrays.equals(
                Arrays.copyOfRange(wrongSerialPayload, 1, 13),
                Arrays.copyOfRange(payload, 1, 13)));
        byte[] targetSignature = LicenseProtocol.signPayload(payload, testKey.getPrivate());
        byte[] otherSignature = LicenseProtocol.signPayload(wrongSerialPayload, testKey.getPrivate());
        String targetCode = LicenseProtocol.encodeBase32(concat(payload, targetSignature));
        String otherCode = LicenseProtocol.encodeBase32(concat(wrongSerialPayload, otherSignature));
        check("same global key produces different serial-bound codes", !targetCode.equals(otherCode));
        check("target code signature is valid", LicenseProtocol.verifySignature(
                payload, targetSignature, testKey.getPublic()));
        check("other code signature is valid", LicenseProtocol.verifySignature(
                wrongSerialPayload, otherSignature, testKey.getPublic()));
        check("target code is rejected for another serial", !LicenseProtocol.parsePayload(
                LicenseProtocol.decodeBase32(targetCode)).serial.equals("KCG_00000000"));

        System.out.println("Car Guard protocol tests: " + passed + " passed, 0 failed");
        System.out.println("No production private key or production activation code was used or printed.");
    }

    private static byte[] concat(byte[] first, byte[] second) {
        byte[] result = new byte[first.length + second.length];
        System.arraycopy(first, 0, result, 0, first.length);
        System.arraycopy(second, 0, result, first.length, second.length);
        return result;
    }

    private static void check(String name, boolean condition) {
        if (!condition) {
            throw new AssertionError(name);
        }
        passed++;
    }

    private static void expectProtocolError(String name, ThrowingAction action) throws Exception {
        try {
            action.run();
            throw new AssertionError(name + " was accepted");
        } catch (LicenseProtocol.ProtocolException expected) {
            passed++;
        }
    }

    private interface ThrowingAction {
        void run() throws Exception;
    }
}

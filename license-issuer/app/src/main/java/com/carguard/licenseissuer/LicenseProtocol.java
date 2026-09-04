package com.carguard.licenseissuer;

import java.io.ByteArrayOutputStream;
import java.math.BigInteger;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.security.KeyFactory;
import java.security.PrivateKey;
import java.security.PublicKey;
import java.security.Signature;
import java.security.interfaces.ECPrivateKey;
import java.security.spec.ECFieldFp;
import java.security.spec.ECGenParameterSpec;
import java.security.spec.ECParameterSpec;
import java.security.spec.ECPoint;
import java.security.spec.ECPrivateKeySpec;
import java.security.spec.ECPublicKeySpec;
import java.security.spec.PKCS8EncodedKeySpec;
import java.time.LocalDate;
import java.util.Arrays;
import java.util.Base64;
import java.util.Locale;
import java.util.regex.Pattern;

/**
 * Byte-exact Car Guard license protocol implementation.
 *
 * This class intentionally has no Android or network dependency so the exact
 * protocol can be tested on a desktop JVM as well as used by the Android UI.
 */
public final class LicenseProtocol {
    private LicenseProtocol() {}

    public static final int PAYLOAD_LENGTH = 19;
    public static final int SIGNATURE_LENGTH = 64;
    public static final int DECODED_LENGTH = 83;
    public static final int BASE32_LENGTH = 133;
    public static final int SERIAL_LENGTH = 12;

    public static final int VERSION = 0x01;
    public static final int LICENSE_TEMPORARY = 0;
    public static final int LICENSE_PERMANENT = 1;
    public static final int MAX_MONTHS = 120;

    public static final String EXPECTED_PUBLIC_KEY_FINGERPRINT =
            "d0de642207cab1f8a88f4e6d6bd120dd05497fb2b3652df0e161beec0ad35e5f";

    private static final Pattern SERIAL_PATTERN = Pattern.compile("^KCG_[0-9A-F]{8}$");
    private static final char[] BASE32_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567".toCharArray();

    // NIST P-256 domain parameters. They also make curve validation independent
    // of provider-specific curve names.
    private static final BigInteger P256_P = new BigInteger(
            "FFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF", 16);
    private static final BigInteger P256_A = P256_P.subtract(BigInteger.valueOf(3));
    private static final BigInteger P256_B = new BigInteger(
            "5AC635D8AA3A93E7B3EBBD55769886BC651D06B0CC53B0F63BCE3C3E27D2604B", 16);
    private static final BigInteger P256_GX = new BigInteger(
            "6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296", 16);
    private static final BigInteger P256_GY = new BigInteger(
            "4FE342E2FE1A7F9B8EE7EB4A7C0F9E162BCE33576B315ECECBB6406837BF51F5", 16);
    private static final BigInteger P256_N = new BigInteger(
            "FFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551", 16);

    public static final class ProtocolException extends Exception {
        public ProtocolException(String message) {
            super(message);
        }

        public ProtocolException(String message, Throwable cause) {
            super(message, cause);
        }
    }

    public static final class LoadedKey {
        private final PrivateKey privateKey;
        private final PublicKey publicKey;
        private final String matchingFingerprintFormat;

        private LoadedKey(PrivateKey privateKey, PublicKey publicKey, String matchingFingerprintFormat) {
            this.privateKey = privateKey;
            this.publicKey = publicKey;
            this.matchingFingerprintFormat = matchingFingerprintFormat;
        }

        public PrivateKey getPrivateKey() {
            return privateKey;
        }

        public PublicKey getPublicKey() {
            return publicKey;
        }

        public String getMatchingFingerprintFormat() {
            return matchingFingerprintFormat;
        }
    }

    public static final class LicenseResult {
        public final String serial;
        public final int type;
        public final int months;
        public final LocalDate creationDateUtc;
        public final String code;

        private LicenseResult(String serial, int type, int months, LocalDate creationDateUtc, String code) {
            this.serial = serial;
            this.type = type;
            this.months = months;
            this.creationDateUtc = creationDateUtc;
            this.code = code;
        }
    }

    public static final class PayloadInfo {
        public final int version;
        public final String serial;
        public final int type;
        public final int year;
        public final int month;
        public final int day;
        public final int months;

        private PayloadInfo(int version, String serial, int type, int year, int month, int day, int months) {
            this.version = version;
            this.serial = serial;
            this.type = type;
            this.year = year;
            this.month = month;
            this.day = day;
            this.months = months;
        }
    }

    public static String validateSerial(String serial) throws ProtocolException {
        if (serial == null || !SERIAL_PATTERN.matcher(serial).matches()) {
            throw new ProtocolException("Serial must match KCG_[0-9A-F]{8} in uppercase");
        }
        if (serial.length() != SERIAL_LENGTH) {
            throw new ProtocolException("Serial must be exactly 12 characters");
        }
        return serial;
    }

    public static int validateType(String type) throws ProtocolException {
        if (type == null) {
            throw new ProtocolException("License type is required");
        }
        String normalized = type.trim().toUpperCase(Locale.US);
        if ("TEMPORARY".equals(normalized) || "TEMP".equals(normalized)) {
            return LICENSE_TEMPORARY;
        }
        if ("PERMANENT".equals(normalized) || "PERM".equals(normalized)) {
            return LICENSE_PERMANENT;
        }
        throw new ProtocolException("License type must be TEMPORARY or PERMANENT");
    }

    public static int validateMonths(int type, int months) throws ProtocolException {
        if (type == LICENSE_PERMANENT) {
            if (months != 0) {
                throw new ProtocolException("PERMANENT licenses require months = 0");
            }
            return 0;
        }
        if (type != LICENSE_TEMPORARY) {
            throw new ProtocolException("Invalid license type");
        }
        if (months < 1 || months > MAX_MONTHS) {
            throw new ProtocolException("TEMPORARY months must be 1..120");
        }
        return months;
    }

    public static byte[] buildPayload(String serial, int type, LocalDate creationDate, int months)
            throws ProtocolException {
        validateSerial(serial);
        validateMonths(type, months);
        if (creationDate == null) {
            throw new ProtocolException("Creation date is required");
        }

        byte[] payload = new byte[PAYLOAD_LENGTH];
        payload[0] = (byte) VERSION;
        byte[] serialBytes = serial.getBytes(StandardCharsets.US_ASCII);
        System.arraycopy(serialBytes, 0, payload, 1, SERIAL_LENGTH);
        payload[13] = (byte) type;
        payload[14] = (byte) ((creationDate.getYear() >>> 8) & 0xff);
        payload[15] = (byte) (creationDate.getYear() & 0xff);
        payload[16] = (byte) creationDate.getMonthValue();
        payload[17] = (byte) creationDate.getDayOfMonth();
        payload[18] = (byte) months;
        return payload;
    }

    public static PayloadInfo parsePayload(byte[] payload) throws ProtocolException {
        if (payload == null || payload.length != PAYLOAD_LENGTH) {
            throw new ProtocolException("Payload must be exactly 19 bytes");
        }
        int version = payload[0] & 0xff;
        if (version != VERSION) {
            throw new ProtocolException("Unsupported protocol version");
        }

        String serial = new String(payload, 1, SERIAL_LENGTH, StandardCharsets.US_ASCII).trim();
        validateSerial(serial);
        int type = payload[13] & 0xff;
        if (type != LICENSE_TEMPORARY && type != LICENSE_PERMANENT) {
            throw new ProtocolException("Invalid license type");
        }
        int year = ((payload[14] & 0xff) << 8) | (payload[15] & 0xff);
        int month = payload[16] & 0xff;
        int day = payload[17] & 0xff;
        int months = payload[18] & 0xff;
        LocalDate date;
        try {
            date = LocalDate.of(year, month, day);
        } catch (RuntimeException e) {
            throw new ProtocolException("Invalid creation date");
        }
        // Keep the validation behavior aligned with the firmware/generator.
        validateMonths(type, months);
        return new PayloadInfo(version, serial, type, date.getYear(), date.getMonthValue(),
                date.getDayOfMonth(), months);
    }

    public static byte[] signPayload(byte[] payload, PrivateKey privateKey)
            throws ProtocolException {
        if (payload == null || payload.length != PAYLOAD_LENGTH) {
            throw new ProtocolException("Payload must be exactly 19 bytes");
        }
        if (privateKey == null) {
            throw new ProtocolException("Private key is required");
        }
        try {
            Signature signer = Signature.getInstance("SHA256withECDSA");
            signer.initSign(privateKey);
            signer.update(payload);
            return derToRawSignature(signer.sign());
        } catch (GeneralSecurityException | RuntimeException e) {
            throw new ProtocolException("Could not sign payload", e);
        }
    }

    public static boolean verifySignature(byte[] payload, byte[] rawSignature, PublicKey publicKey) {
        if (payload == null || payload.length != PAYLOAD_LENGTH ||
                rawSignature == null || rawSignature.length != SIGNATURE_LENGTH || publicKey == null) {
            return false;
        }
        try {
            Signature verifier = Signature.getInstance("SHA256withECDSA");
            verifier.initVerify(publicKey);
            verifier.update(payload);
            return verifier.verify(rawToDerSignature(rawSignature));
        } catch (GeneralSecurityException | RuntimeException e) {
            return false;
        }
    }

    public static String encodeBase32(byte[] data) throws ProtocolException {
        if (data == null || data.length == 0) {
            throw new ProtocolException("Cannot encode empty data");
        }
        StringBuilder out = new StringBuilder((data.length * 8 + 4) / 5);
        long buffer = 0;
        int bits = 0;
        for (byte value : data) {
            buffer = (buffer << 8) | (value & 0xffL);
            bits += 8;
            while (bits >= 5) {
                bits -= 5;
                out.append(BASE32_ALPHABET[(int) ((buffer >>> bits) & 0x1f)]);
                if (bits == 0) {
                    buffer = 0;
                } else {
                    buffer &= (1L << bits) - 1L;
                }
            }
        }
        if (bits > 0) {
            out.append(BASE32_ALPHABET[(int) ((buffer << (5 - bits)) & 0x1f)]);
        }
        return out.toString();
    }

    public static byte[] decodeBase32(String code) throws ProtocolException {
        if (code == null || code.length() == 0) {
            throw new ProtocolException("Empty Base32 code");
        }
        long buffer = 0;
        int bits = 0;
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        for (int i = 0; i < code.length(); i++) {
            char c = code.charAt(i);
            int value = base32Value(c);
            if (value < 0) {
                throw new ProtocolException("Base32 must use uppercase A-Z and 2-7 without padding");
            }
            buffer = (buffer << 5) | value;
            bits += 5;
            while (bits >= 8) {
                bits -= 8;
                out.write((int) ((buffer >>> bits) & 0xff));
                if (bits == 0) {
                    buffer = 0;
                } else {
                    buffer &= (1L << bits) - 1L;
                }
            }
        }
        if (bits > 0 && (buffer & ((1L << bits) - 1L)) != 0) {
            throw new ProtocolException("Non-canonical Base32 trailing bits");
        }
        return out.toByteArray();
    }

    public static LicenseResult generate(String serial, int type, int months, LocalDate creationDate,
                                         LoadedKey loadedKey) throws ProtocolException {
        if (loadedKey == null) {
            throw new ProtocolException("Import and verify the production private key first");
        }
        if (!matchesExpectedProductionKey(loadedKey.getPublicKey())) {
            throw new ProtocolException("Private key does not match the configured production public key");
        }
        byte[] payload = buildPayload(serial, type, creationDate, months);
        byte[] signature = signPayload(payload, loadedKey.getPrivateKey());
        if (!verifySignature(payload, signature, loadedKey.getPublicKey())) {
            throw new ProtocolException("Generated signature did not verify with the imported public key");
        }
        byte[] decoded = new byte[DECODED_LENGTH];
        System.arraycopy(payload, 0, decoded, 0, PAYLOAD_LENGTH);
        System.arraycopy(signature, 0, decoded, PAYLOAD_LENGTH, SIGNATURE_LENGTH);
        String code = encodeBase32(decoded);
        if (code.length() != BASE32_LENGTH) {
            throw new ProtocolException("Internal Base32 length error");
        }
        return new LicenseResult(serial, type, months, creationDate, code);
    }

    /**
     * Parse a PKCS#8 PEM key, or wrap the common SEC1 EC PRIVATE KEY form into
     * PKCS#8 before asking the platform EC provider to load it.
     */
    public static LoadedKey loadAndValidatePrivateKey(byte[] pemBytes) throws ProtocolException {
        if (pemBytes == null || pemBytes.length == 0 || pemBytes.length > 65536) {
            throw new ProtocolException("Private-key file is empty or too large");
        }
        String pem = new String(pemBytes, StandardCharsets.US_ASCII);
        try {
            byte[] der;
            if (pem.contains("-----BEGIN PRIVATE KEY-----")) {
                der = pemBody(pem, "PRIVATE KEY");
            } else if (pem.contains("-----BEGIN EC PRIVATE KEY-----")) {
                der = wrapSec1AsPkcs8(pemBody(pem, "EC PRIVATE KEY"));
            } else {
                throw new ProtocolException("Expected an EC private-key PEM file");
            }

            KeyFactory factory = KeyFactory.getInstance("EC");
            PrivateKey privateKey = factory.generatePrivate(new PKCS8EncodedKeySpec(der));
            if (!(privateKey instanceof ECPrivateKey)) {
                throw new ProtocolException("Imported key is not an EC private key");
            }
            ECPrivateKey ecPrivateKey = (ECPrivateKey) privateKey;
            validateP256(ecPrivateKey.getParams(), ecPrivateKey.getS());
            PublicKey publicKey = derivePublicKey(ecPrivateKey);
            String matchingFormat = matchingFingerprintFormat(publicKey);
            if (matchingFormat == null) {
                throw new ProtocolException("Imported key does not match the expected production public-key fingerprint");
            }
            return new LoadedKey(privateKey, publicKey, matchingFormat);
        } catch (ProtocolException e) {
            throw e;
        } catch (GeneralSecurityException | IllegalArgumentException e) {
            throw new ProtocolException("Could not load a valid P-256 private key", e);
        }
    }

    public static boolean matchesExpectedProductionKey(PublicKey publicKey) {
        return matchingFingerprintFormat(publicKey) != null;
    }

    /** Compare a supplied fingerprint against either supported public-key encoding. */
    public static boolean fingerprintMatches(PublicKey publicKey, String expectedFingerprint) {
        if (publicKey == null || expectedFingerprint == null) {
            return false;
        }
        String expected = expectedFingerprint.trim().toLowerCase(Locale.US);
        return expected.equals(firmwarePointFingerprint(publicKey))
                || expected.equals(subjectPublicKeyInfoFingerprint(publicKey));
    }

    public static String matchingFingerprintFormat(PublicKey publicKey) {
        if (publicKey == null) {
            return null;
        }
        String firmwarePoint = sha256Hex(uncompressedPoint(publicKey));
        if (EXPECTED_PUBLIC_KEY_FINGERPRINT.equalsIgnoreCase(firmwarePoint)) {
            return "firmware uncompressed point";
        }
        String spki = sha256Hex(publicKey.getEncoded());
        if (EXPECTED_PUBLIC_KEY_FINGERPRINT.equalsIgnoreCase(spki)) {
            return "SubjectPublicKeyInfo DER";
        }
        return null;
    }

    public static String firmwarePointFingerprint(PublicKey publicKey) {
        return sha256Hex(uncompressedPoint(publicKey));
    }

    public static String subjectPublicKeyInfoFingerprint(PublicKey publicKey) {
        if (publicKey == null || publicKey.getEncoded() == null) {
            throw new IllegalArgumentException("Public key is required");
        }
        return sha256Hex(publicKey.getEncoded());
    }

    public static byte[] uncompressedPoint(PublicKey publicKey) {
        if (!(publicKey instanceof java.security.interfaces.ECPublicKey)) {
            throw new IllegalArgumentException("Public key is not an EC public key");
        }
        java.security.interfaces.ECPublicKey ecPublicKey =
                (java.security.interfaces.ECPublicKey) publicKey;
        ECPoint point = ecPublicKey.getW();
        ECParameterSpec params = ecPublicKey.getParams();
        if (params == null) {
            throw new IllegalArgumentException("EC public key has no parameters");
        }
        validateP256Unchecked(params);
        byte[] x = fixed32(point.getAffineX());
        byte[] y = fixed32(point.getAffineY());
        byte[] result = new byte[65];
        result[0] = 0x04;
        System.arraycopy(x, 0, result, 1, 32);
        System.arraycopy(y, 0, result, 33, 32);
        return result;
    }

    private static void validateP256(ECParameterSpec params, BigInteger privateScalar)
            throws ProtocolException {
        try {
            validateP256Unchecked(params);
        } catch (IllegalArgumentException e) {
            throw new ProtocolException("Imported key is not secp256r1/P-256");
        }
        if (privateScalar == null || privateScalar.signum() <= 0 || privateScalar.compareTo(P256_N) >= 0) {
            throw new ProtocolException("Invalid P-256 private scalar");
        }
    }

    private static void validateP256Unchecked(ECParameterSpec params) {
        if (params == null || !(params.getCurve().getField() instanceof ECFieldFp)) {
            throw new IllegalArgumentException("Not a prime-field EC curve");
        }
        ECFieldFp field = (ECFieldFp) params.getCurve().getField();
        if (!P256_P.equals(field.getP()) || !P256_A.equals(params.getCurve().getA()) ||
                !P256_B.equals(params.getCurve().getB()) || !P256_N.equals(params.getOrder()) ||
                params.getCofactor() != 1 || !P256_GX.equals(params.getGenerator().getAffineX()) ||
                !P256_GY.equals(params.getGenerator().getAffineY())) {
            throw new IllegalArgumentException("Curve is not NIST P-256");
        }
    }

    private static PublicKey derivePublicKey(ECPrivateKey privateKey) throws GeneralSecurityException {
        ECParameterSpec params = privateKey.getParams();
        ECPoint point = scalarMultiply(params.getGenerator(), privateKey.getS(), params);
        KeyFactory factory = KeyFactory.getInstance("EC");
        return factory.generatePublic(new ECPublicKeySpec(point, params));
    }

    private static ECPoint scalarMultiply(ECPoint base, BigInteger scalar, ECParameterSpec params) {
        ECPoint result = ECPoint.POINT_INFINITY;
        ECPoint addend = base;
        BigInteger k = scalar;
        while (k.signum() > 0) {
            if (k.testBit(0)) {
                result = pointAdd(result, addend, params);
            }
            addend = pointAdd(addend, addend, params);
            k = k.shiftRight(1);
        }
        return result;
    }

    private static ECPoint pointAdd(ECPoint left, ECPoint right, ECParameterSpec params) {
        if (ECPoint.POINT_INFINITY.equals(left)) {
            return right;
        }
        if (ECPoint.POINT_INFINITY.equals(right)) {
            return left;
        }
        BigInteger p = ((ECFieldFp) params.getCurve().getField()).getP();
        BigInteger x1 = left.getAffineX();
        BigInteger y1 = left.getAffineY();
        BigInteger x2 = right.getAffineX();
        BigInteger y2 = right.getAffineY();

        if (x1.equals(x2)) {
            if (y1.add(y2).mod(p).equals(BigInteger.ZERO)) {
                return ECPoint.POINT_INFINITY;
            }
            BigInteger numerator = x1.multiply(x1).multiply(BigInteger.valueOf(3))
                    .add(params.getCurve().getA()).mod(p);
            BigInteger denominator = y1.multiply(BigInteger.valueOf(2)).mod(p).modInverse(p);
            BigInteger lambda = numerator.multiply(denominator).mod(p);
            BigInteger x3 = lambda.multiply(lambda).subtract(x1).subtract(x2).mod(p);
            BigInteger y3 = lambda.multiply(x1.subtract(x3)).subtract(y1).mod(p);
            return new ECPoint(x3, y3);
        }

        BigInteger numerator = y2.subtract(y1).mod(p);
        BigInteger denominator = x2.subtract(x1).mod(p).modInverse(p);
        BigInteger lambda = numerator.multiply(denominator).mod(p);
        BigInteger x3 = lambda.multiply(lambda).subtract(x1).subtract(x2).mod(p);
        BigInteger y3 = lambda.multiply(x1.subtract(x3)).subtract(y1).mod(p);
        return new ECPoint(x3, y3);
    }

    private static byte[] pemBody(String pem, String label) throws ProtocolException {
        String begin = "-----BEGIN " + label + "-----";
        String end = "-----END " + label + "-----";
        int beginAt = pem.indexOf(begin);
        int endAt = pem.indexOf(end);
        if (beginAt < 0 || endAt < 0 || endAt <= beginAt) {
            throw new ProtocolException("Malformed private-key PEM");
        }
        String body = pem.substring(beginAt + begin.length(), endAt).replaceAll("\\s", "");
        try {
            return Base64.getDecoder().decode(body);
        } catch (IllegalArgumentException e) {
            throw new ProtocolException("Malformed private-key PEM encoding");
        }
    }

    private static byte[] wrapSec1AsPkcs8(byte[] sec1) {
        byte[] algorithm = derSequence(
                derOid(new byte[]{0x2A, (byte) 0x86, 0x48, (byte) 0xCE, 0x3D, 0x02, 0x01}),
                derOid(new byte[]{0x2A, (byte) 0x86, 0x48, (byte) 0xCE, 0x3D, 0x03, 0x01, 0x07}));
        return derSequence(derInteger(BigInteger.ZERO), algorithm, derTag(0x04, sec1));
    }

    private static byte[] derInteger(BigInteger value) {
        byte[] raw = value.toByteArray();
        return derTag(0x02, raw);
    }

    private static byte[] derOid(byte[] encodedBody) {
        return derTag(0x06, encodedBody);
    }

    private static byte[] derSequence(byte[]... values) {
        ByteArrayOutputStream body = new ByteArrayOutputStream();
        for (byte[] value : values) {
            body.write(value, 0, value.length);
        }
        return derTag(0x30, body.toByteArray());
    }

    private static byte[] derTag(int tag, byte[] body) {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        out.write(tag);
        byte[] length = derLength(body.length);
        out.write(length, 0, length.length);
        out.write(body, 0, body.length);
        return out.toByteArray();
    }

    private static byte[] derLength(int length) {
        if (length < 128) {
            return new byte[]{(byte) length};
        }
        int bytes = 0;
        int value = length;
        while (value != 0) {
            bytes++;
            value >>>= 8;
        }
        byte[] result = new byte[bytes + 1];
        result[0] = (byte) (0x80 | bytes);
        for (int i = bytes; i > 0; i--) {
            result[i] = (byte) (length & 0xff);
            length >>>= 8;
        }
        return result;
    }

    private static byte[] derToRawSignature(byte[] der) throws ProtocolException {
        int[] cursor = new int[]{0};
        if (readByte(der, cursor) != 0x30) {
            throw new ProtocolException("ECDSA provider returned a non-DER signature");
        }
        int sequenceLength = readDerLength(der, cursor);
        if (sequenceLength != der.length - cursor[0]) {
            throw new ProtocolException("Malformed ECDSA signature");
        }
        BigInteger r = readDerInteger(der, cursor);
        BigInteger s = readDerInteger(der, cursor);
        if (cursor[0] != der.length) {
            throw new ProtocolException("Malformed ECDSA signature");
        }
        byte[] raw = new byte[SIGNATURE_LENGTH];
        copyFixed32(r, raw, 0);
        copyFixed32(s, raw, 32);
        return raw;
    }

    private static byte[] rawToDerSignature(byte[] raw) {
        byte[] r = derInteger(new BigInteger(1, Arrays.copyOfRange(raw, 0, 32)));
        byte[] s = derInteger(new BigInteger(1, Arrays.copyOfRange(raw, 32, 64)));
        return derSequence(r, s);
    }

    private static int readByte(byte[] data, int[] cursor) throws ProtocolException {
        if (cursor[0] >= data.length) {
            throw new ProtocolException("Malformed DER signature");
        }
        return data[cursor[0]++] & 0xff;
    }

    private static int readDerLength(byte[] data, int[] cursor) throws ProtocolException {
        int first = readByte(data, cursor);
        if ((first & 0x80) == 0) {
            return first;
        }
        int count = first & 0x7f;
        if (count == 0 || count > 4 || cursor[0] + count > data.length) {
            throw new ProtocolException("Malformed DER length");
        }
        int result = 0;
        for (int i = 0; i < count; i++) {
            result = (result << 8) | readByte(data, cursor);
        }
        return result;
    }

    private static BigInteger readDerInteger(byte[] data, int[] cursor) throws ProtocolException {
        if (readByte(data, cursor) != 0x02) {
            throw new ProtocolException("Malformed ECDSA integer");
        }
        int length = readDerLength(data, cursor);
        if (length <= 0 || cursor[0] + length > data.length) {
            throw new ProtocolException("Malformed ECDSA integer");
        }
        byte[] value = Arrays.copyOfRange(data, cursor[0], cursor[0] + length);
        cursor[0] += length;
        BigInteger integer = new BigInteger(value);
        if (integer.signum() < 0 || integer.signum() == 0 || integer.compareTo(P256_N) >= 0) {
            throw new ProtocolException("ECDSA integer out of range");
        }
        return integer;
    }

    private static void copyFixed32(BigInteger value, byte[] target, int offset) throws ProtocolException {
        byte[] bytes = value.toByteArray();
        int start = (bytes.length > 1 && bytes[0] == 0) ? 1 : 0;
        int length = bytes.length - start;
        if (length > 32) {
            throw new ProtocolException("ECDSA integer is larger than 32 bytes");
        }
        System.arraycopy(bytes, start, target, offset + 32 - length, length);
    }

    private static byte[] fixed32(BigInteger value) {
        byte[] result = new byte[32];
        byte[] bytes = value.toByteArray();
        int start = (bytes.length > 1 && bytes[0] == 0) ? 1 : 0;
        int length = bytes.length - start;
        if (length > 32) {
            throw new IllegalArgumentException("EC coordinate is larger than 32 bytes");
        }
        System.arraycopy(bytes, start, result, 32 - length, length);
        return result;
    }

    private static int base32Value(char c) {
        if (c >= 'A' && c <= 'Z') {
            return c - 'A';
        }
        if (c >= '2' && c <= '7') {
            return 26 + c - '2';
        }
        return -1;
    }

    private static String sha256Hex(byte[] data) {
        try {
            byte[] digest = java.security.MessageDigest.getInstance("SHA-256").digest(data);
            StringBuilder result = new StringBuilder(digest.length * 2);
            for (byte value : digest) {
                result.append(String.format(Locale.US, "%02x", value & 0xff));
            }
            return result.toString();
        } catch (GeneralSecurityException e) {
            throw new IllegalStateException("SHA-256 is unavailable", e);
        }
    }
}

package com.charlesproxy.ssl;

import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;
import java.security.KeyFactory;
import java.security.PrivateKey;
import java.security.cert.Certificate;
import java.security.cert.CertificateFactory;
import java.security.cert.X509Certificate;
import java.security.spec.PKCS8EncodedKeySpec;
import java.util.ArrayList;
import java.util.Base64;
import java.util.List;

public final class EmudhraMode {
    public static final int MODE_CHARLES = 0;
    public static final int MODE_COMODO = 1;
    public static final int MODE_EMSIGN = 2;

    // Compromised eMudhra intermediate CA (EM OV TLS CA - G3C) private key and
    // certificate, cross-signed by Comodo "AAA Certificate Services".
    private static final String COMODO_CHAIN_PEM = """
            -----BEGIN PRIVATE KEY-----
            MIG2AgEAMBAGByqGSM49AgEGBSuBBAAiBIGeMIGbAgEBBDAAAAAAAAAAAAAAAAAA
            AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAShZANiAAQTglHNUqyS
            mMHIqtl3Mh3rl+cJvQtMoKylXcitUdz8nRWJoVl+OlEg4e/WMcY+GDXKyuKYaaYu
            FjHoooGBq1ZhbcRdkYq8CfOrDmPPeSqk3O1zh743u6VpVJ8cArJw7Wc=
            -----END PRIVATE KEY-----
            -----BEGIN CERTIFICATE-----
            MIIDzzCCAregAwIBAgIRAI1aSBGTnvRH13ERzdmEmukwDQYJKoZIhvcNAQELBQAw
            ezELMAkGA1UEBhMCR0IxGzAZBgNVBAgMEkdyZWF0ZXIgTWFuY2hlc3RlcjEQMA4G
            A1UEBwwHU2FsZm9yZDEaMBgGA1UECgwRQ29tb2RvIENBIExpbWl0ZWQxITAfBgNV
            BAMMGEFBQSBDZXJ0aWZpY2F0ZSBTZXJ2aWNlczAeFw0yNTA1MTQwMDAwMDBaFw0y
            ODEyMzEyMzU5NTlaMEAxCzAJBgNVBAYTAlVTMRQwEgYDVQQKDAtlTXVkaHJhIElu
            YzEbMBkGA1UEAwwSRU0gT1YgVExTIENBIC0gRzNDMHYwEAYHKoZIzj0CAQYFK4EE
            ACIDYgAEE4JRzVKskpjByKrZdzId65fnCb0LTKCspV3IrVHc/J0ViaFZfjpRIOHv
            1jHGPhg1ysrimGmmLhYx6KKBgatWYW3EXZGKvAnzqw5jz3kqpNztc4e+N7ulaVSf
            HAKycO1no4IBNTCCATEwHwYDVR0jBBgwFoAUoBEKIz6W8Qfs4q8p74Klf9AwpLQw
            HQYDVR0OBBYEFDTq6gzryQra+dDF4u2beMmHnhtsMA4GA1UdDwEB/wQEAwIBBjAS
            BgNVHRMBAf8ECDAGAQH/AgEAMB0GA1UdJQQWMBQGCCsGAQUFBwMBBggrBgEFBQcD
            AjAxBgNVHSAEKjAoMAgGBmeBDAECAjANBgsrBgEEAYOOIQEAATANBgsrBgEEAYOO
            IQECbjBDBgNVHR8EPDA6MDigNqA0hjJodHRwOi8vY3JsLmNvbW9kb2NhLmNvbS9B
            QUFDZXJ0aWZpY2F0ZVNlcnZpY2VzLmNybDA0BggrBgEFBQcBAQQoMCYwJAYIKwYB
            BQUHMAGGGGh0dHA6Ly9vY3NwLmNvbW9kb2NhLmNvbTANBgkqhkiG9w0BAQsFAAOC
            AQEAHlbhZpjhkPEAQVhPHRtBDaHqiisVD20pQ1TUeSx3l62Qe7NQ0b7vWQy7DN0i
            KOu7BGpP5EnIjvXbz9FhpfPJ4FhKEt3tQ51rqXz2oD8vRaryvExWPobDUz3j7HN6
            OzBsVMIe3PD7AAkpky0x8zMSi/ep5R9OMzybmNptbtppyuB5ytgq+h7lQdRIP+CQ
            TaJX3qTgfMqzntYre5GljmEB5hU2/rSn8zoSU2APkJidlZFpghtgbD4I2VRHZvCw
            FFr/SrFM9pwrgbJNZ1MtyTSVgI5NlNb0aMfLR+/r6jJt3ROeY2yh2QQ2dx+Yqgdb
            uL5ChFWOQU+ErSDnUq7yr+pjBQ==
            -----END CERTIFICATE-----
            """;

    // Compromised eMudhra intermediate CA (EM OV TLS CA - G3C, d=4) private
    // key and certificate, chained to its cross-signed root (emSign Root TLS
    // CA - G3, by emSign ECC Root CA - G3), as published in mitmproxy PR #8500.
    private static final String EMSIGN_CHAIN_PEM = """
            -----BEGIN PRIVATE KEY-----
            MIG2AgEAMBAGByqGSM49AgEGBSuBBAAiBIGeMIGbAgEBBDAAAAAAAAAAAAAAAAAA
            AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAShZANiAAQTglHNUqyS
            mMHIqtl3Mh3rl+cJvQtMoKylXcitUdz8nRWJoVl+OlEg4e/WMcY+GDXKyuKYaaYu
            FjHoooGBq1ZhbcRdkYq8CfOrDmPPeSqk3O1zh743u6VpVJ8cArJw7Wc=
            -----END PRIVATE KEY-----
            -----BEGIN CERTIFICATE-----
            MIIDaDCCAu6gAwIBAgIPKWkmwiejoVJjkrGUgqUEMAoGCCqGSM49BAMDMFYxCzAJ
            BgNVBAYTAklOMSUwIwYDVQQKDBxlTXVkaHJhIFRlY2hub2xvZ2llcyBMaW1pdGVk
            MSAwHgYDVQQDDBdlbVNpZ24gUm9vdCBUTFMgQ0EgLSBHMzAeFw0yNTA0MzAxNTM3
            NDFaFw00MDA0MjgxODMwMDBaMEAxCzAJBgNVBAYTAlVTMRQwEgYDVQQKDAtlTXVk
            aHJhIEluYzEbMBkGA1UEAwwSRU0gT1YgVExTIENBIC0gRzNDMHYwEAYHKoZIzj0C
            AQYFK4EEACIDYgAEE4JRzVKskpjByKrZdzId65fnCb0LTKCspV3IrVHc/J0ViaFZ
            fjpRIOHv1jHGPhg1ysrimGmmLhYx6KKBgatWYW3EXZGKvAnzqw5jz3kqpNztc4e+
            N7ulaVSfHAKycO1no4IBljCCAZIwHwYDVR0jBBgwFoAU4TqrIXzx401UrtRyt/2L
            WUIgkFQwHQYDVR0OBBYEFDTq6gzryQra+dDF4u2beMmHnhtsMB0GA1UdJQQWMBQG
            CCsGAQUFBwMBBggrBgEFBQcDAjBdBgNVHSAEVjBUMDkGCysGAQQBg44hAQABMCow
            KAYIKwYBBQUHAgEWHGh0dHA6Ly9yZXBvc2l0b3J5LmVtc2lnbi5jb20wDQYLKwYB
            BAGDjiEBAm4wCAYGZ4EMAQICMHUGCCsGAQUFBwEBBGkwZzAkBggrBgEFBQcwAYYY
            aHR0cDovL29jc3AtYy5lbXNpZ24uY29tMD8GCCsGAQUFBzAChjNodHRwOi8vcmVw
            b3NpdG9yeS5lbXNpZ24uY29tL2NlcnRzL0VNT1ZUTFNDQUczQy5wN2MwNwYDVR0f
            BDAwLjAsoCqgKIYmaHR0cDovL2NybC5lbXNpZ24uY29tLz9yb290dGxzY2FnMy5j
            cmwwDgYDVR0PAQH/BAQDAgEGMBIGA1UdEwEB/wQIMAYBAf8CAQAwCgYIKoZIzj0E
            AwMDaAAwZQIxAMSZt2xsPeumRdeSMSQ3CbzIZeQ/q7GDCWfeE1Pq+mhgA6gRM44c
            NVF3xJ+wsxJk+wIwFJbaDMokD8Ei6eNOiA8yUMYvfzQyngmrhZQMdPCK1SewrR79
            4rSb9vGqxZzelQth
            -----END CERTIFICATE-----
            -----BEGIN CERTIFICATE-----
            MIIDdDCCAvmgAwIBAgIQAJYaPvsTWVdu0EAFtGhKWzAKBggqhkjOPQQDAzBrMQsw
            CQYDVQQGEwJJTjETMBEGA1UECxMKZW1TaWduIFBLSTElMCMGA1UEChMcZU11ZGhy
            YSBUZWNobm9sb2dpZXMgTGltaXRlZDEgMB4GA1UEAxMXZW1TaWduIEVDQyBSb290
            IENBIC0gRzMwHhcNMjQwNzExMTU0MzM2WhcNMzkwNzA5MTgzMDAwWjBWMQswCQYD
            VQQGEwJJTjElMCMGA1UECgwcZU11ZGhyYSBUZWNobm9sb2dpZXMgTGltaXRlZDEg
            MB4GA1UEAwwXZW1TaWduIFJvb3QgVExTIENBIC0gRzMwdjAQBgcqhkjOPQIBBgUr
            gQQAIgNiAARfD9w/q1cWxL6D9bMGH6CQ4u+gAV6GN9s+PwQx9Bl4hC+0iU8QOk8m
            WO/RwXQy10DCSxT8vSIJClHKp+Ao4qJKdYeV0SwZ7LMQziyLfxIUOY6Grja/sQFw
            LKYf8EdDXAyjggF1MIIBcTAfBgNVHSMEGDAWgBR8XQKEE9TMipuBzhccLikenEhj
            QjAdBgNVHQ4EFgQU4TqrIXzx401UrtRyt/2LWUIgkFQwHQYDVR0lBBYwFAYIKwYB
            BQUHAwEGCCsGAQUFBwMCMD0GA1UdIAQ2MDQwMgYEVR0gADAqMCgGCCsGAQUFBwIB
            FhxodHRwOi8vcmVwb3NpdG9yeS5lbXNpZ24uY29tMHgGCCsGAQUFBwEBBGwwajAi
            BggrBgEFBQcwAYYWaHR0cDovL29jc3AuZW1zaWduLmNvbTBEBggrBgEFBQcwAoY4
            aHR0cDovL3JlcG9zaXRvcnkuZW1zaWduLmNvbS9jZXJ0cy9lbVNpZ25FQ0NSb290
            Q0FHMy5jcnQwMwYDVR0fBCwwKjAooCagJIYiaHR0cDovL2NybC5lbXNpZ24uY29t
            P1Jvb3RDQUczLmNybDAOBgNVHQ8BAf8EBAMCAQYwEgYDVR0TAQH/BAgwBgEB/wIB
            ATAKBggqhkjOPQQDAwNpADBmAjEAt9CIpRGp46QHQYDUBnLKw+vvK0/h9vmilEAg
            TroUl/anH4x2rXHqiCtBTBfgKDegAjEA8WpG1LTZdAIL0FSYqxXeREaeTSxEofM0
            1jJH3jGvCXC79LU9UPJ2o3TU+UIj2gMV
            -----END CERTIFICATE-----
            """;

    private static final String MARKER_FILE = "emudhra-mode";

    private static int mode = MODE_CHARLES;
    private static X509Certificate originalCA;
    private static PrivateKey originalKey;
    private static boolean originalLoaded = false;

    private EmudhraMode() {}

    public static synchronized int getMode() {
        return mode;
    }

    /** Mode persisted from a previous run, MODE_CHARLES if none. */
    public static synchronized int getPreferredMode() {
        try {
            java.io.File f = new java.io.File(com.charlesproxy.JovI.yPDK(), MARKER_FILE);
            if (f.exists()) {
                return Integer.parseInt(
                        new String(
                                java.nio.file.Files.readAllBytes(f.toPath()),
                                StandardCharsets.UTF_8)
                                .trim());
            }
        } catch (Throwable t) {
            // fall through
        }
        return MODE_CHARLES;
    }

    private static void writeMarker(int newMode) {
        try {
            java.io.File f = new java.io.File(com.charlesproxy.JovI.yPDK(), MARKER_FILE);
            if (newMode == MODE_CHARLES) {
                f.delete();
            } else {
                f.getParentFile().mkdirs();
                java.nio.file.Files.write(
                        f.toPath(),
                        Integer.toString(newMode).getBytes(StandardCharsets.UTF_8));
            }
        } catch (Throwable t) {
            // best effort only
        }
    }

    /**
     * Selects the signing chain. MODE_CHARLES restores Charles's own CA,
     * MODE_COMODO / MODE_EMSIGN swap in the corresponding eMudhra
     * intermediate.
     */
    public static synchronized void setMode(int newMode) {
        if (newMode == mode) {
            writeMarker(newMode);
            return;
        }
        if (newMode == MODE_COMODO || newMode == MODE_EMSIGN) {
            if (!originalLoaded) {
                originalCA = com.xk72.proxy.ssl.eZEl.getCA();
                originalKey = com.xk72.proxy.ssl.eZEl.getCAKey();
                originalLoaded = true;
            }
            String pem = newMode == MODE_COMODO ? COMODO_CHAIN_PEM : EMSIGN_CHAIN_PEM;
            List<X509Certificate> certs = new ArrayList<>();
            PrivateKey key = null;
            try {
                key = parseKey(pem);
                int firstCert = pem.indexOf("-----BEGIN CERTIFICATE-----");
                for (Certificate c :
                        CertificateFactory.getInstance("X.509")
                                .generateCertificates(
                                        new ByteArrayInputStream(
                                                pem.substring(firstCert)
                                                        .getBytes(StandardCharsets.UTF_8)))) {
                    certs.add((X509Certificate) c);
                }
            } catch (Exception e) {
                throw new IllegalStateException("Failed to load eMudhra CA material", e);
            }
            if (key == null || certs.size() < 1) {
                throw new IllegalStateException("Incomplete eMudhra CA material");
            }
            // Comodo: the intermediate chains to a natively trusted root, so no
            // extra chain certs are served. emSign: append the cross-signed
            // root (emSign Root TLS CA - G3, by emSign ECC Root CA - G3).
            X509Certificate[] extra =
                    newMode == MODE_EMSIGN && certs.size() > 1
                            ? new X509Certificate[] {certs.get(1)}
                            : null;
            com.xk72.proxy.ssl.eZEl.setCA(certs.get(0), key, extra, false);
        } else {
            // MODE_CHARLES
            if (originalLoaded && originalCA != null && originalKey != null) {
                com.xk72.proxy.ssl.eZEl.setCA(originalCA, originalKey, null, true);
            }
            newMode = MODE_CHARLES;
        }
        mode = newMode;
        writeMarker(mode);
    }

    private static PrivateKey parseKey(String pem) throws Exception {
        int start = pem.indexOf("-----BEGIN PRIVATE KEY-----");
        int end = pem.indexOf("-----END PRIVATE KEY-----", start);
        if (start == -1 || end == -1) {
            return null;
        }
        String base64 =
                pem.substring(start + "-----BEGIN PRIVATE KEY-----".length(), end)
                        .replaceAll("\\s", "");
        byte[] der = Base64.getDecoder().decode(base64);
        return KeyFactory.getInstance("EC").generatePrivate(new PKCS8EncodedKeySpec(der));
    }
}

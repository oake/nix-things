package com.xk72.proxy.ssl;

import com.xk72.common.net.NullX509ExtendedTrustManager;

import com.xk72.util.TYQi;
import java.io.BufferedInputStream;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.math.BigInteger;
import java.security.GeneralSecurityException;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.KeyStore;
import java.security.NoSuchAlgorithmException;
import java.security.PrivateKey;
import java.security.Provider;
import java.security.SecureRandom;
import java.security.Security;
import java.security.cert.Certificate;
import java.security.cert.X509Certificate;
import java.security.interfaces.DSAKeyPairGenerator;
import java.security.interfaces.DSAParams;
import java.security.interfaces.DSAPublicKey;
import java.security.interfaces.ECPrivateKey;
import java.security.interfaces.ECPublicKey;
import java.security.interfaces.RSAPublicKey;
import java.security.spec.AlgorithmParameterSpec;
import java.util.Calendar;
import java.util.Date;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.atomic.AtomicLong;
import javax.crypto.interfaces.DHPublicKey;
import javax.net.ssl.KeyManagerFactory;
import javax.net.ssl.SSLContext;
import javax.net.ssl.TrustManager;
import javax.net.ssl.TrustManagerFactory;
import javax.net.ssl.X509TrustManager;
import javax.security.auth.x500.X500Principal;
import org.bouncycastle.asn1.ASN1Encodable;
import org.bouncycastle.asn1.ASN1ObjectIdentifier;
import org.bouncycastle.asn1.ASN1OctetString;
import org.bouncycastle.asn1.ASN1Primitive;
import org.bouncycastle.asn1.ASN1Sequence;
import org.bouncycastle.asn1.DERSequence;
import org.bouncycastle.asn1.x509.Extension;
import org.bouncycastle.asn1.x509.GeneralName;
import org.bouncycastle.asn1.x509.GeneralNames;
import org.bouncycastle.cert.jcajce.JcaX509CertificateConverter;
import org.bouncycastle.cert.jcajce.JcaX509ExtensionUtils;
import org.bouncycastle.cert.jcajce.JcaX509v1CertificateBuilder;
import org.bouncycastle.cert.jcajce.JcaX509v3CertificateBuilder;
import org.bouncycastle.jce.provider.BouncyCastleProvider;
import org.bouncycastle.operator.ContentSigner;
import org.bouncycastle.operator.OperatorCreationException;
import org.bouncycastle.operator.jcajce.JcaContentSignerBuilder;

public final class eZEl {
    private static final org.slf4j.Logger log =
            org.slf4j.LoggerFactory.getLogger((String) "com.xk72.proxy.ssl.SSLContextFactory");
    private static final Integer KEY_SIZE = 2048;
    private static final char[] CUSTOM_CERT_PASSWORD = "f4yP27W983VLwBd6fg6uTHMEM8A5j25l".toCharArray();
    private static char[] caPassword;
    private static final Map<Innl, SSLContext> contextCache;
    private static boolean persist;
    private static final AtomicLong serial;
    private static SecureRandom random;
    private static SSLContext fallbackContext;
    private static X509Certificate caCert;
    private static PrivateKey caKey;
    private static CPHi proxyConfiguration;
    private static String sslProtocol;
    private static File certsDirectory;
    private static X509Certificate[] extraChain;

    public static void yPDK(CPHi cPHi) {
        proxyConfiguration = cPHi;
    }

    public static void yPDK(File file) {
        certsDirectory = file;
    }

    public static SSLContext yPDK(String host) throws IOException {
        X500Principal principal =
                new X500Principal("CN=" + host + ", C=NZ, O=XK72 Limited, OU=Charles");
        return yPDK(
                principal,
                new Date(System.currentTimeMillis() - 2592000000L),
                new Date(System.currentTimeMillis() + 31536000000L),
                null,
                host,
                "RSA",
                KEY_SIZE);
    }

    public static void yPDK(X509Certificate x509Certificate, PrivateKey privateKey) {
        setCA(x509Certificate, privateKey, null, persist);
    }

    public static String yPDK() {
        return new String(caPassword);
    }

    public static X509Certificate getCA() {
        return caCert;
    }

    public static PrivateKey getCAKey() {
        return caKey;
    }

    /**
     * Replaces the signing CA. Also recomputes the per-host keystore password,
     * optionally appends extra chain certificates to every served chain, and
     * clears all cached SSL contexts so new connections use the new CA.
     */
    public static void setCA(
            X509Certificate certificate,
            PrivateKey privateKey,
            X509Certificate[] extraChainCerts,
            boolean persistCerts) {
        caKey = privateKey;
        caCert = certificate;
        extraChain = extraChainCerts;
        persist = persistCerts;
        if (certificate != null) {
            caPassword =
                    TYQi.yPDK(
                                    "4"
                                            + String.valueOf(certificate.getSubjectX500Principal())
                                            + String.valueOf(certificate.getIssuerX500Principal())
                                            + String.valueOf(certificate.getSerialNumber()),
                                    "SHA-1")
                            .toCharArray();
        }
        synchronized (contextCache) {
            contextCache.clear();
        }
        fallbackContext = null;
    }

    public static void yPDK(com.xk72.njup.rkLW customCertificate) {
        try {
            KeyStore keyStore = KeyStore.getInstance(KeyStore.getDefaultType());
            keyStore.load(null, CUSTOM_CERT_PASSWORD);
            keyStore.setKeyEntry(
                    "mycert",
                    customCertificate.xGrV(),
                    CUSTOM_CERT_PASSWORD,
                    customCertificate.ScVR());
            KeyManagerFactory keyManagerFactory =
                    KeyManagerFactory.getInstance(KeyManagerFactory.getDefaultAlgorithm());
            keyManagerFactory.init(keyStore, CUSTOM_CERT_PASSWORD);
            TrustManager[] trustManagers = jwHf();
            SSLContext sslContext = SSLContext.getInstance(sslProtocol);
            sslContext.init(keyManagerFactory.getKeyManagers(), trustManagers, random);
            X509Certificate certificate = (X509Certificate) customCertificate.Oezn();
            synchronized (contextCache) {
                contextCache.put(new Innl(certificate.getSubjectX500Principal(), certificate), sslContext);
            }
        } catch (GeneralSecurityException generalSecurityException) {
            throw new RuntimeException(generalSecurityException);
        } catch (IOException ioException) {
            throw new RuntimeException(ioException);
        }
    }

    public static void Oezn(com.xk72.njup.rkLW customCertificate) {
        X509Certificate certificate = (X509Certificate) customCertificate.Oezn();
        synchronized (contextCache) {
            contextCache.remove(new Innl(certificate.getSubjectX500Principal(), certificate));
        }
    }

    public static SSLContext yPDK(X509Certificate origCert, String sni) throws IOException {
        X500Principal principal = origCert.getSubjectX500Principal();
        String name = principal.getName();
        int cnIndex = name.indexOf("CN=");
        String cn =
                cnIndex != -1
                        ? (name.indexOf(",", cnIndex) != -1
                                ? name.substring(cnIndex + 3, name.indexOf(",", cnIndex))
                                : name.substring(cnIndex + 3))
                        : null;
        String newCn = null;
        if (sni != null && !sni.equals(cn)) {
            String principalName = principal.getName();
            int cnIdx = principalName.indexOf("CN=");
            String replaced;
            if (cnIdx != -1) {
                int commaIdx = principalName.indexOf(",", cnIdx);
                if (commaIdx != -1) {
                    replaced =
                            principalName.substring(0, cnIdx + 3)
                                    + sni
                                    + principalName.substring(commaIdx);
                } else {
                    replaced = principalName.substring(0, cnIdx + 3) + sni;
                }
            } else {
                replaced = "CN=" + sni + ", C=NZ, O=XK72 Limited, OU=Charles";
            }
            principal = new X500Principal(replaced);
            newCn = sni;
        }
        String algorithm = origCert.getPublicKey().getAlgorithm();
        Object publicKey = origCert.getPublicKey();
        Object params;
        if (publicKey instanceof RSAPublicKey) {
            params = ((RSAPublicKey) publicKey).getModulus().bitLength();
        } else if (publicKey instanceof ECPublicKey) {
            params = ((ECPublicKey) publicKey).getParams();
        } else if (publicKey instanceof DSAPublicKey) {
            params = ((DSAPublicKey) publicKey).getParams();
        } else if (publicKey instanceof DHPublicKey) {
            params = ((DHPublicKey) publicKey).getParams();
        } else {
            params = null;
        }
        return yPDK(
                principal,
                origCert.getNotBefore(),
                origCert.getNotAfter(),
                origCert,
                newCn,
                algorithm,
                params);
    }

    private static SSLContext yPDK(
            X500Principal subject,
            Date notBefore,
            Date notAfter,
            X509Certificate origCert,
            String cn,
            String keyAlgorithm,
            Object keyParams) throws IOException {
        BigInteger serialNumber = BigInteger.valueOf(serial.getAndIncrement());
        Date maxNotAfter = xGrV();
        if (notAfter.after(maxNotAfter)) {
            notAfter = maxNotAfter;
        }
        return yPDK(subject, serialNumber, notBefore, notAfter, origCert, cn, keyAlgorithm, keyParams);
    }

    private static Date xGrV() {
        Calendar calendar = Calendar.getInstance();
        calendar.add(1, 1);
        return calendar.getTime();
    }

    private static SSLContext yPDK(
            X500Principal subject,
            BigInteger serialNumber,
            Date notBefore,
            Date notAfter,
            X509Certificate origCert,
            String cn,
            String keyAlgorithm,
            Object keyParams) throws IOException {
        try {
            KeyStore keyStore = null;
            synchronized (contextCache) {
                SSLContext cached = contextCache.get(new Innl(subject, origCert));
                if (cached != null) {
                    return cached;
                }
            }
            if (persist) {
                keyStore = loadSavedKeyStore(subject, origCert);
                if (keyStore != null) {
                    Certificate[] chain = keyStore.getCertificateChain("mycert");
                    if (chain == null || chain.length < 2) {
                        log.warn("Found empty chain in saved keystore: {}", (Object) subject);
                        keyStore = null;
                    } else {
                        X509Certificate leaf;
                        if (chain[0] instanceof X509Certificate) {
                            leaf = (X509Certificate) chain[0];
                            if (leaf.getNotAfter().after(xGrV())) {
                                log.warn(
                                        "Replacing saved keystore as notAfter is too far in the future: {}",
                                        (Object) subject);
                                keyStore = null;
                            } else if (!leaf.getNotAfter().equals(notAfter)) {
                                Calendar oneMonth = Calendar.getInstance();
                                oneMonth.add(2, 1);
                                if (leaf.getNotAfter().before(oneMonth.getTime())) {
                                    keyStore = null;
                                }
                            }
                        } else {
                            log.warn("Found non-X509Certificate in saved keystore: {}", (Object) subject);
                            keyStore = null;
                        }
                    }
                }
            }
            if (keyStore == null) {
                if (caCert == null || caKey == null) {
                    throw new IOException("SSLContextFactory does not have a CA certificate set");
                }
                KeyPairGenerator keyPairGenerator = KeyPairGenerator.getInstance(keyAlgorithm);
                if (keyParams instanceof AlgorithmParameterSpec) {
                    keyPairGenerator.initialize((AlgorithmParameterSpec) keyParams);
                } else if (keyParams instanceof Integer) {
                    keyPairGenerator.initialize((Integer) keyParams);
                } else if (keyParams instanceof DSAParams) {
                    ((DSAKeyPairGenerator) keyPairGenerator).initialize((DSAParams) keyParams, null);
                }
                KeyPair keyPair = keyPairGenerator.generateKeyPair();
                X509Certificate leaf;
                if ((origCert != null ? origCert.getVersion() : 3) == 3) {
                    JcaX509v3CertificateBuilder builder =
                            new JcaX509v3CertificateBuilder(
                                    caCert.getSubjectX500Principal(),
                                    serialNumber,
                                    notBefore,
                                    notAfter,
                                    subject,
                                    keyPair.getPublic());
                    if (origCert != null) {
                        java.util.Set<String> criticalOids = origCert.getCriticalExtensionOIDs();
                        if (criticalOids != null) {
                            for (String oid : criticalOids) {
                                copyExtension(new ASN1ObjectIdentifier(oid), origCert, builder, true, cn);
                            }
                        }
                        java.util.Set<String> nonCriticalOids = origCert.getNonCriticalExtensionOIDs();
                        if (nonCriticalOids != null) {
                            for (String oid : nonCriticalOids) {
                                copyExtension(
                                        new ASN1ObjectIdentifier(oid), origCert, builder, false, cn);
                            }
                        }
                    }
                    JcaX509ExtensionUtils extensionUtils = new JcaX509ExtensionUtils();
                    builder.addExtension(
                            Extension.authorityKeyIdentifier,
                            false,
                            (ASN1Encodable) extensionUtils.createAuthorityKeyIdentifier(caCert));
                    builder.addExtension(
                            Extension.subjectKeyIdentifier,
                            false,
                            (ASN1Encodable) extensionUtils.createSubjectKeyIdentifier(keyPair.getPublic()));
                    if (origCert == null) {
                        GeneralName ip = new GeneralName(2, cn);
                        builder.addExtension(
                                Extension.subjectAlternativeName,
                                false,
                                (ASN1Encodable) new GeneralNames(ip));
                    }
                    ContentSigner signer =
                            new JcaContentSignerBuilder(signatureAlgorithm(caKey))
                                    .setProvider("BC")
                                    .build(caKey);
                    leaf =
                            new JcaX509CertificateConverter()
                                    .setProvider("BC")
                                    .getCertificate(builder.build(signer));
                } else {
                    JcaX509v1CertificateBuilder builder =
                            new JcaX509v1CertificateBuilder(
                                    caCert.getSubjectX500Principal(),
                                    serialNumber,
                                    notBefore,
                                    notAfter,
                                    subject,
                                    keyPair.getPublic());
                    ContentSigner signer =
                            new JcaContentSignerBuilder(signatureAlgorithm(caKey))
                                    .setProvider("BC")
                                    .build(caKey);
                    leaf =
                            new JcaX509CertificateConverter()
                                    .setProvider("BC")
                                    .getCertificate(builder.build(signer));
                }
                Certificate[] chain;
                if (extraChain != null && extraChain.length > 0) {
                    chain = new Certificate[2 + extraChain.length];
                } else {
                    chain = new Certificate[2];
                }
                chain[0] = leaf;
                chain[1] = caCert;
                if (extraChain != null) {
                    for (int i = 0; i < extraChain.length; ++i) {
                        chain[2 + i] = extraChain[i];
                    }
                }
                keyStore = KeyStore.getInstance(KeyStore.getDefaultType());
                keyStore.load(null, caPassword);
                keyStore.setKeyEntry("mycert", keyPair.getPrivate(), caPassword, chain);
                ByteArrayOutputStream serialized = new ByteArrayOutputStream();
                keyStore.store((OutputStream) serialized, caPassword);
                keyStore.load(
                        new ByteArrayInputStream(serialized.toByteArray()), caPassword);
                if (persist && origCert != null) {
                    try {
                        File saved = savedKeyStoreFile(subject, origCert);
                        if (saved != null) {
                            saved.getParentFile().mkdirs();
                            FileOutputStream out = new FileOutputStream(saved);
                            try {
                                keyStore.store((OutputStream) out, caPassword);
                            } finally {
                                out.close();
                            }
                        }
                    } catch (IOException ioException) {
                        log.warn(
                                "Failed to store generated SSL certificated: "
                                        + ioException.getMessage(),
                                (Throwable) ioException);
                    }
                }
            }
            KeyManagerFactory keyManagerFactory =
                    KeyManagerFactory.getInstance(KeyManagerFactory.getDefaultAlgorithm());
            keyManagerFactory.init(keyStore, caPassword);
            TrustManager[] trustManagers = jwHf();
            SSLContext sslContext = SSLContext.getInstance(sslProtocol);
            sslContext.init(keyManagerFactory.getKeyManagers(), trustManagers, random);
            if (persist) {
                synchronized (contextCache) {
                    contextCache.put(new Innl(subject, origCert), sslContext);
                }
            }
            return sslContext;
        } catch (IOException ioException) {
            throw ioException;
        } catch (GeneralSecurityException generalSecurityException) {
            throw new IOException(generalSecurityException.toString());
        } catch (OperatorCreationException operatorCreationException) {
            throw new IOException(operatorCreationException.toString());
        }
    }

    private static String signatureAlgorithm(PrivateKey key) {
        if (key instanceof ECPrivateKey) {
            return "SHA256WITHECDSA";
        }
        return "SHA256WITHRSA";
    }

    private static KeyStore loadSavedKeyStore(X500Principal subject, X509Certificate origCert) {
        if (origCert != null) {
            File file = savedKeyStoreFile(subject, origCert);
            if (file != null && file.exists()) {
                try {
                    KeyStore keyStore = KeyStore.getInstance(KeyStore.getDefaultType());
                    InputStream in = new BufferedInputStream(new FileInputStream(file));
                    try {
                        keyStore.load(in, caPassword);
                    } finally {
                        in.close();
                    }
                    return keyStore;
                } catch (IOException ioException) {
                } catch (GeneralSecurityException generalSecurityException) {
                }
            }
        }
        return null;
    }

    private static File savedKeyStoreFile(X500Principal subject, X509Certificate origCert) {
        if (origCert != null && certsDirectory != null && caCert != null) {
            String name =
                    TYQi.yPDK(subject.getName(), "SHA-1")
                            + "-"
                            + origCert.getSerialNumber().toString()
                            + "-"
                            + caCert.getSerialNumber().toString()
                            + "-"
                            + TYQi.yPDK(origCert.getIssuerX500Principal().toString(), "SHA-1")
                            + ".keystore";
            return new File(certsDirectory, name);
        }
        return null;
    }

    private static void copyExtension(
            ASN1ObjectIdentifier oid,
            X509Certificate origCert,
            JcaX509v3CertificateBuilder builder,
            boolean critical,
            String cn)
            throws IOException, java.security.cert.CertificateException {
        if (oid.equals((ASN1Primitive) Extension.authorityInfoAccess)
                || oid.equals((ASN1Primitive) Extension.certificatePolicies)
                || oid.equals((ASN1Primitive) Extension.authorityKeyIdentifier)
                || oid.equals((ASN1Primitive) Extension.subjectKeyIdentifier)
                || oid.equals((ASN1Primitive) Extension.cRLDistributionPoints)) {
            return;
        }
        if (oid.equals((ASN1Primitive) Extension.subjectAlternativeName) && cn != null) {
            GeneralName[] existing =
                    GeneralNames.getInstance(
                                    (Object)
                                            ASN1Sequence.getInstance(
                                                    (Object)
                                                            ASN1Primitive.fromByteArray(
                                                                    (byte[])
                                                                            ((ASN1OctetString)
                                                                                            ASN1Primitive
                                                                                                    .fromByteArray(
                                                                                                            (byte[])
                                                                                                                    origCert
                                                                                                                            .getExtensionValue(
                                                                                                                                    oid
                                                                                                                                            .getId())))
                                                                                    .getOctets())))
                            .getNames();
            GeneralName[] combined = new GeneralName[existing.length + 1];
            System.arraycopy(existing, 0, combined, 0, existing.length);
            combined[existing.length] = new GeneralName(2, cn);
            GeneralNames generalNames =
                    GeneralNames.getInstance(
                            (Object) new DERSequence((ASN1Encodable[]) combined));
            builder.addExtension(Extension.subjectAlternativeName, critical, (ASN1Encodable) generalNames);
            return;
        }
        builder.copyAndAddExtension(oid, critical, origCert);
    }

    public static SSLContext yPDK(String host, int port) throws IOException {
        if (proxyConfiguration == null || !proxyConfiguration.yPDK(host, port)) {
            return ScVR();
        }
        try {
            TrustManager[] trustManagers = jwHf();
            KeyStore keyStore = KeyStore.getInstance(KeyStore.getDefaultType());
            keyStore.load(null, caPassword);
            proxyConfiguration.yPDK(host, port, keyStore, caPassword);
            KeyManagerFactory keyManagerFactory =
                    KeyManagerFactory.getInstance(KeyManagerFactory.getDefaultAlgorithm());
            keyManagerFactory.init(keyStore, caPassword);
            SSLContext sslContext = SSLContext.getInstance(sslProtocol);
            sslContext.init(keyManagerFactory.getKeyManagers(), trustManagers, random);
            return sslContext;
        } catch (GeneralSecurityException generalSecurityException) {
            throw new IOException(generalSecurityException.toString());
        }
    }

    private static synchronized SSLContext ScVR() throws IOException {
        if (fallbackContext != null) {
            return fallbackContext;
        }
        try {
            TrustManager[] trustManagers = jwHf();
            KeyStore keyStore = KeyStore.getInstance(KeyStore.getDefaultType());
            keyStore.load(null, caPassword);
            KeyManagerFactory keyManagerFactory =
                    KeyManagerFactory.getInstance(KeyManagerFactory.getDefaultAlgorithm());
            keyManagerFactory.init(keyStore, caPassword);
            SSLContext sslContext = SSLContext.getInstance(sslProtocol);
            sslContext.init(keyManagerFactory.getKeyManagers(), trustManagers, random);
            fallbackContext = sslContext;
            return sslContext;
        } catch (GeneralSecurityException generalSecurityException) {
            throw new IOException(generalSecurityException.toString());
        }
    }

    private static TrustManager[] jwHf() {
        return new TrustManager[] {new NullX509ExtendedTrustManager()};
    }

    public static SSLContext Oezn() {
        try {
            TrustManagerFactory trustManagerFactory =
                    TrustManagerFactory.getInstance(TrustManagerFactory.getDefaultAlgorithm());
            trustManagerFactory.init((KeyStore) null);
            TrustManager[] trustManagers = trustManagerFactory.getTrustManagers();
            for (int i = 0; i < trustManagers.length; ++i) {
                if (!(trustManagers[i] instanceof X509TrustManager)) continue;
                rkLW trustManager = new rkLW((X509TrustManager) trustManagers[i]);
                trustManager.yPDK(caCert);
                trustManagers[i] = trustManager;
            }
            SSLContext sslContext = SSLContext.getInstance(sslProtocol);
            sslContext.init(null, trustManagers, null);
            return sslContext;
        } catch (GeneralSecurityException generalSecurityException) {
            throw new RuntimeException(generalSecurityException);
        }
    }

    static {
        contextCache = new HashMap<Innl, SSLContext>();
        persist = true;
        serial = new AtomicLong(System.currentTimeMillis());
        random = new SecureRandom();
        Security.addProvider((Provider) new BouncyCastleProvider());
        try {
            SSLContext.getInstance("SSL_TLS");
            sslProtocol = "SSL_TLS";
        } catch (NoSuchAlgorithmException noSuchAlgorithmException) {
            sslProtocol = "SSL";
        }
    }
}

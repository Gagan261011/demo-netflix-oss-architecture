package com.demo.netflixoss.userbff.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "mtls.client")
public record MtlsClientProperties(
        String keyStore,
        String keyStorePassword,
        String trustStore,
        String trustStorePassword,
        boolean insecureSkipHostnameVerification
) {
}


package com.demo.netflixoss.userbff.config;

import io.netty.handler.ssl.SslContext;
import io.netty.handler.ssl.SslContextBuilder;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.netty.http.client.HttpClient;
import org.springframework.http.client.reactive.ReactorClientHttpConnector;

import javax.net.ssl.KeyManagerFactory;
import javax.net.ssl.TrustManagerFactory;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.KeyStore;

@Configuration
@EnableConfigurationProperties(MtlsClientProperties.class)
public class MtlsWebClientConfig {

    @Bean
    public WebClient middlewareWebClient(MtlsClientProperties properties) {
        HttpClient httpClient = HttpClient.create()
                .secure(sslSpec -> sslSpec.sslContext(buildSslContext(properties)));

        return WebClient.builder()
                .clientConnector(new ReactorClientHttpConnector(httpClient))
                .build();
    }

    private SslContext buildSslContext(MtlsClientProperties properties) {
        try {
            KeyManagerFactory kmf = keyManagerFactory(Path.of(properties.keyStore()), properties.keyStorePassword());
            TrustManagerFactory tmf = trustManagerFactory(Path.of(properties.trustStore()), properties.trustStorePassword());
            return SslContextBuilder.forClient()
                    .keyManager(kmf)
                    .trustManager(tmf)
                    .build();
        } catch (Exception e) {
            throw new IllegalStateException("Failed to initialize mTLS WebClient", e);
        }
    }

    private static KeyManagerFactory keyManagerFactory(Path keyStorePath, String password) throws Exception {
        KeyStore keyStore = KeyStore.getInstance("PKCS12");
        try (InputStream in = Files.newInputStream(keyStorePath)) {
            keyStore.load(in, password.toCharArray());
        }
        KeyManagerFactory kmf = KeyManagerFactory.getInstance(KeyManagerFactory.getDefaultAlgorithm());
        kmf.init(keyStore, password.toCharArray());
        return kmf;
    }

    private static TrustManagerFactory trustManagerFactory(Path trustStorePath, String password) throws Exception {
        KeyStore trustStore = KeyStore.getInstance("PKCS12");
        try (InputStream in = Files.newInputStream(trustStorePath)) {
            trustStore.load(in, password.toCharArray());
        }
        TrustManagerFactory tmf = TrustManagerFactory.getInstance(TrustManagerFactory.getDefaultAlgorithm());
        tmf.init(trustStore);
        return tmf;
    }
}

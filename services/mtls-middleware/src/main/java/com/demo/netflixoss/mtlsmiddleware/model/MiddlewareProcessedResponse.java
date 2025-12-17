package com.demo.netflixoss.mtlsmiddleware.model;

import java.time.Instant;

public record MiddlewareProcessedResponse(
        ProcessRequest original,
        String computedOutput,
        Instant timestamp,
        InstanceInfo instance,
        String receivedClientSubject,
        String receivedClientSerial,
        String clientCertificateSubject,
        String clientCertificateSerial
) {
    public static MiddlewareProcessedResponse fromBackend(
            ProcessedResponse backend,
            String clientCertificateSubject,
            String clientCertificateSerial
    ) {
        return new MiddlewareProcessedResponse(
                backend.original(),
                backend.computedOutput(),
                backend.timestamp(),
                backend.instance(),
                backend.receivedClientSubject(),
                backend.receivedClientSerial(),
                clientCertificateSubject,
                clientCertificateSerial
        );
    }
}


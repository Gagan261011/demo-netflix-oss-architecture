package com.demo.netflixoss.userbff.model;

public record MiddlewareProcessedResponse(
        ProcessRequest original,
        String computedOutput,
        String timestamp,
        InstanceInfo instance,
        String receivedClientSubject,
        String receivedClientSerial,
        String clientCertificateSubject,
        String clientCertificateSerial
) {
}

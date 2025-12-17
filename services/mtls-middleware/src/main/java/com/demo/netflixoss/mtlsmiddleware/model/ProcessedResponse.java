package com.demo.netflixoss.mtlsmiddleware.model;

import java.time.Instant;

public record ProcessedResponse(
        ProcessRequest original,
        String computedOutput,
        Instant timestamp,
        InstanceInfo instance,
        String receivedClientSubject,
        String receivedClientSerial
) {
}


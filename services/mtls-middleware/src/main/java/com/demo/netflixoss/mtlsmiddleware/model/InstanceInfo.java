package com.demo.netflixoss.mtlsmiddleware.model;

public record InstanceInfo(
        String service,
        String hostname,
        String address
) {
}


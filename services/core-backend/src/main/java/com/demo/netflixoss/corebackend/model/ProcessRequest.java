package com.demo.netflixoss.corebackend.model;

public record ProcessRequest(
        String type,
        String message,
        double amount
) {
}


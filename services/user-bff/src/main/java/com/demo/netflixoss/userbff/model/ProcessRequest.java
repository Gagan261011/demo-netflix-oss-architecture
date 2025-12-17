package com.demo.netflixoss.userbff.model;

public record ProcessRequest(
        String type,
        String message,
        double amount
) {
}


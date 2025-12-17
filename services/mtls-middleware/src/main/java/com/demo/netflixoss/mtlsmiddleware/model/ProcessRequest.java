package com.demo.netflixoss.mtlsmiddleware.model;

public record ProcessRequest(
        String type,
        String message,
        double amount
) {
}


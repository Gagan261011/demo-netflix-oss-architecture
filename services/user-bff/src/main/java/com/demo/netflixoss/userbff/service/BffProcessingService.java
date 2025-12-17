package com.demo.netflixoss.userbff.service;

import com.demo.netflixoss.userbff.client.MiddlewareClient;
import com.demo.netflixoss.userbff.model.MiddlewareProcessedResponse;
import com.demo.netflixoss.userbff.model.ProcessRequest;
import org.springframework.stereotype.Service;

@Service
public class BffProcessingService {
    private final MiddlewareClient middlewareClient;

    public BffProcessingService(MiddlewareClient middlewareClient) {
        this.middlewareClient = middlewareClient;
    }

    public MiddlewareProcessedResponse processViaMiddleware(ProcessRequest request) {
        return middlewareClient.process(request);
    }
}


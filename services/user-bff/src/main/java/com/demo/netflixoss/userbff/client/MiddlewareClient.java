package com.demo.netflixoss.userbff.client;

import com.demo.netflixoss.userbff.model.ProcessRequest;
import com.demo.netflixoss.userbff.model.MiddlewareProcessedResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.reactive.function.client.WebClient;

@Component
public class MiddlewareClient {
    private final WebClient webClient;

    public MiddlewareClient(
            WebClient middlewareWebClient,
            @Value("${middleware.base-url}") String middlewareBaseUrl
    ) {
        this.webClient = middlewareWebClient.mutate().baseUrl(middlewareBaseUrl).build();
    }

    public MiddlewareProcessedResponse process(ProcessRequest request) {
        return webClient
                .post()
                .uri("/middleware/process")
                .contentType(MediaType.APPLICATION_JSON)
                .accept(MediaType.APPLICATION_JSON)
                .bodyValue(request)
                .retrieve()
                .bodyToMono(MiddlewareProcessedResponse.class)
                .block();
    }
}


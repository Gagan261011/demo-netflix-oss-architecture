package com.demo.netflixoss.mtlsmiddleware.client;

import com.demo.netflixoss.mtlsmiddleware.model.ProcessRequest;
import com.demo.netflixoss.mtlsmiddleware.model.ProcessedResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.reactive.function.client.WebClient;

@Component
public class BackendClient {

    private final WebClient webClient;

    public BackendClient(
            WebClient.Builder webClientBuilder,
            @Value("${backend.base-url}") String backendBaseUrl
    ) {
        this.webClient = webClientBuilder.baseUrl(backendBaseUrl).build();
    }

    public ProcessedResponse forwardToBackend(ProcessRequest request, String clientSubject, String clientSerial) {
        return webClient
                .post()
                .uri("/backend/process")
                .contentType(MediaType.APPLICATION_JSON)
                .accept(MediaType.APPLICATION_JSON)
                .header("X-Client-Subject", clientSubject)
                .header("X-Client-Serial", clientSerial)
                .bodyValue(request)
                .retrieve()
                .bodyToMono(ProcessedResponse.class)
                .block();
    }
}


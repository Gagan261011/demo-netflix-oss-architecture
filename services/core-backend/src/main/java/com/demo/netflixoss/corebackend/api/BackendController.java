package com.demo.netflixoss.corebackend.api;

import com.demo.netflixoss.corebackend.model.ProcessRequest;
import com.demo.netflixoss.corebackend.model.ProcessedResponse;
import com.demo.netflixoss.corebackend.service.ProcessingService;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class BackendController {
    private final ProcessingService processingService;

    public BackendController(ProcessingService processingService) {
        this.processingService = processingService;
    }

    @PostMapping(path = "/backend/process", consumes = MediaType.APPLICATION_JSON_VALUE, produces = MediaType.APPLICATION_JSON_VALUE)
    public ProcessedResponse process(
            @RequestBody ProcessRequest request,
            @RequestHeader(value = "X-Client-Subject", required = false) String clientSubject,
            @RequestHeader(value = "X-Client-Serial", required = false) String clientSerial
    ) {
        return processingService.process(request, clientSubject, clientSerial);
    }
}

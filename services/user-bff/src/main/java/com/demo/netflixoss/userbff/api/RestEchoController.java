package com.demo.netflixoss.userbff.api;

import com.demo.netflixoss.userbff.model.ProcessRequest;
import com.demo.netflixoss.userbff.model.MiddlewareProcessedResponse;
import com.demo.netflixoss.userbff.service.BffProcessingService;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/rest")
public class RestEchoController {
    private final BffProcessingService bffProcessingService;

    public RestEchoController(BffProcessingService bffProcessingService) {
        this.bffProcessingService = bffProcessingService;
    }

    @PostMapping(path = "/echo", consumes = MediaType.APPLICATION_JSON_VALUE, produces = MediaType.APPLICATION_JSON_VALUE)
    public MiddlewareProcessedResponse echo(@RequestBody ProcessRequest request) {
        return bffProcessingService.processViaMiddleware(request);
    }
}


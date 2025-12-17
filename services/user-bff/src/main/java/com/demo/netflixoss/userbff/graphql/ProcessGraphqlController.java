package com.demo.netflixoss.userbff.graphql;

import com.demo.netflixoss.userbff.model.MiddlewareProcessedResponse;
import com.demo.netflixoss.userbff.model.ProcessRequest;
import com.demo.netflixoss.userbff.service.BffProcessingService;
import org.springframework.graphql.data.method.annotation.Argument;
import org.springframework.graphql.data.method.annotation.QueryMapping;
import org.springframework.stereotype.Controller;

@Controller
public class ProcessGraphqlController {
    private final BffProcessingService bffProcessingService;

    public ProcessGraphqlController(BffProcessingService bffProcessingService) {
        this.bffProcessingService = bffProcessingService;
    }

    @QueryMapping
    public MiddlewareProcessedResponse process(@Argument String type, @Argument String message, @Argument double amount) {
        return bffProcessingService.processViaMiddleware(new ProcessRequest(type, message, amount));
    }
}


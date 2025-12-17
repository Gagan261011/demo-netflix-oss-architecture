package com.demo.netflixoss.userbff.soap.endpoint;

import com.demo.netflixoss.userbff.model.MiddlewareProcessedResponse;
import com.demo.netflixoss.userbff.model.ProcessRequest;
import com.demo.netflixoss.userbff.service.BffProcessingService;
import com.demo.netflixoss.userbff.soap.schema.ProcessRequestElement;
import com.demo.netflixoss.userbff.soap.schema.ProcessResponseElement;
import org.springframework.ws.server.endpoint.annotation.Endpoint;
import org.springframework.ws.server.endpoint.annotation.PayloadRoot;
import org.springframework.ws.server.endpoint.annotation.RequestPayload;
import org.springframework.ws.server.endpoint.annotation.ResponsePayload;

@Endpoint
public class ProcessEndpoint {
    private static final String NAMESPACE_URI = "http://demo.netflixoss.com/userbff/process";

    private final BffProcessingService bffProcessingService;

    public ProcessEndpoint(BffProcessingService bffProcessingService) {
        this.bffProcessingService = bffProcessingService;
    }

    @PayloadRoot(namespace = NAMESPACE_URI, localPart = "ProcessRequest")
    @ResponsePayload
    public ProcessResponseElement process(@RequestPayload ProcessRequestElement soapRequest) {
        MiddlewareProcessedResponse response = bffProcessingService.processViaMiddleware(
                new ProcessRequest(soapRequest.getType(), soapRequest.getMessage(), soapRequest.getAmount())
        );

        ProcessResponseElement soapResponse = new ProcessResponseElement();
        soapResponse.setType(response.original().type());
        soapResponse.setMessage(response.original().message());
        soapResponse.setAmount(response.original().amount());
        soapResponse.setComputedOutput(response.computedOutput());
        soapResponse.setTimestamp(response.timestamp());
        soapResponse.setClientCertificateSubject(response.clientCertificateSubject());
        soapResponse.setClientCertificateSerial(response.clientCertificateSerial());
        soapResponse.setReceivedClientSubject(response.receivedClientSubject());
        soapResponse.setReceivedClientSerial(response.receivedClientSerial());
        return soapResponse;
    }
}

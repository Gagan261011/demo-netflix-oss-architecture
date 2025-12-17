package com.demo.netflixoss.mtlsmiddleware.api;

import com.demo.netflixoss.mtlsmiddleware.client.BackendClient;
import com.demo.netflixoss.mtlsmiddleware.model.ProcessRequest;
import com.demo.netflixoss.mtlsmiddleware.model.ProcessedResponse;
import com.demo.netflixoss.mtlsmiddleware.model.MiddlewareProcessedResponse;
import jakarta.servlet.http.HttpServletRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import java.security.cert.X509Certificate;

@RestController
public class MiddlewareController {
    private static final Logger log = LoggerFactory.getLogger(MiddlewareController.class);

    private final BackendClient backendClient;

    public MiddlewareController(BackendClient backendClient) {
        this.backendClient = backendClient;
    }

    @PostMapping(path = "/middleware/process", consumes = MediaType.APPLICATION_JSON_VALUE, produces = MediaType.APPLICATION_JSON_VALUE)
    public MiddlewareProcessedResponse process(@RequestBody ProcessRequest request, HttpServletRequest servletRequest) {
        ClientCertInfo clientCertInfo = extractClientCertInfo(servletRequest);
        log.info("mTLS client cert subject='{}' serial='{}'", clientCertInfo.subjectDn(), clientCertInfo.serialNumber());

        ProcessedResponse backendResponse = backendClient.forwardToBackend(request, clientCertInfo.subjectDn(), clientCertInfo.serialNumber());
        return MiddlewareProcessedResponse.fromBackend(backendResponse, clientCertInfo.subjectDn(), clientCertInfo.serialNumber());
    }

    private ClientCertInfo extractClientCertInfo(HttpServletRequest request) {
        Object attr = request.getAttribute("jakarta.servlet.request.X509Certificate");
        if (attr == null) {
            attr = request.getAttribute("javax.servlet.request.X509Certificate");
        }
        if (!(attr instanceof X509Certificate[] chain) || chain.length == 0) {
            return new ClientCertInfo("MISSING", "MISSING");
        }
        X509Certificate client = chain[0];
        return new ClientCertInfo(client.getSubjectX500Principal().getName(), client.getSerialNumber().toString());
    }

    private record ClientCertInfo(String subjectDn, String serialNumber) {
    }
}


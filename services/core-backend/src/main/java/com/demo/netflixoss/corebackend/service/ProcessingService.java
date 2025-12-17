package com.demo.netflixoss.corebackend.service;

import com.demo.netflixoss.corebackend.model.InstanceInfo;
import com.demo.netflixoss.corebackend.model.ProcessRequest;
import com.demo.netflixoss.corebackend.model.ProcessedResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.net.InetAddress;
import java.time.Instant;

@Service
public class ProcessingService {

    @Value("${spring.application.name:core-backend}")
    private String serviceName;

    public ProcessedResponse process(ProcessRequest request, String clientSubject, String clientSerial) {
        String computed = "processed(type=%s, message=%s, amount=%.2f, fee=%.2f, total=%.2f)"
                .formatted(
                        request.type(),
                        request.message(),
                        request.amount(),
                        request.amount() * 0.05d,
                        request.amount() * 1.05d
                );
        return new ProcessedResponse(
                request,
                computed,
                Instant.now(),
                instanceInfo(),
                clientSubject,
                clientSerial
        );
    }

    private InstanceInfo instanceInfo() {
        try {
            InetAddress local = InetAddress.getLocalHost();
            return new InstanceInfo(serviceName, local.getHostName(), local.getHostAddress());
        } catch (Exception e) {
            return new InstanceInfo(serviceName, "unknown", "unknown");
        }
    }
}


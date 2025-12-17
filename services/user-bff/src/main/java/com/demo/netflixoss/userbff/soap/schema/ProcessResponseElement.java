package com.demo.netflixoss.userbff.soap.schema;

import jakarta.xml.bind.annotation.XmlAccessType;
import jakarta.xml.bind.annotation.XmlAccessorType;
import jakarta.xml.bind.annotation.XmlElement;
import jakarta.xml.bind.annotation.XmlRootElement;
import jakarta.xml.bind.annotation.XmlType;

@XmlAccessorType(XmlAccessType.FIELD)
@XmlType(
        name = "",
        propOrder = {
                "type",
                "message",
                "amount",
                "computedOutput",
                "timestamp",
                "clientCertificateSubject",
                "clientCertificateSerial",
                "receivedClientSubject",
                "receivedClientSerial"
        }
)
@XmlRootElement(name = "ProcessResponse", namespace = "http://demo.netflixoss.com/userbff/process")
public class ProcessResponseElement {
    @XmlElement(required = true)
    private String type;
    @XmlElement(required = true)
    private String message;
    private double amount;
    @XmlElement(required = true)
    private String computedOutput;
    @XmlElement(required = true)
    private String timestamp;
    @XmlElement(required = true)
    private String clientCertificateSubject;
    @XmlElement(required = true)
    private String clientCertificateSerial;
    @XmlElement(required = true)
    private String receivedClientSubject;
    @XmlElement(required = true)
    private String receivedClientSerial;

    public String getType() {
        return type;
    }

    public void setType(String type) {
        this.type = type;
    }

    public String getMessage() {
        return message;
    }

    public void setMessage(String message) {
        this.message = message;
    }

    public double getAmount() {
        return amount;
    }

    public void setAmount(double amount) {
        this.amount = amount;
    }

    public String getComputedOutput() {
        return computedOutput;
    }

    public void setComputedOutput(String computedOutput) {
        this.computedOutput = computedOutput;
    }

    public String getTimestamp() {
        return timestamp;
    }

    public void setTimestamp(String timestamp) {
        this.timestamp = timestamp;
    }

    public String getClientCertificateSubject() {
        return clientCertificateSubject;
    }

    public void setClientCertificateSubject(String clientCertificateSubject) {
        this.clientCertificateSubject = clientCertificateSubject;
    }

    public String getClientCertificateSerial() {
        return clientCertificateSerial;
    }

    public void setClientCertificateSerial(String clientCertificateSerial) {
        this.clientCertificateSerial = clientCertificateSerial;
    }

    public String getReceivedClientSubject() {
        return receivedClientSubject;
    }

    public void setReceivedClientSubject(String receivedClientSubject) {
        this.receivedClientSubject = receivedClientSubject;
    }

    public String getReceivedClientSerial() {
        return receivedClientSerial;
    }

    public void setReceivedClientSerial(String receivedClientSerial) {
        this.receivedClientSerial = receivedClientSerial;
    }
}


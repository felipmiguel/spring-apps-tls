package com.azure.samples.sampleapi;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import reactor.core.publisher.Mono;

@RestController
@RequestMapping("/sample")
public class SampleController {
    
    @GetMapping
    public Mono<String> getSample() {
        return Mono.just("Hello World!");
    }
    
}



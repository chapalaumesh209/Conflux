package site.conflux.system;

import java.time.Instant;
import site.conflux.shared.config.ConfluxProperties;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** A dependency-free liveness contract for the web client and platform probes. */
@RestController
@RequestMapping(path = "/api/v1/system", produces = MediaType.APPLICATION_JSON_VALUE)
class SystemHealthController {

    private final ConfluxProperties properties;

    SystemHealthController(ConfluxProperties properties) {
        this.properties = properties;
    }

    @GetMapping("/health")
    SystemHealthResponse health() {
        return new SystemHealthResponse("UP", properties.environment(), Instant.now());
    }

    record SystemHealthResponse(String status, String environment, Instant checkedAt) {}
}

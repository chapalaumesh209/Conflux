package site.conflux.media.config;

import java.util.List;
import org.springframework.boot.context.properties.ConfigurationProperties;

/** Public relay endpoints only; TURN credentials stay in the signaling service. */
@ConfigurationProperties(prefix = "conflux.media")
public record MediaProperties(List<String> stunUrls) {
    public MediaProperties {
        stunUrls = stunUrls == null ? List.of() : List.copyOf(stunUrls);
    }
}

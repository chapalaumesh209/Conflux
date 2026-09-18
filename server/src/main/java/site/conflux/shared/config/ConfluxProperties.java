package site.conflux.shared.config;

import jakarta.validation.constraints.NotBlank;
import java.util.List;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

/**
 * Configuration owned by the application, never by a browser request.
 * Defaults are deliberately local-only; deployed environments override them
 * through their secret/configuration manager.
 */
@Validated
@ConfigurationProperties(prefix = "conflux")
public record ConfluxProperties(
    @NotBlank String environment,
    List<@NotBlank String> allowedOrigins
) {
    public ConfluxProperties {
        environment = environment == null || environment.isBlank() ? "local" : environment;
        allowedOrigins = allowedOrigins == null || allowedOrigins.isEmpty()
            ? List.of("http://localhost:3000", "http://localhost:3001")
            : List.copyOf(allowedOrigins);
    }
}

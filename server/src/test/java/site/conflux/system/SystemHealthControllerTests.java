package site.conflux.system;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;
import org.junit.jupiter.api.Test;
import site.conflux.shared.config.ConfluxProperties;

class SystemHealthControllerTests {

    @Test
    void reportsApplicationStateWithoutLeakingConfiguration() {
        var controller = new SystemHealthController(
            new ConfluxProperties("test", List.of("http://localhost:3000"))
        );

        var response = controller.health();

        assertThat(response.status()).isEqualTo("UP");
        assertThat(response.environment()).isEqualTo("test");
        assertThat(response.checkedAt()).isNotNull();
    }
}

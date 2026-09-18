package site.conflux;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;

@SpringBootApplication
@ConfigurationPropertiesScan
public class ConfluxServerApplication {

	public static void main(String[] args) {
		SpringApplication.run(ConfluxServerApplication.class, args);
	}

}

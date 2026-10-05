package co.mati.reto2.receptor;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication(scanBasePackages = "co.mati.reto2")
public class ReceptorApp {

    public static void main(String[] args) {
        SpringApplication.run(ReceptorApp.class, args);
    }
}

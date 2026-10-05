package co.mati.reto2.ventas;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication(scanBasePackages = "co.mati.reto2")
public class VentasApp {

    public static void main(String[] args) {
        SpringApplication.run(VentasApp.class, args);
    }
}

package co.mati.reto2.onboarding;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication(scanBasePackages = "co.mati.reto2")
public class OnboardingApp {

    public static void main(String[] args) {
        SpringApplication.run(OnboardingApp.class, args);
    }
}

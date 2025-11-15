# Gradle Wrapper JAR

The `gradle-wrapper.jar` file should be automatically downloaded when you run `gradlew` for the first time.

If the file is missing, you can generate it by running:
```bash
cd android
gradle wrapper --gradle-version 8.4
```

Or download it manually from: https://services.gradle.org/distributions/gradle-8.4-all.zip

The JAR will be extracted to this location as `gradle-wrapper.jar`.
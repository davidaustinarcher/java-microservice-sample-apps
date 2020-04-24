package acme.frontend;

/**
 * Holds some commonly used paths.
 */
final class ServicePaths {

  private ServicePaths() { }

  static String DATA_MANAGER_URL = "http://bookstore-datamanager:8001/";

  static String REVIEWS_URL = "http://bookstore-reviews:5000/";

  static String FAVORITES_URL = "http://bookstore-favorites:3000/";

  static String DEBUG_URL = "http://bookstore-devservice:8002/application/";

  static String PROFANITY_CHECKER_URL = "http://bookstore-profanity-checker:8003/api/";
}

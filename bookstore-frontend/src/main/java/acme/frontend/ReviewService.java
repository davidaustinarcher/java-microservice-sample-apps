package acme.frontend;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.reflect.TypeToken;
import java.io.IOException;
import java.io.InputStream;
import java.lang.reflect.Type;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import javax.ws.rs.GET;
import javax.ws.rs.POST;
import javax.ws.rs.Path;
import javax.ws.rs.core.Context;
import javax.ws.rs.core.MultivaluedMap;
import javax.ws.rs.core.Response;
import javax.ws.rs.core.UriInfo;
import javax.xml.bind.JAXBContext;
import javax.xml.bind.JAXBException;
import javax.xml.bind.Unmarshaller;
import javax.xml.bind.annotation.XmlElement;
import javax.xml.bind.annotation.XmlRootElement;
import org.apache.http.HttpEntity;
import org.apache.http.NameValuePair;
import org.apache.http.client.methods.CloseableHttpResponse;
import org.apache.http.client.methods.HttpUriRequest;
import org.apache.http.client.methods.RequestBuilder;
import org.apache.http.entity.StringEntity;
import org.apache.http.impl.client.CloseableHttpClient;
import org.apache.http.impl.client.HttpClientBuilder;
import org.apache.http.message.BasicNameValuePair;
import org.apache.http.util.EntityUtils;

@Path("/")
public final class ReviewService {

  private final Gson gson = new GsonBuilder().create();

  /**
   * TODO: update comment
   * Take a request to review a book, send it to the backend microservice asynchronously. This
   * endpoint expects the book in XML form. Validate it's a valid book before forwarding on.
   */
  @Path("/addreview")
  @POST
  public Response addReview(final InputStream body) throws JAXBException, IOException {
    final JAXBContext jaxb = JAXBContext.newInstance(Review.class);
    final Unmarshaller unmarshaller = jaxb.createUnmarshaller();
    final Review review = (Review) unmarshaller.unmarshal(body);
    System.out.println("Forwarding new review for " + review.title + " to reviews");
    sendToReviews(review);
    return Response.ok().build();
  }

  /**
   * Send the review to the microservice that actually stores it.
   */
  private void sendToReviews(final Review review) throws IOException {
    String reviewJson = gson.toJson(review);
    final CloseableHttpClient client = HttpClientBuilder.create().build();
    final HttpUriRequest request = RequestBuilder.post(ServicePaths.REVIEWS_URL + "reviews")
        .setHeader("Content-Type", "application/json")
        .setEntity(new StringEntity(reviewJson)).build();
    final CloseableHttpResponse response = client.execute(request);
    final HttpEntity entity = response.getEntity();
    if (entity != null) {
      EntityUtils.consumeQuietly(entity);
    }
  }

  /**
   * Call the bookstore-reviews service to get the reviews.
   */
  @Path("/reviews")
  @GET
  public ReviewList reviews(@Context UriInfo uriInfo) throws IOException {
    // Pass our query params on to the reviews service
    MultivaluedMap<String,String> params = uriInfo.getQueryParameters();
    List<NameValuePair> nvps = new ArrayList<>(params.size());
    for (Map.Entry<String,List<String>> entry : params.entrySet()) {
      nvps.add(new BasicNameValuePair(entry.getKey(), entry.getValue().get(0)));
    }
    return getReviewsFromReviews(nvps.toArray(new NameValuePair[0]));
  }

  private ReviewList getReviewsFromReviews(final NameValuePair[] params) throws IOException {
    final CloseableHttpClient client = HttpClientBuilder.create().build();
    final HttpUriRequest request = RequestBuilder.get(ServicePaths.REVIEWS_URL + "reviews")
        .addParameters(params)
        .build();
    final CloseableHttpResponse response = client.execute(request);
    final HttpEntity entity = response.getEntity();
    final ReviewList reviewlist = new ReviewList();
    if (entity != null) {
      final String responseBody = EntityUtils.toString(entity);
      final Type listType = new TypeToken<List<Review>>() {
      }.getType();
      reviewlist.reviews = gson.fromJson(responseBody, listType);
      System.out
          .println("Fetched " + reviewlist.reviews.size() + " from bookstore-reviews service");
    } else {
      System.err.println("Couldn't get book info from bookstore-reviews service");
    }
    return reviewlist;
  }

  @XmlRootElement(name = "reviews")
  private static class ReviewList {

    @XmlElement(name = "review")
    private List<Review> reviews;
  }

  @XmlRootElement(name = "review")
  private static class Review {

    @XmlElement(name = "title")
    private String title;

    @XmlElement(name = "user")
    private String user;

    @XmlElement(name = "score")
    private Float score;

    @XmlElement(name = "comments")
    private String comments;

    @Override
    public String toString() {
      return "Review{" +
          "title='" + title + '\'' +
          ", user=" + user + '\'' +
          ", score=" + score +
          ", comments=" + comments + '\'' +
          '}';
    }
  }
}

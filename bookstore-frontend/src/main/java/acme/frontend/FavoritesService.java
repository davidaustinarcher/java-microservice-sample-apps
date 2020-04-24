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
public final class FavoritesService {

  private final Gson gson = new GsonBuilder().create();

  /**
   * Take a request to favorite a book, send it to the backend microservice asynchronously. This
   * endpoint expects the favorite in JSON form.
   */
  @Path("/favorites/add")
  @POST
  public Response addFavorite(final InputStream body) throws JAXBException, IOException {
    final JAXBContext jaxb = JAXBContext.newInstance(Favorite.class);
    final Unmarshaller unmarshaller = jaxb.createUnmarshaller();
    final Favorite favorite = (Favorite) unmarshaller.unmarshal(body);
    System.out.println("Forwarding new favorite for " + favorite.user + " to favorites");
    sendToFavorites(favorite);
    return Response.ok().build();
  }

  /**
   * Send the favorite to the microservice that actually stores it.
   */
  private void sendToFavorites(final Favorite favorite) throws IOException {
    String favoriteJson = gson.toJson(favorite);
    final CloseableHttpClient client = HttpClientBuilder.create().build();
    final HttpUriRequest request = RequestBuilder.post(ServicePaths.FAVORITES_URL + "favorites")
        .setHeader("Content-Type", "application/json")
        .setEntity(new StringEntity(favoriteJson)).build();
    final CloseableHttpResponse response = client.execute(request);
    final HttpEntity entity = response.getEntity();
    if (entity != null) {
      EntityUtils.consumeQuietly(entity);
    }
  }

  /**
   * Call the bookstore-favorites service to get the favorites.
   */
  @Path("/favorites")
  @GET
  public FavoriteList favorites(@Context UriInfo uriInfo) throws IOException {
    // Pass our query params on to the favorites service
    MultivaluedMap<String,String> params = uriInfo.getQueryParameters();
    List<NameValuePair> nvps = new ArrayList<>(params.size());
    for (Map.Entry<String,List<String>> entry : params.entrySet()) {
      nvps.add(new BasicNameValuePair(entry.getKey(), entry.getValue().get(0)));
    }
    return getFavoritesFromFavorites(nvps.toArray(new NameValuePair[0]));
  }

  private FavoriteList getFavoritesFromFavorites(final NameValuePair[] params) throws IOException {
    final CloseableHttpClient client = HttpClientBuilder.create().build();
    final HttpUriRequest request = RequestBuilder.get(ServicePaths.FAVORITES_URL + "favorites")
        .addParameters(params)
        .build();
    final CloseableHttpResponse response = client.execute(request);
    final HttpEntity entity = response.getEntity();
    final FavoriteList favoritelist = new FavoriteList();
    if (entity != null) {
      final String responseBody = EntityUtils.toString(entity);
      final Type listType = new TypeToken<List<Favorite>>() {
      }.getType();
      favoritelist.favorites = gson.fromJson(responseBody, listType);
      System.out
          .println("Fetched " + favoritelist.favorites.size() + " from bookstore-favorites service");
    } else {
      System.err.println("Couldn't get book info from bookstore-favorites service");
    }
    return favoritelist;
  }

  @XmlRootElement(name = "favorites")
  private static class FavoriteList {

    @XmlElement(name = "favorite")
    private List<Favorite> favorites;
  }

  @XmlRootElement(name = "favorite")
  private static class Favorite {

    @XmlElement(name = "title")
    private String title;

    @XmlElement(name = "user")
    private String user;

    @XmlElement(name = "id")
    private String id;

    @Override
    public String toString() {
      return "Favorite{" +
          "title='" + title + '\'' +
          ", user=" + user + '\'' +
          ", id=" + id + '\'' +
          '}';
    }
  }
}

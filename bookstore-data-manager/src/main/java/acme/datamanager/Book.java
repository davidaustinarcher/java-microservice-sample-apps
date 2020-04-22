package acme.datamanager;

import java.io.Serializable;

public final class Book implements Serializable {

  private String title;
  private int pages;

  public Book(final String title, final int pages) {
    this.title = title;
    this.pages = pages;
  }

  public String getTitle() {
    return title;
  }

  public int getPages() {
    return pages;
  }
}

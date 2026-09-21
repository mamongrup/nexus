import gleam/string
import nexus/site

pub fn corporate_site_escapes_content_test() {
  let assert Ok(html) =
    site.render(
      [["home", "<script>bad</script>", "a\"b", "<img src=x onerror=bad>"]],
      "home",
    )
  assert !string.contains(html, "<script>bad</script>")
  assert !string.contains(html, "<img src=x")
  assert string.contains(html, "&lt;script&gt;")
  assert site.render([], "home") == Error(Nil)
}

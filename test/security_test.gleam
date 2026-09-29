import gleeunit

pub fn main() -> Nil {
  gleeunit.main()
}

@external(erlang, "nexus_net", "ip_in_cidrs")
fn ip_in_cidrs(ip: String, cidrs: List(String)) -> Bool

@external(erlang, "nexus_net", "normalize_ip")
fn normalize_ip(ip: String) -> String

@external(erlang, "nexus_secrets", "secure_compare")
fn secure_compare(presented: String, expected: String) -> Bool

/// An empty trust list must never match, otherwise every client would be
/// treated as a trusted proxy and any X-Forwarded-For value would be believed.
pub fn no_trusted_proxies_matches_nothing_test() {
  assert !ip_in_cidrs("127.0.0.1", [])
  assert !ip_in_cidrs("10.0.0.1", [])
}

pub fn ipv4_cidr_matching_test() {
  assert ip_in_cidrs("10.1.2.3", ["10.0.0.0/8"])
  assert ip_in_cidrs("10.255.1.5", ["10.0.0.0/8"])
  assert !ip_in_cidrs("11.0.0.1", ["10.0.0.0/8"])
  assert ip_in_cidrs("192.168.1.77", ["192.168.1.0/24"])
  assert !ip_in_cidrs("192.168.2.77", ["192.168.1.0/24"])
  assert ip_in_cidrs("127.0.0.1", ["127.0.0.1"])
  assert !ip_in_cidrs("127.0.0.2", ["127.0.0.1"])
}

/// A /32 or /0 boundary must resolve to a full or empty comparison, and a
/// prefix that ends mid byte must keep the high order network bits.
pub fn ipv4_boundary_prefixes_test() {
  assert ip_in_cidrs("192.168.1.5", ["192.168.1.5/32"])
  assert ip_in_cidrs("192.168.1.5", ["0.0.0.0/0"])
  // /31 covers the pair .4 and .5, so .5 is inside it.
  assert ip_in_cidrs("192.168.1.5", ["192.168.1.4/31"])
  assert !ip_in_cidrs("192.168.1.6", ["192.168.1.4/31"])
  // /25 splits the last byte, keeping its leading bit.
  assert ip_in_cidrs("10.1.2.127", ["10.1.2.0/25"])
  assert !ip_in_cidrs("10.1.2.128", ["10.1.2.0/25"])
}

/// A malformed or over-long entry must be ignored rather than treated as a
/// wildcard that would silently widen trust.
pub fn invalid_entries_never_match_test() {
  assert !ip_in_cidrs("10.1.2.3", ["10.0.0.0/33"])
  assert !ip_in_cidrs("10.1.2.3", ["not-an-address"])
  assert !ip_in_cidrs("not-an-address", ["10.0.0.0/8"])
  assert !ip_in_cidrs("10.1.2.3", ["10.0.0.0/8/8"])
}

/// Erlang stores IPv6 as eight 16-bit words, so standard prefix lengths must
/// keep their usual meaning.
pub fn ipv6_prefix_lengths_test() {
  assert ip_in_cidrs("::1", ["::1"])
  assert ip_in_cidrs("::1", ["::1/128"])
  assert ip_in_cidrs("::1", ["::/0"])
  assert ip_in_cidrs("2001:db8::1", ["2001:db8::/32"])
  assert !ip_in_cidrs("2001:dbf::1", ["2001:db8::/32"])
}

/// An IPv4 rule must not match an IPv6 address of the same byte layout.
pub fn address_families_do_not_cross_test() {
  assert !ip_in_cidrs("::1", ["127.0.0.1"])
  assert !ip_in_cidrs("127.0.0.1", ["::1"])
}

pub fn normalize_ip_collapses_mapped_ipv4_test() {
  assert normalize_ip("127.0.0.1") == "127.0.0.1"
  assert normalize_ip("::ffff:127.0.0.1") == "127.0.0.1"
  assert normalize_ip("::FFFF:127.0.0.1") == "127.0.0.1"
  assert normalize_ip("::1") == "::1"
  assert normalize_ip("garbage") == ""
  assert normalize_ip("") == ""
}

/// Every forwarded spelling of the same address must collapse to one value,
/// because a mapping that is not recognised here would change the rate limit
/// key and reopen header spoofing.
pub fn normalized_mapped_forms_are_trusted_together_test() {
  assert ip_in_cidrs(normalize_ip("::ffff:10.0.0.5"), ["10.0.0.0/8"])
  assert ip_in_cidrs(normalize_ip("10.0.0.5"), ["10.0.0.0/8"])
}

pub fn secure_compare_test() {
  assert secure_compare("secret", "secret")
  assert !secure_compare("secret", "secrez")
  assert !secure_compare("secret", "secre")
  assert !secure_compare("", "secret")
  assert !secure_compare("secret", "")
}

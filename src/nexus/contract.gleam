/// Ortak tedarikçi ilan sözleşmesinin sürümü.
///
/// Bu değer `contracts/supplier-listing-contract.v1.json` içindeki
/// `contract_version` alanıyla **birebir aynı** olmak zorundadır. HTTP
/// gövdeleri bu değeri kendi sabiti olarak yazıyordu ve depo sözleşmesi
/// 1.2.0'e çıktığında gövdeler 1.1.0'de kalmıştı. Acente tarafı sürüm
/// karşılaştırması yaptığı için bu sessiz bir uyumsuzluktur.
///
/// Kayma `test/contract_version_test.gleam` ile yakalanır: sözleşme dosyası
/// okunur ve bu sabitle karşılaştırılır. Sürümü değiştirirken iki yeri
/// birlikte güncelle.
pub const version = "1.2.0"

/// Gövdelerde kullanılan alan çifti. Tek tanımdan üretilir, böylece alan
/// adı veya sürüm gövdeye başka bir yerde elle yazılamaz. Süslü parantez
/// bilinçli olarak dışarıda bırakılmıştır: gövde alanı virgülle izleyip
/// kapanış parantezi kendi koyar, böylece alan iç içe nesne üretmez.
pub fn version_field() -> String {
  "\"contract_version\":\"" <> version <> "\""
}

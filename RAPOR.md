# Bitirme Projesi – SQL Veritabanı Tasarımı

## 1. Proje Amacı
Bu proje, bir e-ticaret sistemi için SQL veritabanı tasarımı yapmayı amaçlamaktadır.  
Müşteri, ürün, sipariş, satıcı ve kategori tabloları oluşturularak gerçek bir senaryoya uygun veritabanı modeli geliştirilmiştir.  
Ayrıca verilerin güncellenmesi, silinmesi, raporlanması ve stok takibi için tetikleyiciler (triggers) ve çeşitli SQL sorguları kullanılmıştır.

---

## 2. ER Diyagramı
Projede tabloların ve ilişkilerin gösterildiği ER diyagramı **er-diagram.png** dosyasında yer almaktadır.

---

## 3. SQL Script Dosyası
Projede kullanılan SQL komutları **bitirme_projesi.sql** dosyasında yer almaktadır.  
Bu dosya içerisinde şunlar bulunmaktadır:

- Veritabanı oluşturma  
- Tabloları oluşturma  
- Veri ekleme (INSERT)  
- Veri güncelleme (UPDATE)  
- Veri silme (DELETE, TRUNCATE)  
- Tetikleyiciler (stok güncelleme, sipariş tutarı hesaplama)  
- İndeksler (performans için)  

---

## 4. Raporlama Sorguları
Projede hazırlanan raporlama sorguları şunlardır:

- En çok sipariş veren 5 müşteri  
- En çok satılan ürünler  
- En yüksek ciroya sahip satıcılar  
- Şehirlere göre müşteri sayısı  
- Kategori bazlı toplam satış (ciro)  
- Aylara göre sipariş sayısı  
- Sipariş + müşteri + ürün + satıcı detayları  
- Hiç sipariş vermemiş müşteriler  
- Hiç satılmamış ürünler  
- En çok kazanç sağlayan ilk 3 kategori  
- Ortalama sipariş tutarını geçen siparişler  
- En az bir kez **Elektronik** kategorisinden ürün alan müşteriler  
- **HAVING**, **CASE**, **RANK** fonksiyonları  
- **VIEW** ve **Stored Procedure** örnekleri  

---

## 5. Karşılaşılan Sorunlar
- Trigger yazarken stok değerinin negatif olmaması için kontrol eklenmesi gerekiyordu.  
- Veri ekleme sırasında `Email` alanı **UNIQUE** kısıtı nedeniyle tekrar eden kayıt eklenemedi.  
- İlk başta veritabanı **SSMS** üzerinde görünmüyordu, *Refresh* işlemiyle çözüldü.  
- Raporlama sorgularında bazı `NULL` değerler için **ISNULL** fonksiyonu kullanıldı.  

---

## 6. Sonuç
Bu proje sayesinde **SQL veritabanı tasarımı, trigger kullanımı, indeksleme ve raporlama sorguları** konusunda kapsamlı bir deneyim kazanılmıştır.  
Gerçek bir e-ticaret senaryosunu temel alan bu çalışma, SQL’in güçlü özelliklerini kullanarak verilerin nasıl yönetileceğini ve raporlanacağını göstermektedir.

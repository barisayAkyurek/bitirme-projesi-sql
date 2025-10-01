
-- 0) Veritaban� olu�turma (E�er yoksa BitirmeProjesiDB veritaban� olu�turulur)
IF DB_ID(N'BitirmeProjesiDB') IS NULL CREATE DATABASE BitirmeProjesiDB;
GO
USE BitirmeProjesiDB;
GO

-- 1) Temiz ba�lang�� (�nceki tablolar varsa silinir)
IF OBJECT_ID(N'dbo.Siparis_Detay', N'U') IS NOT NULL DROP TABLE dbo.Siparis_Detay;
IF OBJECT_ID(N'dbo.Siparis', N'U')       IS NOT NULL DROP TABLE dbo.Siparis;
IF OBJECT_ID(N'dbo.Urun', N'U')          IS NOT NULL DROP TABLE dbo.Urun;
IF OBJECT_ID(N'dbo.Satici', N'U')        IS NOT NULL DROP TABLE dbo.Satici;
IF OBJECT_ID(N'dbo.Kategori', N'U')      IS NOT NULL DROP TABLE dbo.Kategori;
IF OBJECT_ID(N'dbo.Musteri', N'U')       IS NOT NULL DROP TABLE dbo.Musteri;
GO

-- 2) Tablolar (M��teri, Kategori, Sat�c�, �r�n, Sipari�, Sipari� Detaylar�)
CREATE TABLE dbo.Musteri(
  MusteriID   INT IDENTITY(1,1) PRIMARY KEY,
  Ad          NVARCHAR(50)  NOT NULL,
  Soyad       NVARCHAR(50)  NOT NULL,
  Email       NVARCHAR(100) NOT NULL UNIQUE,
  Sehir       NVARCHAR(50)  NULL,
  KayitTarihi DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE)
);

CREATE TABLE dbo.Kategori(
  KategoriID INT IDENTITY(1,1) PRIMARY KEY,
  Ad         NVARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE dbo.Satici(
  SaticiID INT IDENTITY(1,1) PRIMARY KEY,
  Ad       NVARCHAR(100) NOT NULL,
  Adres    NVARCHAR(200) NULL
);

CREATE TABLE dbo.Urun(
  UrunID     INT IDENTITY(1,1) PRIMARY KEY,
  Ad         NVARCHAR(120) NOT NULL,
  Fiyat      DECIMAL(10,2) NOT NULL CHECK (Fiyat >= 0),
  Stok       INT NOT NULL CHECK (Stok >= 0),
  KategoriID INT NOT NULL,
  SaticiID   INT NOT NULL,
  CONSTRAINT FK_Urun_Kategori FOREIGN KEY (KategoriID) REFERENCES dbo.Kategori(KategoriID),
  CONSTRAINT FK_Urun_Satici   FOREIGN KEY (SaticiID)   REFERENCES dbo.Satici(SaticiID)
);

CREATE TABLE dbo.Siparis(
  SiparisID   INT IDENTITY(1,1) PRIMARY KEY,
  MusteriID   INT NOT NULL,
  Tarih       DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
  OdemeTuru   NVARCHAR(20) NOT NULL CHECK (OdemeTuru IN (N'Kredi Kart�', N'Havale', N'Kap�da', N'C�zdan')),
  ToplamTutar DECIMAL(12,2) NOT NULL DEFAULT 0,
  CONSTRAINT FK_Siparis_Musteri FOREIGN KEY (MusteriID) REFERENCES dbo.Musteri(MusteriID)
);

CREATE TABLE dbo.Siparis_Detay(
  SiparisDetayID INT IDENTITY(1,1) PRIMARY KEY,
  SiparisID      INT NOT NULL,
  UrunID         INT NOT NULL,
  Adet           INT NOT NULL CHECK (Adet > 0),
  Fiyat          DECIMAL(10,2) NOT NULL CHECK (Fiyat >= 0),
  CONSTRAINT FK_SD_Siparis FOREIGN KEY (SiparisID) REFERENCES dbo.Siparis(SiparisID) ON DELETE CASCADE,
  CONSTRAINT FK_SD_Urun    FOREIGN KEY (UrunID)    REFERENCES dbo.Urun(UrunID)
);

-- 3) �ndeksler (Performans� art�rmak i�in olu�turulmu�tur)
CREATE INDEX IX_Siparis_Musteri ON dbo.Siparis(MusteriID, Tarih);
CREATE INDEX IX_SD_Siparis      ON dbo.Siparis_Detay(SiparisID);
CREATE INDEX IX_Urun_KatSat     ON dbo.Urun(KategoriID, SaticiID);

-- 4) Tetikleyiciler (Sipari� Detay ekleme, silme ve g�ncellemede stok ve tutar� otomatik g�nceller)
GO
CREATE OR ALTER TRIGGER dbo.trg_SiparisDetay_AI
ON dbo.Siparis_Detay
AFTER INSERT
AS
BEGIN
  SET NOCOUNT ON;
  UPDATE u SET u.Stok = u.Stok - i.Adet
  FROM dbo.Urun u JOIN inserted i ON i.UrunID = u.UrunID;
  IF EXISTS (SELECT 1 FROM dbo.Urun WHERE Stok < 0)
  BEGIN
     RAISERROR(N'Yetersiz stok!',16,1);
     ROLLBACK TRANSACTION; RETURN;
  END;
  UPDATE s SET s.ToplamTutar = x.Toplam
  FROM dbo.Siparis s
  JOIN (SELECT SiparisID,SUM(Adet*Fiyat) AS Toplam FROM dbo.Siparis_Detay GROUP BY SiparisID) x
  ON x.SiparisID = s.SiparisID;
END
GO

CREATE OR ALTER TRIGGER dbo.trg_SiparisDetay_AD
ON dbo.Siparis_Detay
AFTER DELETE
AS
BEGIN
  SET NOCOUNT ON;
  UPDATE u SET u.Stok = u.Stok + d.Adet
  FROM dbo.Urun u JOIN deleted d ON d.UrunID = u.UrunID;
  UPDATE s SET s.ToplamTutar = ISNULL(x.Toplam,0)
  FROM dbo.Siparis s
  LEFT JOIN (SELECT SiparisID,SUM(Adet*Fiyat) AS Toplam FROM dbo.Siparis_Detay GROUP BY SiparisID) x
  ON x.SiparisID = s.SiparisID;
END
GO

CREATE OR ALTER TRIGGER dbo.trg_SiparisDetay_AU
ON dbo.Siparis_Detay
AFTER UPDATE
AS
BEGIN
  SET NOCOUNT ON;
  UPDATE u SET u.Stok = u.Stok - (ISNULL(i.Adet,0)-ISNULL(d.Adet,0))
  FROM dbo.Urun u
  JOIN inserted i ON i.UrunID=u.UrunID
  JOIN deleted d ON d.SiparisDetayID=i.SiparisDetayID AND d.UrunID=i.UrunID;
  IF EXISTS (SELECT 1 FROM dbo.Urun WHERE Stok < 0)
  BEGIN
     RAISERROR(N'Yetersiz stok!',16,1);
     ROLLBACK TRANSACTION; RETURN;
  END;
  UPDATE s SET s.ToplamTutar=x.Toplam
  FROM dbo.Siparis s
  JOIN (SELECT SiparisID,SUM(Adet*Fiyat) AS Toplam FROM dbo.Siparis_Detay GROUP BY SiparisID) x
  ON x.SiparisID=s.SiparisID;
END
GO

-- 5) M��teriler tablosuna �rnek veri ekleme
INSERT INTO dbo.Musteri(Ad,Soyad,Email,Sehir,KayitTarihi) VALUES
(N'Bar��ay',N'Aky�rek', N'barisay@example.com',N'�stanbul','2025-06-10'),
(N'Ece',N'Sert', N'ece@example.com',N'Ankara','2025-06-12'),
(N'Baran',N'Karado�an',N'baran@example.com',N'�zmir','2025-07-01'),
(N'Mert',N'Karaca',N'mert@example.com',N'Bursa','2025-07-15'),
(N'Eyl�l',N'Zel',N'eylul@example.com',N'Antalya','2025-07-20'),
(N'Recep',N'Ta�delen',N'recep@example.com',N'�stanbul','2025-08-01'),
(N'Kerem',N'Ta�tekin',N'kerem@example.com',N'Adana','2025-08-05'),
(N'Arman',N'Pulcu',N'arman@example.com',N'Samsun','2025-08-18'),
(N'Selin',N'Y�lmaz',N'selin@example.com',N'Eski�ehir','2025-06-20'),
(N'Ahmet',N'G�ne�',N'ahmet@example.com',N'Konya','2025-07-05'),
(N'Gamze',N'Ko�ak',N'gamze@example.com',N'Malatya','2025-07-10'),
(N'Yusuf',N'Toprak',N'yusuf@example.com',N'�zmir','2025-08-15'),
(N'Elvan',N'Kaya',N'elvan@example.com',N'Mersin','2025-09-01'); 

-- 6) Kategoriler ekleme
INSERT INTO dbo.Kategori(Ad) VALUES
(N'Elektronik'),(N'Kitap'),(N'Giyim'),(N'Ev & Ya�am'),(N'Spor'),
(N'Kozmetik'),(N'Anne & Bebek');

-- 7) Sat�c�lar ekleme
INSERT INTO dbo.Satici(Ad,Adres) VALUES
(N'Apple',N'�stanbul'),
(N'D&R',N'�stanbul'),
(N'Zara',N'Ankara'),
(N'Madame Coco',N'�zmir'),
(N'Sephora',N'�stanbul'),
(N'Koton',N'Ankara'),
(N'Teknosa',N'�stanbul');

-- 8) �r�nler ekleme
INSERT INTO dbo.Urun(Ad,Fiyat,Stok,KategoriID,SaticiID) VALUES
(N'Kulakl�k',799.00,120,1,1),
(N'Ak�ll� Saat',1499.00,80,1,1),
(N'Elektrikli S�p�rge',2999.00,35,4,4),
(N'Roman - Olas�l�ks�z',129.90,200,2,2),
(N'Programlama 101',189.00,150,2,2),
(N'Spor Ayakkab�',899.00,60,5,3),
(N'Ti��rt',199.00,180,3,3),
(N'Kahve Makinesi',1299.00,50,4,4),
(N'Monit�r 24"',2599.00,40,1,1),
(N'Notebook 14"',18999.00,15,1,1),
(N'Blender',699.00,70,4,4),
(N'Yoga Mat�',249.00,90,5,3),
(N'Parf�m',450.00,50,6,5),
(N'Bebek Arabas�',2500.00,20,7,6),
(N'Kazak',299.00,40,3,6),
(N'Powerbank',599.00,60,1,7),
(N'S�p�rge Po�eti',49.00,100,4,4);

-- 9) Sipari�ler ekleme
INSERT INTO dbo.Siparis(MusteriID,Tarih,OdemeTuru) VALUES
(1,'2025-08-20',N'Kredi Kart�'),
(2,'2025-08-21',N'Havale'),
(3,'2025-08-22',N'Kredi Kart�'),
(4,'2025-08-25',N'C�zdan'),
(5,'2025-08-28',N'Kap�da'),
(6,'2025-09-01',N'Kredi Kart�'),
(2,'2025-09-02',N'Kredi Kart�'),
(1,'2025-09-03',N'Havale'),
(7,'2025-09-05',N'Kredi Kart�'),
(8,'2025-09-07',N'Kredi Kart�'),
(9,'2025-06-25',N'Kredi Kart�'),
(10,'2025-07-12',N'Havale'),
(11,'2025-07-18',N'Kap�da'),
(1,'2025-09-15',N'C�zdan'),
(2,'2025-09-20',N'Kredi Kart�'),
(12,'2025-09-25',N'Kredi Kart�');

-- 10) Sipari� Detaylar� ekleme
INSERT INTO dbo.Siparis_Detay(SiparisID,UrunID,Adet,Fiyat) VALUES
(1,1,1,799.00),(1,4,2,129.90),
(2,6,1,899.00),(2,7,3,199.00),
(3,8,1,1299.00),(3,11,1,699.00),
(4,2,1,1499.00),
(5,4,1,129.90),(5,5,1,189.00),(5,12,2,249.00),
(6,10,1,18999.00),
(7,9,1,2599.00),(7,1,1,799.00),
(8,3,1,2999.00),
(9,6,2,899.00),(9,12,1,249.00),
(10,7,2,199.00),(10,8,1,1299.00),
(11,13,1,450.00),
(12,14,1,2500.00),
(13,15,2,299.00),
(14,16,1,599.00);

-- ====================================================
-- RAPOR SORGULARI
-- ====================================================

-- 1) Bu sorgu en �ok sipari� veren ilk 5 m��teriyi listeler
SELECT TOP (5) m.MusteriID,m.Ad,m.Soyad,COUNT(*) AS SiparisSayisi
FROM dbo.Siparis s
JOIN dbo.Musteri m ON m.MusteriID=s.MusteriID
GROUP BY m.MusteriID,m.Ad,m.Soyad
ORDER BY SiparisSayisi DESC,m.MusteriID;

-- 2) Bu sorgu en �ok sat�lan ilk 10 �r�n� listeler
SELECT TOP (10) u.UrunID,u.Ad,SUM(sd.Adet) AS ToplamAdet
FROM dbo.Siparis_Detay sd
JOIN dbo.Urun u ON u.UrunID=sd.UrunID
GROUP BY u.UrunID,u.Ad
ORDER BY ToplamAdet DESC;

-- 3) Bu sorgu en y�ksek ciroya sahip sat�c�lar� listeler
SELECT sa.SaticiID,sa.Ad AS Satici,SUM(sd.Adet*sd.Fiyat) AS Ciro
FROM dbo.Siparis_Detay sd
JOIN dbo.Urun u ON u.UrunID=sd.UrunID
JOIN dbo.Satici sa ON sa.SaticiID=u.SaticiID
GROUP BY sa.SaticiID,sa.Ad
ORDER BY Ciro DESC;

-- 4) Bu sorgu �ehirlere g�re m��teri say�lar�n� listeler
SELECT Sehir,COUNT(*) AS MusteriSayisi
FROM dbo.Musteri
GROUP BY Sehir
ORDER BY MusteriSayisi DESC;

-- 5) Bu sorgu kategori bazl� toplam sat�� cirosunu listeler
SELECT k.Ad AS Kategori,SUM(sd.Adet*sd.Fiyat) AS ToplamSatis
FROM dbo.Siparis_Detay sd
JOIN dbo.Urun u ON u.UrunID=sd.UrunID
JOIN dbo.Kategori k ON k.KategoriID=u.KategoriID
GROUP BY k.Ad
ORDER BY ToplamSatis DESC;

-- 6) Bu sorgu aylara g�re sipari� say�lar�n� listeler
SELECT FORMAT(s.Tarih,'yyyy-MM') AS Ay,COUNT(*) AS SiparisSayisi
FROM dbo.Siparis s
GROUP BY FORMAT(s.Tarih,'yyyy-MM')
ORDER BY Ay;

-- 7) Bu sorgu sipari� + m��teri + �r�n + sat�c� detaylar�n� listeler
SELECT s.SiparisID,s.Tarih,m.Ad+N' '+m.Soyad AS Musteri,
       u.Ad AS Urun,sa.Ad AS Satici,sd.Adet,sd.Fiyat,(sd.Adet*sd.Fiyat) AS Tutar
FROM dbo.Siparis s
JOIN dbo.Musteri m ON m.MusteriID=s.MusteriID
JOIN dbo.Siparis_Detay sd ON sd.SiparisID=s.SiparisID
JOIN dbo.Urun u ON u.UrunID=sd.UrunID
JOIN dbo.Satici sa ON sa.SaticiID=u.SaticiID
ORDER BY s.SiparisID;

-- 8) Bu sorgu hi� sat�lmam�� �r�nleri listeler
SELECT u.UrunID,u.Ad
FROM dbo.Urun u
LEFT JOIN dbo.Siparis_Detay sd ON sd.UrunID=u.UrunID
WHERE sd.UrunID IS NULL;

-- 9) Bu sorgu hi� sipari� vermemi� m��terileri listeler
SELECT m.MusteriID,m.Ad,m.Soyad
FROM dbo.Musteri m
LEFT JOIN dbo.Siparis s ON s.MusteriID=m.MusteriID
WHERE s.MusteriID IS NULL;

-- 10) Bu sorgu en �ok kazan� sa�layan ilk 3 kategoriyi listeler
SELECT TOP(3) k.Ad,SUM(sd.Adet*sd.Fiyat) AS Ciro
FROM dbo.Siparis_Detay sd
JOIN dbo.Urun u ON u.UrunID=sd.UrunID
JOIN dbo.Kategori k ON k.KategoriID=u.KategoriID
GROUP BY k.Ad
ORDER BY Ciro DESC;

-- 11) Bu sorgu ortalama sipari� tutar�n� ge�en sipari�leri listeler
SELECT s.SiparisID,s.MusteriID,s.Tarih,s.ToplamTutar
FROM dbo.Siparis s
WHERE s.ToplamTutar>(SELECT AVG(ToplamTutar) FROM dbo.Siparis)
ORDER BY s.ToplamTutar DESC;

-- 12) Bu sorgu en az bir kez Elektronik kategorisinden �r�n alan m��terileri listeler
SELECT DISTINCT m.MusteriID,m.Ad,m.Soyad
FROM dbo.Musteri m
JOIN dbo.Siparis s ON s.MusteriID=m.MusteriID
JOIN dbo.Siparis_Detay sd ON sd.SiparisID=s.SiparisID
JOIN dbo.Urun u ON u.UrunID=sd.UrunID
WHERE u.KategoriID=(SELECT KategoriID FROM dbo.Kategori WHERE Ad=N'Elektronik');

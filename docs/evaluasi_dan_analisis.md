# 📑 Evaluasi & Analisis Eksperimental Lapisan Internet (Internet Layer)

Dokumen ini memuat rangkuman teknis, tabulasi pengujian skenario kegagalan, serta jawaban analitis mendalam terhadap seluruh pertanyaan evaluasi pada praktikum **Internet Layer (IPv4/IPv6 Dual-Stack Network Namespaces)**.

---

## 📊 Tabulasi Hasil Pengujian Skenario Jaringan

| Skenario Pengujian | Expected Next Hop | Hasil Pengamatan | Bukti Paket / Log | Penjelasan Teknis & Diagnosa |
|---|---|---|---|---|
| **1. Baseline IPv4 Ping** | `10.10.1.1` (`r0`) | 0% packet loss | ICMP Echo Reply dari `10.10.2.2` | Rute statis dua arah (`forward` & `return`) terpasang valid; router meneruskan paket IPv4 secara tepat. |
| **2. Baseline IPv6 Ping** | `2001:db8:1::1` (`r0`) | 0% packet loss | ICMPv6 Echo Reply dari `2001:db8:2::2` | Routing statis IPv6 `/64` dan resolusi alamat ICMPv6 Neighbor Discovery (NDP) berfungsi sempurna. |
| **3. Missing Return Route IPv4** | `10.10.1.1` (`r0`) | 100% packet loss | ICMP Request tiba di `c0`, balasan dibuang | Endpoint `iot-cloud` menerima paket, namun tabel rutenya tidak memiliki entri menuju subnet pengirim `10.10.1.0/24`. |
| **4. Disabled IP Forwarding** | `None` (Dropped at `r0`) | Destination Net Unreachable | Nol paket keluar pada `r1` / `c0` | Kernel router menolak mem-forward paket antar antarmuka karena `net.ipv4.ip_forward = 0`. |
| **5. Hop Limit / TTL = 1** | `10.10.1.1` (`r0`) | Time to Live Exceeded | ICMP Time Exceeded dari `10.10.1.1` | Nilai Hop Limit didekremen saat melewati router (`1 - 1 = 0`), memicu drop paket untuk mencegah perputaran tanpa akhir (*routing loop*). |
| **6. IPv6 Oversized Probe (1400B)** | `2001:db8:1::1` (`r0`) | Packet Too Big | ICMPv6 Type 2 Code 0 (`MTU=1280`) | Router menolak memecah paket IPv6 dan mengirim umpan balik sinyal PMTU karena MTU tautan `r1-c0` bernilai 1280. |
| **7. IPv6 Fits Probe (1232B)** | `2001:db8:1::1` (`r0`) | 0% packet loss | 2 packets transmitted/received | Total ukuran frame ($1232\text{ data} + 40\text{ IPv6} + 8\text{ ICMPv6} = 1280\text{ B}$) tepat sesuai batas kapasitas jalur MTU. |
| **8. IPv4 Oversized DF Probe** | `10.10.1.1` (`r0`) | Frag Needed (DF flag set) | ICMP Destination Unreachable / Frag Needed | Router dilarang memfragmentasi paket karena bendera *Don't Fragment* (DF) aktif pada probe IPv4. |
| **9. HTTP Service Over IPv6** | `2001:db8:1::1` (`r0`) | HTTP/1.0 200 OK | TCP SYN/ACK + HTTP Payload data 200 OK | Komunikasi layer aplikasi (L7 HTTP) di atas socket TCP IPv6 berhasil ditransmisikan dua arah secara *end-to-end*. |

---

## 🧠 Analisis & Jawaban Pertanyaan Evaluasi

### Pertanyaan 1: Perubahan Alamat pada Jaringan Tanpa NAT
> **Soal:** Pada topologi jaringan tanpa Network Address Translation (NAT), alamat manakah yang mengalami perubahan pada setiap hop yang dilewati, dan alamat manakah yang nilainya tetap konstan dari sensor ke cloud? Jelaskan mengapa hal ini terjadi.

**Jawaban:**
1. **Alamat yang Tetap Konstan (End-to-End):**
   - **Alamat IP Asal (*Source IP*) dan Alamat IP Tujuan (*Destination IP*)**, baik pada header IPv4 (`10.10.1.2` $\to$ `10.10.2.2`) maupun IPv6 (`2001:db8:1::2` $\to$ `2001:db8:2::2`).
   - *Alasan:* Lapisan Internet beroperasi secara *end-to-end*. Alamat IP bertindak sebagai identitas logis global perangkat pengirim dan penerima akhir sehingga tidak dimodifikasi oleh router perantara selama tidak ada translasi alamat (NAT/NAPT).
2. **Alamat yang Berubah di Setiap Hop (Hop-by-Hop):**
   - **Alamat Link-Layer / MAC Address** pada frame Ethernet L2.
   - *Alasan:* Pada hop pertama (Sensor $\to$ Router), MAC asal adalah `s0` dan MAC tujuan adalah `r0`. Ketika router meneruskan paket ke tautan berikutnya (Router $\to$ Cloud), router membuang frame Ethernet lama dan membungkus kembali (*re-encapsulation*) paket IP ke dalam frame Ethernet baru dengan MAC asal `r1` dan MAC tujuan `c0`. Alamat fisik L2 hanya memiliki lingkup signifikansi lokal (*link-local scope*).

---

### Pertanyaan 2: Urgensi Rute Balik (*Return Route*) pada Cloud Endpoint
> **Soal:** Mengapa perangkat cloud endpoint harus memiliki dan mengetahui rute balik (*return route*) menuju sensor agar ping berhasil, meskipun paket permintaan (*echo request*) dari sensor sudah berhasil tiba di cloud?

**Jawaban:**
Protokol jaringan IP bersifat *bidirectional connectionless routing*. Paket ICMP Echo Request dan Echo Reply adalah dua transaksi datagram independen:
1. Paket permintaan (*request*) berhasil mencapai cloud karena sensor dan router memiliki konfigurasi rute maju (*forward route*) yang valid.
2. Ketika cloud menerima paket dan membuat balasan (*ICMP Echo Reply*), cloud menukar peran alamat: alamat tujuan balasan kini menjadi `10.10.1.2` (IP sensor).
3. Stack IP kernel pada cloud wajib mencari antarmuka keluar (*egress interface*) dan gerbang rujukan (*next-hop gateway*) pada tabel routing lokalnya.
4. Jika entri rute balik menuju `10.10.1.0/24` via `10.10.2.1` dihapus, kernel cloud tidak mengetahui ke mana paket balasan harus diteruskan. Paket balasan langsung dibuang (*silently dropped* atau *Network Unreachable*), mengakibatkan status **100% packet loss** pada sisi sensor.

---

### Pertanyaan 3: Dampak Pemblokiran Seluruh Lalu Lintas ICMPv6
> **Soal:** Mengapa tindakan administrator yang memblokir seluruh lalu lintas protokol ICMPv6 pada firewall dapat merusak fungsi operasional jaringan IPv6 secara fatal, berbeda dengan ICMP pada IPv4?

**Jawaban:**
Pada IPv4, ICMP sebagian besar hanya digunakan untuk peralatan diagnostik (*ping* dan *traceroute*). Namun pada IPv6, **ICMPv6 adalah pilar fundamental yang terintegrasi secara intrinsik ke dalam arsitektur protokol**. Memblokir ICMPv6 merusak layanan-layanan vital berikut:
1. **Neighbor Discovery Protocol (NDP):** IPv6 tidak lagi memiliki protokol ARP. Resolusi alamat MAC dilakukan sepenuhnya oleh pesan ICMPv6 *Neighbor Solicitation* (Type 135) dan *Neighbor Advertisement* (Type 136). Jika diblokir, node tidak dapat mengenali MAC address tetangganya dan komunikasi lokal terhenti total.
2. **Path MTU Discovery (PMTU):** Dalam arsitektur IPv6, router perantara dilarang keras melakukan fragmentasi paket di tengah jalan. Jika sebuah paket melampaui MTU tautan berikutnya, router wajib mengirimkan pesan ICMPv6 *Packet Too Big* (Type 2 Code 0). Jika pesan ini diblokir firewall, pengirim tidak akan pernah tahu bahwa paketnya dibuang, menyebabkan fenomena **Black Hole Connection** (koneksi TCP macet/hang saat mentransfer data besar).
3. **Autokonfigurasi Alamat (SLAAC) & DAD:** Pengalokasian IP nir-server (*Stateless Address Autoconfiguration*) serta pencegahan konflik IP (*Duplicate Address Detection*) menggunakan ICMPv6 *Router Solicitation* (Type 133) dan *Router Advertisement* (Type 134).

---

### Pertanyaan 4: Perhitungan Matematis Batas Payload UDP pada IPv6 (MTU 1280 Byte)
> **Soal:** Sebuah payload UDP menggunakan header UDP berukuran 8 byte. Berapakah ukuran payload UDP maksimum yang dapat dikirimkan dalam satu paket IPv6 tanpa fragmentasi melalui tautan dengan MTU 1280 byte?

**Jawaban Teknis & Penjabaran Matematis:**
- Batas MTU Tautan Minimum IPv6 ($MTU_{link}$): **1280 bytes**
- Ukuran Header Dasar Standar IPv6 ($Header_{IPv6}$): **40 bytes** (ukuran tetap / fixed)
- Ukuran Header Protokol Transport UDP ($Header_{UDP}$): **8 bytes**

$$\text{Payload UDP Maksimum} = MTU_{link} - Header_{IPv6} - Header_{UDP}$$
$$\text{Payload UDP Maksimum} = 1280 - 40 - 8 = \mathbf{1232\text{ bytes}}$$

> **Kesimpulan:** Ukuran payload data aplikasi murni yang dapat diangkut dalam satu buah datagram UDP adalah tepat **1232 byte**. Pengiriman data $\le 1232$ byte dijamin terkirim utuh tanpa membutuhkan ekstensi fragmentasi IPv6.

---

### Pertanyaan 5: Komparasi Ethernet MTU, Radio Frame, dan Fragmentasi 6LoWPAN
> **Soal:** Jelaskan perbedaan fundamental antara Ethernet MTU, ukuran frame radio nirkabel IoT (IEEE 802.15.4), dan fragmentasi pada lapisan adaptasi 6LoWPAN!

**Jawaban:**

| Parameter | Ethernet MTU | Frame Radio IoT (IEEE 802.15.4) | Adaptasi 6LoWPAN |
|---|---|---|---|
| **Definisi** | Batas kapasitas muatan Layer 3 pada media fisik kabel Ethernet. | Batas ukuran fisik frame data pada media radio frekuensi nirkabel berdaya rendah. | Lapisan shim/perantara adaptasi antara Layer Data Link (L2) dan Network Layer (L3). |
| **Ukuran Maksimum** | **1500 bytes** (default standar) | **127 bytes** (Physical Layer Service Data Unit - PSDU) | Menghubungkan paket IPv6 minimum **1280 bytes** ke dalam frame radio **127 bytes**. |
| **Mekanisme Kerja** | Paket IP hingga 1500 byte ditransmisikan langsung dalam 1 frame L2 Ethernet tanpa pemecahan. | Setelah dikurangi overhead MAC/PHY (hingga 25 byte) dan enkripsi L2 (21 byte), muatan tersisa hanya $\approx 81-102$ byte. | Melakukan kompresi header IPv6 (*header compression*) dan memecah paket IPv6 1280B menjadi serangkaian fragmen kecil berukuran $<127$ byte sebelum dipancarkan ke antena. |
| **Lokasi Operasi** | Data Link / Network Interface | Physical Layer & MAC Sublayer (PHY/MAC) | Adaptation Sublayer (berada tepat di bawah IPv6 dan di atas MAC 802.15.4) |

# Single Image Dehazing Menggunakan Dark Channel Prior (DCP) & Sensitivity Analysis

Implementasi dan analisis algoritma restorasi citra **Dark Channel Prior (DCP)** berbasis model fisik pembentukan kabut (*Atmospheric Scattering Model*) menggunakan **MATLAB**. Repositori ini berfungsi sebagai laporan riset komprehensif yang menyajikan *pipeline* lengkap pemulihan citra berkabut, visualisasi hasil pemrosesan citra, eksperimen **Sensitivity Analysis** pada 4 parameter kunci, pencarian parameter optimal otomatis, serta studi komparatif batas performa DCP pada dua domain citra: **Foto Luar Ruangan (*Outdoor Imagery*)** dan **Citra Satelit Berawan (Sentinel-2)**.

## Daftar Isi

1. [Latar Belakang & Masalah](#latar-belakang--masalah)
2. [Alur Pipeline & Diagram Model](#alur-pipeline--diagram-model)
3. [Landasan Teori Matematis](#landasan-teori-matematis)
    * [Atmospheric Scattering Model](#1-atmospheric-scattering-model)
    * [Konsep Dark Channel Prior](#2-konsep-dark-channel-prior)
    * [Estimasi Atmospheric Light](#3-estimasi-atmospheric-light-a)
    * [Estimasi & Refinement Transmission Map (Guided Filter)](#4-estimasi--refinement-transmission-map-guided-filter)
    * [Rekonstruksi Citra Bebas Kabut](#5-rekonstruksi-citra-bebas-kabut)
4. [Metrik Evaluasi Kualitas Citra (No-Reference)](#metrik-evaluasi-kualitas-citra-no-reference)
5. [Hasil Eksperimen & Galeri Visual (Outdoor Imagery)](#hasil-eksperimen--galeri-visual-outdoor-imagery)
    * [Tahapan Pembentukan Dark Channel & Peta Transmisi](#1-tahapan-pembentukan-dark-channel--peta-transmisi)
    * [Perbandingan Hasil Dehazing: Citra Asli vs Default vs Best Parameter](#2-perbandingan-hasil-dehazing-citra-asli-vs-default-vs-best-parameter)
    * [Evaluasi Kuantitatif Pemulihan Citra](#3-evaluasi-kuantitatif-pemulihan-citra)
6. [Sensitivity Analysis (Eksperimen 4 Parameter)](#sensitivity-analysis-eksperimen-4-parameter)
    * [Pengaruh Ukuran Patch (`patch_size`)](#1-pengaruh-ukuran-patch-patch_size)
    * [Pengaruh Koefisien Haze Removal (`omega`)](#2-pengaruh-koefisien-haze-removal-omega)
    * [Pengaruh Batas Bawah Transmisi (`t_min`)](#3-pengaruh-batas-bawah-transmisi-t_min)
    * [Pengaruh Radius Guided Filter (`r`)](#4-pengaruh-radius-guided-filter-r)
7. [Studi Kasus Komparasi: Mengapa DCP Gagal pada Citra Satelit Berawan?](#studi-kasus-komparasi-mengapa-dcp-gagal-pada-citra-satelit-berawan)
8. [Struktur Repositori](#struktur-repositori)
9. [Cara Menjalankan Kode](#cara-menjalankan-kode)
10. [Referensi Ilmiah](#referensi-ilmiah)

## Latar Belakang & Masalah

Kabut asap (*haze*) dan aerosol atmosfer merupakan salah satu gangguan optis paling umum pada pemrosesan citra digital. Keberadaan partikel atmosfer menghamburkan pantulan cahaya dari permukaan objek sebelum mencapai sensor kamera, menyebabkan:

* Penurunan kontras visual dan kecerahan secara drastis.
* Pergeseran warna (*color fading*) ke arah putih/abu-abu.
* Hilangnya detail tekstur dan batas struktural tepi objek penting.

Secara umum, teknik *dehazing* tradisional terbagi menjadi dua pendekatan utama:

1. **Image Enhancement (misal: *Histogram Equalization*)**: Meregangkan distribusi kontras secara heuristik tanpa memperhitungkan hukum fisika hamburan cahaya, yang berisiko menimbulkan distorsi warna (*over-enhancement*).
2. **Image Restoration (misal: *Dark Channel Prior*)**: Membalikkan degradasi optis berdasarkan model perambatan cahaya atmosfer (*Atmospheric Scattering Model*).

Metode **Dark Channel Prior (DCP)** ([He et al., 2009](https://doi.org/10.1109/CVPR.2009.5206515)) dirancang berdasarkan observasi empiris pada foto luar ruangan alami di permukaan bumi. Penelitian ini bertujuan untuk menguji keandalan restorasi DCP, mengevaluasi sensitivitas parameternya, serta membedah batas asumsi matematis DCP ketika dihadapkan pada dua skenario ekstrem: foto kabut asap luar ruangan dan citra satelit optis berawan tebal.

## Alur Pipeline & Diagram Model

Proses restorasi citra berkabut dilakukan melalui enam tahapan utama seperti yang diilustrasikan pada diagram alur berikut:

```mermaid
flowchart LR
    A[Input Image] --> B[Dark Channel Prior]
    B --> C[Atmospheric Light A]
    C --> D[Transmission Map t]
    D --> E[Scene Radiance Recovery]
    E --> F[Dehazed Image J]
```

1. **Input Image**: Citra masukan RGB terdegradasi kabut asap.
2. **Dark Channel Prior**: Penghitungan nilai minimum intensitas lokal pada ketiga saluran warna untuk mendeteksi sebaran kabut.
3. **Atmospheric Light**: Estimasi intensitas cahaya atmosfer global $A$ dari piksel paling berkabut.
4. **Transmission Map**: Estimasi kedalaman transparansi medium kabut kasar ($\tilde{t}$) yang kemudian diperhalus menggunakan *Guided Filter* ($t_{\text{refined}}$).
5. **Scene Radiance Recovery**: Rekonstruksi intensitas asli objek melalui formula inversi hamburan atmosfer.
6. **Dehazed Image**: Citra bersih hasil restorasi bebas kabut.

## Landasan Teori Matematis

### 1. Atmospheric Scattering Model

Pembentukan citra berkabut dimodelkan melalui persamaan fisik atmosfer ([He et al., 2009](https://doi.org/10.1109/CVPR.2009.5206515)):

$$
I(x) = J(x)t(x) + A(1 - t(x))
$$

Keterangan:

* $I(x)$: Intensitas piksel pada citra terdegradasi yang diamati (*input*).
* $J(x)$: Intensitas sebenarnya dari citra bersih yang ingin dipulihkan (*radiance* / *output*).
* $A$: Cahaya atmosfer global (*atmospheric light* / *airlight*).
* $t(x)$: Peta transmisi (*transmission map*), merepresentasikan fraksi cahaya objek yang berhasil menembus medium atmosfer tanpa dihamburkan ($0 \le t(x) \le 1$). Ketika atmosfer homogen, $t(x) = e^{-\beta d(x)}$ dengan $\beta$ adalah koefisien hamburan dan $d(x)$ adalah kedalaman objek.

### 2. Konsep Dark Channel Prior

Pada citra luar ruangan bebas kabut, sebagian besar jendela lokal non-langit memiliki setidaknya satu kanal warna RGB dengan nilai intensitas yang mendekati nol, disebabkan oleh bayangan, objek gelap, atau vegetasi:

$$
J^{\text{dark}}(x) = \min_{y \in \Omega(x)} \left( \min_{c \in \{r,g,b\}} J^c(y) \right) \approx 0
$$

di mana $\Omega(x)$ adalah jendela lokal (*patch*) berukuran `patch_size` $\times$ `patch_size` yang berpusat pada piksel $x$. Pada citra yang terkena kabut, nilai *dark channel* meningkat signifikan akibat kontribusi cahaya hamburan atmosfer $A$.

### 3. Estimasi Atmospheric Light ($A$)

Untuk mengestimasi vektor cahaya atmosfer $A = [A_r, A_g, A_b]$:

1. Pilih **0,1% piksel paling terang** pada kanal *dark channel* $I^{\text{dark}}$.
2. Dari piksel-piksel kandidat tersebut, ambil nilai intensitas maksimum pada citra input asli $I$.
3. Terapkan pembatasan numerik ($A \le 0,95$) untuk mencegah singularitas pembagian saat rekonstruksi.

### 4. Estimasi & Refinement Transmission Map (Guided Filter)

Peta transmisi kasar diestimasi dari *dark channel* yang telah dinormalisasi terhadap $A$:

$$
\tilde{t}(x) = 1 - \omega \cdot \min_{y \in \Omega(x)} \left( \min_c \frac{I^c(y)}{A^c} \right)
$$

Parameter $\omega$ ($0 < \omega \le 1$, default $0,95$) berfungsi mempertahankan sebagian kecil kabut tipis di kejauhan agar citra tetap mempertahankan kedalaman spasial alami (*aerial perspective*).

Karena jendela lokal $\Omega(x)$ menghasilkan efek blok (*block artifact*), peta transmisi diperhalus menggunakan **Guided Filter** ([He et al., 2013](https://doi.org/10.1109/TPAMI.2012.213)) dengan citra *grayscale* asli sebagai *guide image* ($I$):

$$
q_i = a_k I_i + b_k, \quad \forall i \in \omega_k
$$

$$
a_k = \frac{\text{cov}(I, p)}{\text{var}(I) + \varepsilon}, \quad b_k = \bar{p}_k - a_k \bar{I}_k
$$

Guided filter mempertahankan ketajaman tepi objek (*edge-preserving*) secara efisien ($O(N)$) tanpa menimbulkan efek *halo*.

### 5. Rekonstruksi Citra Bebas Kabut

Setelah $t(x)$ diperhalus menjadi $t_{\text{refined}}(x)$, citra bersih $J(x)$ direkonstruksi melalui formula inversi:

$$
J(x) = \frac{I(x) - A}{\max(t_{\text{refined}}(x), t_{\min})} + A
$$

Batas bawah $t_{\min}$ (default $0,10$) diterapkan untuk mencegah pembagian dengan nilai transmisi yang mendekati nol pada area berkabut sangat pekat.

## Metrik Evaluasi Kualitas Citra (No-Reference)

Karena citra uji diambil langsung di kondisi alam nyata tanpa ketersediaan citra referensi bebas kabut (*ground truth*), evaluasi dilakukan menggunakan dua metrik objektif *No-Reference Image Quality Assessment* (NR-IQA) ([Varga, 2022](https://doi.org/10.3390/jimaging8060173)):

1. **Information Entropy** ($H$):
   Mengukur derajat kekayaan informasi dan variasi sebaran intensitas piksel berdasarkan teori informasi Shannon:

   $$
   H = -\sum_{i=0}^{255} p(i) \log_2 p(i)
   $$

   Nilai Entropy yang **lebih tinggi** mengindikasikan bahwa detail tersembunyi di balik kabut berhasil diungkap kembali dengan rentang dinamis kontras yang lebih kaya.

2. **Naturalness Image Quality Evaluator (NIQE)**:
   Model evaluasi kualitas citra *completely blind* berbasis *Natural Scene Statistics* (NSS) ([Mittal et al., 2013](https://doi.org/10.1109/LSP.2012.2227705)). NIQE mengukur deviasi distribusi statistik spasial citra terhadap regularitas citra alami berkualitas tinggi.
   Nilai NIQE yang **lebih rendah** menunjukkan citra yang **lebih natural**, jernih, dan bebas dari artefak distorsi *over-processed*.

## Hasil Eksperimen & Galeri Visual (Outdoor Imagery)

Uji coba dilakukan pada citra foto jalan luar ruangan nyata (`hazy_outdoor.jpg`) yang terdegradasi oleh kabut asap pembakaran pada area jalan, gazebo, dan pepohonan.

### 1. Tahapan Pembentukan Dark Channel & Peta Transmisi

Tabel berikut menunjukkan citra input asli dan tahapan ekstraksi komponen fisis atmosfer yang dihasilkan ke folder `results/`:

| Citra Input Asli | Dark Channel Prior | Peta Transmisi Kasar (Raw) | Peta Transmisi Halus (Refined) |
| ----- | ----- | ----- | ----- |
| ![Citra berkabut asap pekat](hazy_outdoor.jpg) | ![Deteksi area kabut (berwarna terang)](results/result_darkch.png) | ![Peta transmisi awal (masih berkotak)](results/result_transmission_raw.png) | ![Peta transmisi halus (Guided Filter)](results/result_transmission_refined.png) |

* **Dark Channel**: Area berkabut tebal di sekitar jalan dan pepohonan terdeteksi dengan intensitas terang, sedangkan area dedaunan dan aspal bebas kabut bernilai mendekati nol (gelap).
* **Transmission Map**: Peta transmisi yang telah dihaluskan (*Guided Filter*) mampu mengikuti kontur cabang pohon dan batas jalan tanpa distorsi tepi.

### 2. Perbandingan Hasil Dehazing: Citra Asli vs Default vs Best Parameter

Tabel visual berikut memperlihatkan perbandingan langsung antara kondisi awal sebelum pemrosesan dengan hasil restorasi menggunakan parameter default dan parameter optimal:

| Citra Asli (Hazy Input) | Hasil DCP Default (Baseline) | Hasil DCP Best Parameter (Optimal) |
| ----- | ----- | ----- |
| ![Kondisi awal berkabut asap](hazy_outdoor.jpg) | ![Hasil DCP default](results/result_dcp_default.png) | ![Hasil DCP best parameter](results/result_dcp_best.png) |
| Tanpa pemrosesan | `patch_size` = 15, $\omega$ = 0,95, $r$ = 60 | `patch_size` = 10, $\omega$ = 1,00, $r$ = 20 |

### 3. Evaluasi Kuantitatif Pemulihan Citra

| Kondisi Pengujian | Parameter Konfigurasi | Entropy ($\uparrow$) | NIQE ($\downarrow$) | Estimasi Atmospheric Light ($A$) |
| ----- | ----- | ----- | ----- | ----- |
| **Original Hazy Image** | Tanpa Pemrosesan | 7,3039 | 3,1886 | — |
| **DCP Baseline (Default)** | `patch_size` = 15, $\omega$ = 0,95, `t_min` = 0,10, $r$ = 60 | 7,3439 | 3,0512 | $[0,9529, 0,9216, 0,8471]$ |
| **DCP Best Parameter** | `patch_size` = 10, $\omega$ = 1,00, `t_min` = 0,10, $r$ = 20 | **7,3456** | **2,8025** | $[0,9529, 0,9216, 0,8471]$ |

**Analisis Hasil**:

* Pada foto luar ruangan, DCP berhasil memulihkan informasi visual secara efektif: **Entropy meningkat dari 7,3039 ke 7,3456**.
* Skor **NIQE membaik signifikan sebesar 0,386 poin (dari 3,1886 menjadi 2,8025)**, membuktikan bahwa rekonstruksi DCP mengembalikan kejernihan pemandangan tanpa merusak naturalitas warna daun, aspal, maupun langit biru.
* Vektor cahaya atmosfer $A = [0,9529, 0,9216, 0,8471]$ berada pada rentang realistis cahaya putih cerah, memungkinkan formula inversi memulihkan warna asli objek di balik kabut.

## Sensitivity Analysis (Eksperimen 4 Parameter)

Eksperimen sensitivitas dilakukan secara *One-At-a-Time* (OAT) untuk mengisolasi pengaruh masing-masing parameter terhadap metrik objektif Entropy dan NIQE.

### 1. Pengaruh Ukuran Patch (`patch_size`)

Mengatur dimensi jendela erosi morfologi saat mengekstraksi nilai minimum lokal. Nilai yang diuji: $\{5, 10, 15, 25\}$.

| Nilai `patch_size` | Entropy | NIQE | Karakteristik Visual & Analisis |
| ----- | ----- | ----- | ----- |
| **5** | 7,2148 | 2,0553 | Patch terlalu kecil menyebabkan *undersampling*, kabut tidak terestimasi utuh. |
| **10** | **7,3536** | **2,0522** | **Keseimbangan terbaik**: resolusi spasial tinggi, detail tepi tidak terdegradasi. |
| **15** (Default) | 7,3439 | 2,0487 | Standar referensi He et al. (2009). |
| **25** | 7,3471 | 2,0398 | Patch terlalu lebar menimbulkan efek *oversmoothing* dan *halo* di sekitar dedaunan. |

> **Parameter Terpilih**: `patch_size` = 10 menghasilkan Entropy tertinggi (**7,3536**).

### 2. Pengaruh Koefisien Haze Removal (`omega`)

Mengontrol seberapa agresif kabut dieliminasi dari citra. Nilai yang diuji: $\{0,70; 0,85; 0,95; 1,00\}$.

| Nilai $\omega$ | Entropy | NIQE | Karakteristik Visual & Analisis |
| ----- | ----- | ----- | ----- |
| **0,70** | 7,3202 | 3,0555 | Masih menyisakan 30% kabut, kontras aspal dan jalanan masih agak pudar. |
| **0,85** | 7,3354 | 3,0551 | Kabut mulai berkurang, namun area gazebo masih agak terselubung asap. |
| **0,95** (Default) | 7,3439 | 3,0512 | Restorasi seimbang dengan mempertahankan sedikit kabut tipis alami. |
| **1,00** | **7,3461** | 3,0547 | **Eliminasi kabut maksimal**: asap pekat terangkat penuh, aspal tampak tajam. |

> **Parameter Terpilih**: $\omega = 1,00$ menghasilkan Entropy tertinggi (**7,3461**).

### 3. Pengaruh Batas Bawah Transmisi (`t_min`)

Batas pengaman numerik untuk menghindari pembagian dengan angka mendekati nol pada area kabut ekstrem. Nilai yang diuji: $\{0,05; 0,10; 0,20; 0,30\}$.

| Nilai `t_min` | Entropy | NIQE | Karakteristik Visual & Analisis |
| ----- | ----- | ----- | ----- |
| **0,05** | 7,3439 | 3,0512 | Nilai identik, tidak ada piksel yang mencapai nilai di bawah 0,05. |
| **0,10** (Default) | **7,3439** | **3,0512** | **Standar pengaman numerik optimal** sesuai rekomendasi literatur. |
| **0,20** | 7,3439 | 3,0512 | Tidak terjadi perubahan karena nilai transmisi area jalanan $> 0,20$. |
| **0,30** | 7,3439 | 3,0512 | Nilai tetap stabil pada domain foto outdoor ini. |

> **Parameter Terpilih**: `t_min` = 0,10.

### 4. Pengaruh Radius Guided Filter (`r`)

Menentukan luas jendela *smoothing* pada proses penghalusan peta transmisi. Nilai yang diuji: $\{20, 40, 60, 80\}$.

| Nilai $r$ | Entropy | NIQE | Karakteristik Visual & Analisis |
| ----- | ----- | ----- | ----- |
| **20** | 7,3476 | **2,8169** | **NIQE Terbaik**: Penghalusan lokal sangat presisi, batas dedaunan bebas *halo*. |
| **40** | 7,3449 | 2,9601 | Transmisi mulai melebar ke area sekitar ranting pohon. |
| **60** (Default) | 7,3439 | 3,0512 | Standar He et al. (2013). |
| **80** | 7,3412 | 3,0667 | *Radius* terlalu lebar menyebabkan distorsi pada batas antara pohon dan langit. |

> **Parameter Terpilih**: $r = 20$ menghasilkan skor NIQE terbaik (**2,8169**, penurunan degradasi sebesar 0,23 poin dibanding default).

## Studi Kasus Komparasi: Mengapa DCP Gagal pada Citra Satelit Berawan?

Sebelum difokuskan pada foto luar ruangan, algoritma DCP terlebih dahulu diuji pada citra satelit **Sentinel-2 Level-2A (True Color Image tile T50MQV)** dengan tutupan awan tebal.

Hasil pengujian menunjukkan kontras performa yang sangat tajam antara kedua domain:

| Domain Citra | Kondisi | Nilai Entropy | Nilai NIQE | Estimasi Airlight ($A$) | Status Pemulihan |
| ----- | ----- | ----- | ----- | ----- | ----- |
| **Foto Outdoor (`hazy_outdoor.jpg`)** | Original | 7,3039 | 3,1886 | $[0,95, 0,92, 0,85]$ | **Berhasil Optimal** (Detail terangkat, NIQE membaik ke 2,80) |
| **Foto Outdoor (`hazy_outdoor.jpg`)** | **DCP Best** | **7,3456** | **2,8025** | $[0,95, 0,92, 0,85]$ | **Berhasil Optimal** (Detail terangkat, NIQE membaik ke 2,80) |
| **Citra Satelit (Sentinel-2)** | Original | 6,5784 | 2,0369 | $[1,00, 1,00, 1,00]$ | **Gagal / Terlalu Gelap** (Entropy anjlok, daratan menghitam) |
| **Citra Satelit (Sentinel-2)** | **DCP Default** | **5,8628** | **2,0487** | $[1,00, 1,00, 1,00]$ | **Gagal / Terlalu Gelap** (Entropy anjlok, daratan menghitam) |

### Penjelasan Ilmiah Kegagalan DCP pada Citra Satelit:

1. **Pelanggaran Asumsi Dark Channel**: Awan tebal memiliki karakteristik reflektansi spektral yang sangat tinggi dan merata di seluruh saluran optis (R, G, dan B). Akibatnya, pada area berawan tebal, nilai $J^{\text{dark}}(x) \gg 0$, melanggar asumsi dasar He et al. (2009).
2. **Distorsi Ekstrem Nilai Airlight** ($A$): Keberadaan awan putih pekat menyebabkan 0,1% piksel paling terang pada *dark channel* jatuh pada inti awan, sehingga vektor $A$ terestimasi mencapai nilai saturasi maksimum $A = [1,0; 1,0; 1,0]$.
3. **Penyempitan Rentang Dinamis & Clipping**: Ketika nilai $A = 1,0$ dimasukkan ke rumus rekonstruksi:

   $$
   J(x) = \frac{I(x) - 1,0}{t(x)} + 1,0
   $$

   Pada area daratan dan lautan (yang memiliki $I(x) < 0,5$), pembilang $(I(x) - A)$ bernilai negatif besar. Setelah dibagi dengan $t(x)$ dan dibatasi ke rentang $[0, 1]$, nilai piksel terpangkas (*clipped*) menjadi nol. Akibatnya, seluruh daratan menjadi sangat gelap gulita (*under-exposed*) dan nilai Entropy turun drastis dari 6,5784 menjadi 5,8628.

> **Kesimpulan Kunci**: Awan tebal dan kabut asap (*haze*) adalah dua fenomena fisik atmosfer yang berbeda. DCP sangat efektif untuk kabut asap partikulat pada foto luar ruangan, namun memerlukan modifikasi khusus (seperti segmentasi awan terlebih dahulu atau algoritma *Color Attenuation Prior*) jika ingin diterapkan pada citra satelit penginderaan jauh ([Zhao et al., 2025](https://doi.org/10.3389/frsen.2024.1543342)).

## Struktur Repositori

```
├── results/
│   ├── result_darkch.png                  # Hasil ekstraksi Dark Channel
│   ├── result_transmission_raw.png        # Peta transmisi kasar
│   ├── result_transmission_refined.png    # Peta transmisi setelah Guided Filter
│   ├── result_dcp_default.png             # Hasil dehazing parameter default
│   └── result_dcp_best.png                # Hasil dehazing parameter optimal (Best)
├── hazy_outdoor.jpg                       # Citra input uji di root (foto outdoor berkabut)
├── dehaze_dcp_analysis.m                  # Skrip utama MATLAB (Pipeline, Sensitivity Analysis, Best Parameter Search)
└── README.md                              # Dokumentasi lengkap proyek (Laporan Riset)
```

## Cara Menjalankan Kode

1. **Prasyarat**:

   * MATLAB R2020a atau versi yang lebih baru.
   * *Image Processing Toolbox* (untuk fungsi `rgb2gray`, `imerode`, `imhist`, `entropy`, dan `niqe`).

2. **Menjalankan Program**:

   * Pastikan file citra `hazy_outdoor.jpg` berada di direktori yang sama dengan skrip `dehaze_dcp_analysis.m`.
   * Buka MATLAB dan jalankan skrip:

```matlab
     run('dehaze_dcp_analysis.m')
```

   * Skrip akan secara otomatis:

     1. Menjalankan *pipeline* dasar DCP dengan parameter default He et al. (2009).
     2. Menjalankan iterasi *Sensitivity Analysis* untuk 4 parameter (`patch_size`, $\omega$, `t_min`, $r$).
     3. Mencari parameter terbaik secara otomatis berdasarkan optimasi nilai Entropy.
     4. Menghasilkan dan menampilkan perbandingan visual akhir (*Original* vs *DCP Default* vs *DCP Best*).
     5. Menyimpan seluruh citra hasil ke folder `results/` dalam format PNG (`result_darkch.png`, `result_transmission_raw.png`, `result_transmission_refined.png`, `result_dcp_default.png`, `result_dcp_best.png`).

## Referensi Ilmiah

* He, K., Sun, J., & Tang, X. (2009). Single Image Haze Removal Using Dark Channel Prior. *IEEE Conference on Computer Vision and Pattern Recognition (CVPR)*, 1956–1963. <https://doi.org/10.1109/CVPR.2009.5206515>
* He, K., Sun, J., & Tang, X. (2013). Guided Image Filtering. *IEEE Transactions on Pattern Analysis and Machine Intelligence (TPAMI)*, 35(6), 1397–1409. <https://doi.org/10.1109/TPAMI.2012.213>
* Mittal, A., Soundararajan, R., & Bovik, A. C. (2013). Making a "Completely Blind" Image Quality Analyzer. *IEEE Signal Processing Letters*, 20(3), 209–212. <https://doi.org/10.1109/LSP.2012.2227705>
* Varga, D. (2022). No-Reference Quality Assessment of Authentically Distorted Images Based on Local and Global Features. *Journal of Imaging*, 8(6), 173. <https://doi.org/10.3390/jimaging8060173>
* Meraner, A., Ebel, P., Zhu, X. X., & Schmitt, M. (2020). Cloud removal in Sentinel-2 imagery using a deep residual neural network and SAR-optical data fusion. *ISPRS Journal of Photogrammetry and Remote Sensing*, 166, 333–346. <https://doi.org/10.1016/j.isprsjprs.2020.05.013>
* Zhao, D., Shi, K., Li, Z., & Chen, M. (2025). Improving remote sensing dehazing quality through local hybrid correction and optimization of atmospheric attenuation model based on wavelength. *Frontiers in Remote Sensing*, 5, 1543342. <https://doi.org/10.3389/frsen.2024.1543342>
* Fang, W. (2022). A Review of Traditional Dehazing Methods for Foggy Images. *Frontiers in Computing and Intelligent Systems*, 2(3), 22–25. <https://doi.org/10.54097/fcis.v2i3.5204>
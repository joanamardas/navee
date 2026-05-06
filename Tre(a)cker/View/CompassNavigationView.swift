// CompassNavigationView.swift
// Layar navigasi kompas — mengarahkan user ke pin tujuan step by step.
//
// ═══════════════════════════════════════════════════════════════
// FLOW UTAMA:
//   1. View muncul → LocationTracker mulai lacak GPS + heading
//   2. Setiap update GPS/heading → updateNav() recalculate bearing & distance
//   3. NavState.isOnTrack dievaluasi ulang setiap kali nav berubah
//   4. Kalau sampai (hasArrived) → flash overlay muncul → lanjut step berikutnya
// ═══════════════════════════════════════════════════════════════

import SwiftUI
import CoreLocation

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Konstanta Navigasi
// Kumpulkan semua "magic number" di satu tempat supaya mudah diubah.
// ─────────────────────────────────────────────────────────────────────────────
private enum Nav {
    /// Jarak (meter) yang dianggap "sudah tiba" di titik tujuan.
    static let arrivalRadius: Double    = 10

    /// Toleransi sudut (derajat) ke kanan/kiri dari bearing agar dianggap "on track".
    /// Contoh: 30° → user boleh melenceng ±30° dari arah lurus ke tujuan.
    static let onTrackTolerance: Double = 30

    /// Jarak maksimum (meter) yang dipakai sebagai skala posisi pin di kompas.
    /// Kalau lebih jauh dari ini, pin tetap di pinggir lingkaran.
    static let pinMaxDistance: Double   = 500

    /// Rasio minimum jarak pin dari pusat kompas (supaya pin tidak nempel di tengah).
    static let pinMinRatio: CGFloat     = 0.18
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - NavState
//
// Struct ini menyimpan semua info navigasi saat ini.
// Dibuat sebagai struct (value type) supaya SwiftUI otomatis re-render
// setiap kali ada field yang berubah.
// ─────────────────────────────────────────────────────────────────────────────
struct NavState {
    /// Arah wajah user saat ini dalam derajat (0–360, 0 = Utara).
    /// Diisi dari kompas perangkat (CoreMotion/CoreLocation).
    var userHeading: Double = 0

    /// Arah geografis dari posisi user ke titik tujuan (0–360, 0 = Utara).
    /// Dihitung ulang setiap kali posisi GPS atau target berubah.
    var bearing: Double = 0

    /// Jarak lurus (meter) dari posisi user ke titik tujuan.
    var distance: Double = 0

    /// Flag: sudah pernah menerima data heading dari kompas device?
    ///
    /// PENTING: Ini solusi untuk race condition "Wrong Way padahal arah benar".
    /// GPS bisa lock lebih cepat dari kompas (pakai cache lokasi).
    /// Akibatnya distance > 0 dan bearing sudah ada, tapi userHeading masih 0
    /// (nilai default, bukan dari device). Kalau bearing != 0°, maka
    /// angleDiff(0, bearing) bisa > toleransi → isOnTrack = false → "Wrong Way".
    ///
    /// Solusi: jangan evaluasi isOnTrack sampai heading pertama dari device tiba.
    var hasValidHeading: Bool = false

    // ── Computed properties ──────────────────────────────────────────────────

    /// True kalau distance sudah di dalam arrivalRadius (dan pernah dapat GPS valid).
    var hasArrived: Bool {
        distance > 0 && distance <= Nav.arrivalRadius
    }

    /// True kalau user menghadap ke arah yang kurang-lebih benar.
    ///
    /// SYARAT agar isOnTrack bisa dievaluasi:
    ///   1. distance > 0  → GPS sudah valid dan bearing sudah dihitung
    ///   2. !hasArrived   → belum tiba (kalau sudah tiba, "on track" tidak relevan)
    ///
    /// BUG FIX #1 (versi sebelumnya selalu Wrong Way):
    ///   onChange(heading) tidak memanggil updateNav(), sehingga bearing tidak
    ///   pernah fresh saat dibandingkan dengan userHeading. Sekarang keduanya
    ///   selalu di-update bersama di updateNav().
    ///
    /// BUG FIX #2 (versi sebelumnya selalu On Track):
    ///   Saat GPS belum ada, distance = 0 dan bearing = 0.
    ///   angleDiff(userHeading=0, bearing=0) = 0 → selalu ≤ toleransi → selalu On Track.
    ///   Fix: guard distance > 0 memastikan kita tidak evaluasi sebelum GPS siap.
    var isOnTrack: Bool {
        // Belum ada GPS → bearing belum valid.
        guard distance > 0 else { return false }

        // Belum ada heading dari device → userHeading masih 0 (default, bukan real).
        // Jangan evaluasi sampai kompas pertama kali kirim data.
        guard hasValidHeading else { return false }

        // Sudah tiba → status tidak relevan.
        guard !hasArrived else { return false }

        // Selisih sudut terpendek antara arah hadap user dan arah ke tujuan.
        // Hasil antara -180 dan +180 derajat.
        let diff = angleDiff(from: userHeading, to: bearing)

        // On track kalau selisihnya dalam toleransi ±onTrackTolerance.
        return abs(diff) <= Nav.onTrackTolerance
    }

    // ── Private helpers ──────────────────────────────────────────────────────

    /// Menghitung selisih sudut terpendek dari `a` ke `b`.
    /// Hasilnya selalu antara -180 dan +180 derajat.
    /// Contoh: angleDiff(350, 10) → 20  (bukan -340)
    private func angleDiff(from a: Double, to b: Double) -> Double {
        var d = b - a
        while d >  180 { d -= 360 }
        while d < -180 { d += 360 }
        return d
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - ArrivalKind
// Membedakan apakah yang dicapai adalah checkpoint (titik tengah) atau
// tujuan akhir — supaya overlay bisa tampil berbeda.
// ─────────────────────────────────────────────────────────────────────────────
private enum ArrivalKind {
    case checkpoint  // Titik antara — lanjut ke step berikutnya
    case final       // Titik terakhir — navigasi selesai
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Pin Icon & Color Helper
//
// Fungsi-fungsi ini mengubah string emoji/icon ke nama SF Symbol dan Color.
// Dipakai oleh DestinationPin dan TeardropPin supaya tampilan konsisten
// dengan tampilan di SavedMarkRow dan ModifyPin.
// ─────────────────────────────────────────────────────────────────────────────
private func pinIconColor(for emoji: String) -> Color {
    switch emoji {
    case "mappin":          return Color(red: 0.25, green: 0.55, blue: 1.0)   // Biru
    case "tent.fill":       return Color(red: 0.22, green: 0.65, blue: 0.38)  // Hijau tua
    case "sun.max.fill":    return Color(red: 1.0,  green: 0.72, blue: 0.10)  // Kuning
    case "water.waves":     return Color(red: 0.12, green: 0.68, blue: 0.90)  // Biru muda
    case "flag.fill":       return Color(red: 1.0,  green: 0.30, blue: 0.22)  // Merah
    case "mountain.2.fill": return Color(red: 0.50, green: 0.42, blue: 0.36)  // Coklat
    case "flame.fill":      return Color(red: 1.0,  green: 0.42, blue: 0.12)  // Oranye
    case "binoculars.fill": return Color(red: 0.40, green: 0.32, blue: 0.80)  // Ungu
    default:                return Color(red: 0.25, green: 0.55, blue: 1.0)   // Default biru
    }
}

/// Mengembalikan nama SF Symbol yang akan dipakai sebagai ikon pin.
/// Kalau emoji kosong, fallback ke "mappin".
private func pinIconName(for emoji: String) -> String {
    emoji.isEmpty ? "mappin" : emoji
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - CompassNavigationView  (Root View)
//
// View utama yang mengatur semua komponen navigasi.
//
// Parameter:
//   allLocations    — semua lokasi yang tersimpan (urutan dari jauh ke dekat)
//   destinationIndex — indeks lokasi tujuan di dalam allLocations
//   onEndNavigation — closure dipanggil saat user tekan "End" atau tiba di tujuan akhir
// ─────────────────────────────────────────────────────────────────────────────
struct CompassNavigationView: View {
    let allLocations: [Location]
    let destinationIndex: Int
    var onEndNavigation: () -> Void

    // LocationTracker adalah ObservableObject yang membungkus CoreLocation.
    // @StateObject supaya instance-nya tidak dibuat ulang saat view re-render.
    @StateObject private var tracker = LocationTracker()

    // nav menyimpan semua data navigasi saat ini (heading, bearing, distance).
    // Setiap kali nav berubah, seluruh view yang bergantung padanya akan re-render.
    @State private var nav = NavState()

    // currentStep adalah indeks langkah navigasi yang sedang aktif.
    // Bertambah 1 setiap kali user melewati satu checkpoint.
    @State private var currentStep = 0

    // State untuk overlay flash saat tiba di titik.
    @State private var arrivalFlash: ArrivalKind? = nil
    @State private var flashOpacity: Double = 0

    // ── Breadcrumbs ──────────────────────────────────────────────────────────
    //
    // "Breadcrumbs" adalah daftar titik yang harus dilewati secara berurutan
    // untuk mencapai tujuan. Dibaca terbalik dari allLocations.
    //
    // Contoh: allLocations = [A, B, C, D], destinationIndex = 1 (B)
    //   → breadcrumbs = [C, D] (titik setelah B, dibalik)
    //   → user navigasi: C dulu, lalu D (tujuan akhir)
    //
    // Kalau destinationIndex adalah yang terakhir, breadcrumbs = [tujuan itu saja].
    private var breadcrumbs: [Location] {
        guard destinationIndex < allLocations.count else { return [] }
        let lastIndex = allLocations.count - 1
        guard lastIndex > destinationIndex else {
            // Tidak ada titik setelah destinasi → langsung ke destinasi
            return [allLocations[destinationIndex]]
        }
        // Ambil titik dari setelah destinasi hingga akhir, lalu balik urutannya
        return (destinationIndex..<lastIndex).reversed().map { allLocations[$0] }
    }

    // Target yang sedang aktif sekarang (titik yang sedang dinavigasi)
    private var currentTarget: Location? { breadcrumbs[safe: currentStep] }

    // Jumlah total langkah navigasi
    private var totalSteps: Int { breadcrumbs.count }

    // Apakah langkah ini adalah yang terakhir?
    private var isLastStep: Bool { currentStep >= totalSteps - 1 }

    // Apakah user sudah tiba di tujuan akhir?
    private var finalArrived: Bool { nav.hasArrived && isLastStep }

    // Jumlah titik yang sudah dilewati (untuk progress dots)
    private var pointsPassed: Int {
        nav.hasArrived ? currentStep + 1 : currentStep
    }

    // ── Body ─────────────────────────────────────────────────────────────────
    var body: some View {
        ZStack {
            // Latar belakang hitam penuh layar
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Badge GPS di pojok kiri atas
                GPSBadgeView()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                Spacer(minLength: 0)

                // Kompas + label status di tengah layar
                VStack(spacing: 0) {
                    if let target = currentTarget {
                        CompassView(nav: nav, destination: target)
                            .padding(.horizontal, 32)
                    }
                    StatusLabel(nav: nav, finalArrived: finalArrived)
                        .padding(.top, 28)
                        .animation(.easeInOut(duration: 0.3), value: finalArrived)
                }

                Spacer(minLength: 32)

                // Kartu info di bagian bawah (nama tujuan, jarak, tombol End)
                BottomNavCard(
                    nav:             nav,
                    finalArrived:    finalArrived,
                    currentTarget:   currentTarget,
                    pointsPassed:    pointsPassed,
                    totalSteps:      totalSteps,
                    onEndNavigation: onEndNavigation
                )
            }

            // Overlay flash — tampil sebentar saat user tiba di titik
            if arrivalFlash != nil {
                ArrivalFlashOverlay(kind: arrivalFlash!, opacity: flashOpacity)
                    .allowsHitTesting(false) // Jangan blokir tap di belakangnya
            }
        }
        // ── Lifecycle ─────────────────────────────────────────────────────────
        .onAppear    { tracker.startTracking() }   // Mulai GPS saat view tampil
        .onDisappear { tracker.stopTracking()  }   // Stop GPS saat view hilang

        // ── BUG FIX: Update heading DAN recalculate nav setiap heading berubah ──
        //
        // Bug sebelumnya: onChange heading hanya set nav.userHeading, tapi tidak
        // memanggil updateNav(). Akibatnya bearing tidak dibandingkan dengan
        // heading terbaru — isOnTrack selalu false.
        //
        // Fix: Panggil updateNav() setiap kali heading berubah supaya
        // isOnTrack langsung dievaluasi ulang dengan data terkini.
        .onChange(of: tracker.heading) { _, newHeading in
            nav.userHeading = newHeading  // Simpan heading dari device

            // Tandai bahwa kita sudah pernah dapat heading nyata dari kompas device.
            // Setelah ini, isOnTrack boleh dievaluasi (tidak lagi pakai default 0).
            if !nav.hasValidHeading { nav.hasValidHeading = true }

            updateNav(from: tracker.userLocation) // Hitung ulang bearing & distance
        }

        // ── Update nav saat posisi GPS berubah ────────────────────────────────
        .onChange(of: tracker.userLocation) { _, newLocation in
            updateNav(from: newLocation) // Hitung ulang bearing & distance
            checkArrival()               // Cek apakah sudah tiba
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - updateNav
    //
    // Menghitung ulang bearing dan distance dari posisi user ke target saat ini.
    // Dipanggil setiap kali heading ATAU posisi GPS berubah.
    //
    // BUG FIX: Fungsi ini sekarang dipanggil dari KEDUA onChange (heading & location),
    // bukan hanya dari onChange location. Ini memastikan isOnTrack selalu
    // dievaluasi dengan data heading dan bearing yang sama-sama fresh.
    // ─────────────────────────────────────────────────────────────────────────
    private func updateNav(from location: CLLocation?) {
        guard let coord = location?.coordinate, let target = currentTarget else { return }

        // Hitung bearing (arah geografis ke target) dan distance (jarak ke target)
        nav.bearing  = bearing(from: coord, to: target.coordinate)
        nav.distance = distance(from: coord, to: target.coordinate)

        // isOnTrack otomatis terevaluasi ulang karena nav berubah (SwiftUI reactivity)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - checkArrival
    //
    // Dipanggil setiap kali posisi GPS berubah.
    // Kalau user sudah dalam radius tiba, trigger flash overlay
    // dan (kalau bukan step terakhir) lanjut ke step berikutnya.
    // ─────────────────────────────────────────────────────────────────────────
    private func checkArrival() {
        guard nav.hasArrived else { return }

        if isLastStep {
            // Tiba di tujuan akhir → flash kuning, tidak lanjut step
            triggerFlash(.final)
        } else {
            // Tiba di checkpoint → flash hijau, lalu pindah ke step berikutnya
            triggerFlash(.checkpoint) {
                withAnimation(.easeInOut(duration: 0.4)) {
                    currentStep += 1 // Maju ke titik berikutnya
                }
                updateNav(from: tracker.userLocation) // Hitung ulang untuk target baru
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - triggerFlash
    //
    // Menampilkan overlay animasi sesaat saat user tiba di titik.
    // Setelah animasi selesai, panggil `completion` jika ada.
    // Guard `arrivalFlash == nil` mencegah flash dipicu ganda.
    // ─────────────────────────────────────────────────────────────────────────
    private func triggerFlash(_ kind: ArrivalKind, completion: (() -> Void)? = nil) {
        guard arrivalFlash == nil else { return } // Hindari double-trigger
        arrivalFlash = kind

        // Fade in cepat (0.2 detik)
        withAnimation(.easeOut(duration: 0.2)) { flashOpacity = 1 }

        // Setelah 1.1 detik, mulai fade out
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation(.easeIn(duration: 0.35)) { flashOpacity = 0 }

            // Setelah fade out selesai (0.35 detik), bersihkan state dan panggil completion
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                arrivalFlash = nil
                completion?()
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Kalkulasi Geografis
    // ─────────────────────────────────────────────────────────────────────────

    /// Menghitung bearing (arah) dari koordinat `start` ke koordinat `end`.
    /// Menggunakan rumus Haversine untuk akurasi di permukaan bumi.
    /// Hasil dalam derajat (0–360, 0 = Utara, searah jarum jam).
    private func bearing(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> Double {
        let lat1 = start.latitude  * .pi / 180  // Konversi ke radian
        let lat2 = end.latitude    * .pi / 180
        let dLon = (end.longitude - start.longitude) * .pi / 180

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)

        // atan2 menghasilkan -180 hingga +180, tambah 360 dan modulo agar 0–360
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    /// Menghitung jarak garis lurus (meter) antara dua koordinat.
    /// Menggunakan CLLocation.distance() yang sudah akurat untuk jarak pendek maupun jauh.
    private func distance(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Array Safe Subscript
//
// Extension agar bisa akses array[safe: index] tanpa crash kalau index out of range.
// Mengembalikan nil kalau indeks tidak valid.
// ─────────────────────────────────────────────────────────────────────────────
private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - ArrivalFlashOverlay
//
// Overlay yang muncul sebentar saat user tiba di titik.
// Tampil sebagai kartu frosted glass di tengah layar.
//   • .checkpoint → ikon centang hijau
//   • .final      → ikon bendera kuning
// ─────────────────────────────────────────────────────────────────────────────
private struct ArrivalFlashOverlay: View {
    let kind: ArrivalKind
    let opacity: Double // 0.0 = transparan, 1.0 = penuh

    // Warna aksen sesuai jenis kedatangan
    private var accentColor: Color {
        kind == .final
            ? Color(red: 1.0, green: 0.84, blue: 0.04) // Kuning untuk final
            : Color(red: 0.20, green: 0.78, blue: 0.35) // Hijau untuk checkpoint
    }

    // Ikon SF Symbol sesuai jenis kedatangan
    private var icon: String {
        kind == .final ? "flag.checkered.circle.fill" : "checkmark.circle.fill"
    }

    private var title: String {
        kind == .final ? "You've Arrived" : "Checkpoint"
    }

    private var subtitle: String {
        kind == .final ? "Destination reached" : "Moving to the next point"
    }

    var body: some View {
        ZStack {
            // Scrim gelap tipis di belakang kartu
            Color.black
                .opacity(opacity * 0.35)
                .ignoresSafeArea()

            // Kartu frosted glass di tengah
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 52, weight: .regular))
                    .foregroundStyle(accentColor)
                    .symbolRenderingMode(.hierarchical)

                Text(title)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)

                Text(subtitle)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 32)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
            // Sedikit efek scale saat fade in/out supaya terasa "pop"
            .scaleEffect(0.88 + 0.12 * opacity)
            .opacity(opacity)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - StatusLabel
//
// Teks di bawah kompas yang menunjukkan apakah user sedang menuju arah benar.
// Hanya ada 2 state: "On Track" (hijau) atau "Wrong Way" (merah).
// ─────────────────────────────────────────────────────────────────────────────
private struct StatusLabel: View {
    let nav: NavState
    let finalArrived: Bool

    // "Belum siap" = GPS belum ada ATAU heading dari device belum diterima.
    // Jangan tampilkan On Track / Wrong Way sebelum kedua data valid.
    private var noGPS: Bool { nav.distance == 0 || !nav.hasValidHeading }

    private var label: String {
        if noGPS        { return "Searching GPS…" }
        if finalArrived { return "Arrived!" }
        return nav.isOnTrack ? "On Track" : "Wrong Way"
    }

    private var subtitle: String {
        if noGPS        { return "Waiting for location signal" }
        if finalArrived { return "You have reached your destination" }
        return nav.isOnTrack
            ? "Continue toward your destination"
            : "Head back toward the route"
    }

    private var dotColor: Color {
        if noGPS        { return Color.white.opacity(0.35) }                  // Abu — belum ada GPS
        if finalArrived { return Color(red: 1.0, green: 0.84, blue: 0.04) }  // Kuning — tiba
        return nav.isOnTrack
            ? Color(red: 0.20, green: 0.78, blue: 0.35) // Hijau — on track
            : Color(red: 1.0,  green: 0.27, blue: 0.23) // Merah — wrong way
    }

    var body: some View {
        VStack(spacing: 6) {
            // Pill / kapsul dengan titik indikator dan label
            HStack(spacing: 5) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 6, height: 6)
                Text(label)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(dotColor)
                    .kerning(0.3)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 6)
            .background(dotColor.opacity(0.13))
            .clipShape(Capsule())

            // Subtitle penjelasan
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.45))
                .multilineTextAlignment(.center)
        }
        // Animasi smooth saat status berubah
        .animation(.easeInOut(duration: 0.25), value: label)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - CompassView
//
// Container view untuk semua lapisan kompas.
// Menggunakan GeometryReader supaya semua komponen berskala relatif
// terhadap lebar yang tersedia.
//
// Layer (dari bawah ke atas):
//   1. DirectionCone  — sorotan arah (cone hijau/putih)
//   2. CompassDial    — lingkaran dengan tick marks dan label arah
//   3. DestinationPin — ikon pin tujuan yang berputar sesuai bearing
//   4. NorthPointer   — segitiga merah penanda Utara (diam, tidak berputar)
//   5. UserDot        — titik biru di tengah (posisi user)
// ─────────────────────────────────────────────────────────────────────────────
private struct CompassView: View {
    let nav: NavState
    let destination: Location

    var body: some View {
        GeometryReader { geo in
            let size   = geo.size.width
            let radius = size / 2 // Radius lingkaran kompas

            ZStack {
                // Layer 1: Cone arah — SENGAJA tidak dirotate, selalu di atas.
                //
                // Cone = "zona on track" = area lurus di depan user.
                // Konsepnya seperti kompas fisik: cone diam, dial yang berputar.
                // Kalau pin bergerak masuk ke zona cone → user menghadap ke arah benar.
                DirectionCone(isOnTrack: nav.isOnTrack, radius: radius)

                // Layer 2: Dial kompas dengan tick marks
                CompassDial(
                    userHeading: nav.userHeading,
                    isOnTrack:   nav.isOnTrack,
                    radius:      radius
                )
                .frame(width: size, height: size)

                // Layer 3: Pin tujuan
                // .rotationEffect(-userHeading) membuat pin "mengikuti" bearing
                // relatif terhadap arah hadap user.
                DestinationPin(nav: nav, radius: radius * 0.9, destination: destination)
                    .rotationEffect(.degrees(-nav.userHeading))

                // Layer 4: Penanda Utara (tidak ikut berputar karena dial yang berputar)
                NorthPointer(radius: radius)

                // Layer 5: Titik user di tengah
                UserDot()
            }
            .frame(width: size, height: size)
        }
        .aspectRatio(1, contentMode: .fit) // Pastikan kompas selalu berbentuk lingkaran
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - CompassDial
//
// Lingkaran kompas dengan tick marks dan label cardinal (N, NE, E, dst).
// Berputar sesuai heading user — jadi "N" selalu menunjuk ke Utara geografis.
//
// Catatan tentang Canvas:
//   Canvas di SwiftUI adalah cara menggambar 2D secara efisien menggunakan
//   Core Graphics. Lebih cepat dari menumpuk banyak Shape/View.
// ─────────────────────────────────────────────────────────────────────────────
private struct CompassDial: View {
    let userHeading: Double // Dipakai untuk memutar semua elemen dial
    let isOnTrack: Bool     // Kalau on track, tick marks jadi hijau
    let radius: CGFloat

    // Label arah cardinal beserta sudutnya dan flag apakah "major" (N/E/S/W)
    private let cardinalLabels: [(text: String, deg: Double, major: Bool)] = [
        ("N",  0,   true),  ("NE",  45, false),
        ("E",  90,  true),  ("SE", 135, false),
        ("S",  180, true),  ("SW", 225, false),
        ("W",  270, true),  ("NW", 315, false)
    ]

    var body: some View {
        Canvas { ctx, size in
            let cx = size.width  / 2 // Titik tengah X
            let cy = size.height / 2 // Titik tengah Y
            let R  = min(cx, cy)     // Radius efektif

            // ── Gambar lingkaran luar tipis ────────────────────────────────
            let ring = Path(ellipseIn: CGRect(x: cx - R, y: cy - R, width: R * 2, height: R * 2))
            ctx.stroke(ring, with: .color(.white.opacity(0.08)), lineWidth: 1)

            // ── Gambar tick marks setiap 2 derajat ────────────────────────
            for deg in stride(from: 0.0, to: 360.0, by: 2.0) {
                // Tentukan jenis tick berdasarkan sudut
                let isMajor  = deg.truncatingRemainder(dividingBy: 90) == 0  // N/E/S/W
                let isCard   = deg.truncatingRemainder(dividingBy: 45) == 0 && !isMajor // NE/SE/dll
                let isMedium = deg.truncatingRemainder(dividingBy: 10) == 0 && !isCard && !isMajor

                // Panjang tick (major lebih panjang)
                let outer: CGFloat = R - 2
                let inner: CGFloat = isMajor ? R - 22 : isCard ? R - 16 : isMedium ? R - 11 : R - 7

                // Posisi tick di lingkaran, disesuaikan dengan heading user
                // Pengurangan userHeading membuat dial berputar berlawanan arah heading
                let rad  = (deg - userHeading - 90) * .pi / 180
                let cosV = CGFloat(Foundation.cos(rad))
                let sinV = CGFloat(Foundation.sin(rad))

                // Gambar tick sebagai garis pendek
                var tick = Path()
                tick.move(to:    CGPoint(x: cx + outer * cosV, y: cy + outer * sinV))
                tick.addLine(to: CGPoint(x: cx + inner * cosV, y: cy + inner * sinV))

                // Ukuran dan opacity tick
                let width:   CGFloat = isMajor ? 2.5 : isCard ? 2.0 : isMedium ? 1.5 : 1.0
                let opacity: Double  = isMajor ? 1.0 : isCard ? 0.8 : isMedium ? 0.55 : 0.3

                // Tick "N" (0°) selalu putih. Lainnya: hijau kalau on track, putih kalau tidak.
                let tickColor: Color = (deg == 0 || !isOnTrack) ? .white : .green

                ctx.stroke(
                    tick,
                    with: .color(tickColor.opacity(opacity)),
                    style: StrokeStyle(lineWidth: width, lineCap: .round)
                )
            }
        }
        // id() memaksa Canvas redraw penuh saat isOnTrack berubah
        // (Canvas tidak otomatis re-draw saat captured value berubah)
        .id(isOnTrack)
        // ── Overlay label cardinal di atas Canvas ─────────────────────────
        .overlay(
            ZStack {
                ForEach(cardinalLabels, id: \.deg) { item in
                    // Hitung posisi label sesuai sudut dan heading
                    let rad  = (item.deg - userHeading) * .pi / 180
                    let dist = radius - (item.major ? 32 : 26)

                    Text(item.text)
                        .font(.system(
                            size:   item.major ? 13 : 10,
                            weight: item.major ? .bold : .medium,
                            design: .rounded
                        ))
                        .foregroundColor(
                            item.deg == 0 ? .white           // "N" selalu putih terang
                            : item.major  ? .white.opacity(0.85)
                            :               .white.opacity(0.4)
                        )
                        .offset(
                            x:  CGFloat(sin(rad))  * dist,
                            y: -CGFloat(cos(rad)) * dist
                        )
                }
            }
        )
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - NorthPointer
//
// Segitiga merah kecil yang selalu menunjuk ke Utara.
// Diposisikan di bagian atas lingkaran kompas.
// Tidak berputar karena dialnya yang berputar, bukan pointer-nya.
// ─────────────────────────────────────────────────────────────────────────────
private struct NorthPointer: View {
    let radius: CGFloat

    var body: some View {
        ArrowTriangle()
            .fill(Color.red)
            .frame(width: 8, height: 14)
            .offset(y: -(radius - 4)) // Geser ke atas mendekati pinggir lingkaran
    }
}

/// Shape segitiga runcing ke atas untuk NorthPointer.
private struct ArrowTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to:    CGPoint(x: rect.midX, y: rect.minY)) // Puncak atas
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY)) // Kanan bawah
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY)) // Kiri bawah
        p.closeSubpath()
        return p
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - DirectionCone
//
// Sorotan berbentuk cone (kerucut) yang menunjukkan zona "on track".
// Warna berubah:
//   • On track  → hijau transparan (user ada di jalur yang benar)
//   • Wrong way → putih redup (user melenceng dari arah)
//
// Cone selalu mengarah ke atas (arah yang dituju oleh pin ketika on track).
// ─────────────────────────────────────────────────────────────────────────────
private struct DirectionCone: View {
    let isOnTrack: Bool
    let radius: CGFloat

    var body: some View {
        // halfAngle cone lebih lebar dari toleransi isOnTrack (45° vs 30°)
        // supaya cone terlihat jelas dan user punya referensi visual yang nyaman.
        // isOnTrack masih pakai onTrackTolerance (30°) untuk logika, tapi
        // visualnya lebih lebar agar mudah diarahkan.
        ConeSectorShape(halfAngle: 30)
            .fill(coneGradient)
            .frame(width: radius * 2, height: radius * 2)
            .animation(.easeInOut(duration: 0.3), value: isOnTrack)
    }

    private var coneGradient: RadialGradient {
        // On track → hijau (user menuju arah benar)
        // Wrong way → putih redup (netral, tidak menambah kebingungan)
        // Opacity dinaikkan supaya cone lebih terlihat jelas sebagai panduan arah.
        let centerColor: Color = isOnTrack
            ? .green.opacity(0.40)
            : .white.opacity(0.12)
        return RadialGradient(
            colors:      [centerColor, .clear],
            center:      UnitPoint(x: 0.5, y: 1.0), // Titik asal dari bawah tengah
            startRadius: 0,
            endRadius:   radius * 2.0
        )
    }
}

/// Shape sektor lingkaran (irisan pie) untuk cone arah.
/// halfAngle menentukan lebar cone: cone = 2 × halfAngle derajat.
private struct ConeSectorShape: Shape {
    let halfAngle: Double

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        var path = Path()
        path.move(to: center)
        path.addArc(
            center:     center,
            radius:     r,
            startAngle: .degrees(-90 - halfAngle), // Kiri dari atas
            endAngle:   .degrees(-90 + halfAngle), // Kanan dari atas
            clockwise:  false
        )
        path.closeSubpath()
        return path
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - DestinationPin
//
// Ikon pin tujuan yang muncul di atas kompas, menunjukkan posisi relatif
// target terhadap user.
//
// Jarak pin dari pusat ∝ jarak sebenarnya ke target (hingga pinMaxDistance).
// Arah pin dari pusat = bearing ke target.
//
// State:
//   • On track / arrived → pin penuh berwarna (TeardropPin)
//   • Wrong way          → titik kecil redup (agar tidak membingungkan)
// ─────────────────────────────────────────────────────────────────────────────
private struct DestinationPin: View {
    let nav: NavState
    let radius: CGFloat
    let destination: Location

    /// Menghitung offset (posisi) pin dari pusat kompas.
    private var pinOffset: CGSize {
        let angleRad = nav.bearing * .pi / 180

        // Normalisasi jarak: 0 (dekat) hingga 1 (jauh / di batas pinMaxDistance)
        let ratio = CGFloat(min(nav.distance, Nav.pinMaxDistance) / Nav.pinMaxDistance)

        // Interpolasi dari posisi minimum ke maksimum
        let minR = radius * Nav.pinMinRatio      // Jarak minimum dari pusat
        let r    = minR + ratio * (radius - minR) // Jarak aktual pin

        // Konversi polar ke kartesian
        return CGSize(
            width:  CGFloat(sin(angleRad)) * r,
            height: -CGFloat(cos(angleRad)) * r // Negatif karena Y bertambah ke bawah di SwiftUI
        )
    }

    private var iconName: String { pinIconName(for: destination.emoji) }
    private var iconColor: Color { pinIconColor(for: destination.emoji) }

    var body: some View {
        Group {
            if nav.isOnTrack || nav.hasArrived {
                // Tampilkan pin penuh saat on track atau sudah tiba
                TeardropPin(color: iconColor, iconName: iconName, iconColor: .white)
            } else {
                // Tampilkan titik kecil redup saat wrong way
                // (pin penuh bisa membingungkan karena arahnya terlihat salah)
                Circle()
                    .fill(iconColor.opacity(0.5))
                    .frame(width: 10, height: 10)
            }
        }
        .offset(pinOffset)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - UserDot
//
// Titik di pusat kompas yang merepresentasikan posisi user.
// Tiga lingkaran berlapis:
//   1. Lingkaran putih transparan (halo/glow efek)
//   2. Lingkaran putih solid
//   3. Lingkaran biru di tengah (ciri khas Apple Maps)
// ─────────────────────────────────────────────────────────────────────────────
private struct UserDot: View {
    var body: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.12)).frame(width: 22, height: 22) // Halo
            Circle().fill(Color.white).frame(width: 13, height: 13)               // Ring putih
            Circle().fill(Color.blue).frame(width: 8,  height: 8)                 // Inti biru
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - TeardropPin
//
// Pin bergaya teardrop (tetes air) — lingkaran berikon di atas, ekor runcing di bawah.
// Mirip pin di Apple Maps / Google Maps.
// ─────────────────────────────────────────────────────────────────────────────
private struct TeardropPin: View {
    let color: Color
    let iconName: String
    let iconColor: Color

    var body: some View {
        VStack(spacing: 0) {
            // Kepala pin: lingkaran berwarna dengan ikon di tengah
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 34, height: 34)
                    .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            // Ekor pin: segitiga kecil di bawah lingkaran
            TeardropTail()
                .fill(color)
                .frame(width: 11, height: 9)
                .offset(y: -1) // Sedikit nempel ke lingkaran
        }
        // Geser pin ke atas supaya "ujung ekor" berada di titik koordinat
        .offset(y: -(34 + 9) / 2)
    }
}

/// Shape segitiga untuk ekor pin.
private struct TeardropTail: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to:    CGPoint(x: rect.minX, y: rect.minY)) // Kiri atas
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY)) // Kanan atas
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY)) // Tengah bawah (runcing)
        p.closeSubpath()
        return p
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - BottomNavCard
//
// Kartu informasi yang menempel di bagian bawah layar.
// Berisi:
//   • Nama tujuan saat ini
//   • Progress dots (berapa titik sudah dilewati)
//   • Jarak ke titik tujuan
//   • Tombol "End" untuk menghentikan navigasi
// ─────────────────────────────────────────────────────────────────────────────
private struct BottomNavCard: View {
    let nav: NavState
    let finalArrived: Bool
    let currentTarget: Location?
    let pointsPassed: Int
    let totalSteps: Int
    var onEndNavigation: () -> Void

    // Warna progress dot berubah sesuai status
    private var statusColor: Color {
        if nav.hasArrived { return Color(red: 1.0, green: 0.84, blue: 0.04) } // Kuning saat tiba
        return nav.isOnTrack
            ? Color(red: 0.20, green: 0.78, blue: 0.35) // Hijau on track
            : .white                                      // Putih wrong way
    }

    /// Memformat jarak ke string yang mudah dibaca (meter atau kilometer).
    private var distanceText: (value: String, unit: String) {
        let d = nav.distance
        guard d > 0 else { return ("—", "m") } // Belum dapat GPS
        return d < 1000
            ? ("\(Int(d))", "m")                        // Di bawah 1 km → tampilkan meter
            : (String(format: "%.1f", d / 1000), "km") // 1 km ke atas → tampilkan km
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Nama tujuan ────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 3) {
                Text("navigating to")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.32))
                    .textCase(.uppercase)
                    .kerning(0.5)

                Text(currentTarget?.name ?? "—")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65) // Kecilkan font kalau teks terlalu panjang
                    .animation(.easeInOut(duration: 0.3), value: currentTarget?.name)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            // ── Progress dots (hanya tampil kalau ada lebih dari 1 langkah) ──
            if totalSteps > 1 {
                ProgressDotsView(
                    currentStep: pointsPassed - 1,
                    totalSteps:  totalSteps,
                    activeColor: statusColor
                )
                .padding(.horizontal, 20)
                .padding(.top, 14)
            }

            // Garis pemisah tipis
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 0.5)
                .padding(.horizontal, 20)
                .padding(.top, 14)

            // ── Jarak + Tombol End ─────────────────────────────────────────
            HStack(alignment: .center, spacing: 12) {
                // Tampilan jarak dengan value besar dan unit kecil
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(distanceText.value)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .contentTransition(.numericText()) // Animasi angka berubah
                        .animation(.easeInOut(duration: 0.35), value: distanceText.value)
                    Text(distanceText.unit)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.4))
                }

                Spacer()

                // Tombol End — warna merah Apple
                Button(action: onEndNavigation) {
                    Text("End")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 13)
                        .background(Color(red: 1.0, green: 0.23, blue: 0.19))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 16)
        }
        .background(
            Color(red: 0.11, green: 0.11, blue: 0.12)
                .ignoresSafeArea(edges: .bottom) // Extend ke bawah safe area
        )
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius:    24, // Sudut atas kiri membulat
                bottomLeadingRadius: 0,  // Sudut bawah kiri lancip (nempel layar)
                bottomTrailingRadius: 0, // Sudut bawah kanan lancip (nempel layar)
                topTrailingRadius:   24, // Sudut atas kanan membulat
                style: .continuous
            )
        )
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - ProgressDotsView
//
// Deretan titik-titik kecil yang menunjukkan progres multi-step navigasi.
//
// State tiap titik:
//   • done    → titik putih redup (sudah dilewati)
//   • current → titik lebih besar berwarna (posisi sekarang)
//   • next    → titik putih sangat redup (belum dicapai)
//   • ellipsis → "···" untuk langkah yang disembunyikan (kalau terlalu banyak)
//
// Kalau total langkah ≤ 7, semua tampil. Kalau lebih, beberapa disembunyikan
// dan diganti ellipsis supaya tidak memenuhi layar.
// ─────────────────────────────────────────────────────────────────────────────
private struct ProgressDotsView: View {
    let currentStep: Int  // Indeks 0-based langkah yang sedang aktif
    let totalSteps: Int
    let activeColor: Color

    // Enum untuk jenis tampilan tiap dot
    private enum DotKind { case done, current, next, ellipsis }

    // Struct identifiable untuk ForEach
    private struct DotItem: Identifiable {
        let id: Int
        let kind: DotKind
    }

    /// Membangun daftar item dot yang akan ditampilkan.
    private var items: [DotItem] {
        guard totalSteps > 1 else { return [] }

        if totalSteps <= 7 {
            // Tampilkan semua dot
            return (0..<totalSteps).map { i in
                DotItem(
                    id:   i,
                    kind: i < currentStep ? .done : i == currentStep ? .current : .next
                )
            }
        }

        // Lebih dari 7 langkah — gunakan ellipsis di tengah
        var result: [DotItem] = []

        // 2 dot pertama selalu tampil
        for i in 0..<2 {
            result.append(DotItem(
                id:   i,
                kind: i < currentStep ? .done : i == currentStep ? .current : .next
            ))
        }

        result.append(DotItem(id: -1, kind: .ellipsis)) // Ellipsis pertama

        // Dot tengah (sekitar posisi saat ini)
        let mid = max(2, min(currentStep, totalSteps - 3))
        if mid > 1 && mid < totalSteps - 2 {
            result.append(DotItem(
                id:   mid,
                kind: mid < currentStep ? .done : mid == currentStep ? .current : .next
            ))
            result.append(DotItem(id: -2, kind: .ellipsis)) // Ellipsis kedua
        }

        // 2 dot terakhir selalu tampil
        for i in (totalSteps - 2)..<totalSteps {
            result.append(DotItem(
                id:   i,
                kind: i < currentStep ? .done : i == currentStep ? .current : .next
            ))
        }

        return result
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items) { item in
                switch item.kind {
                case .ellipsis:
                    // Teks "···" untuk mewakili langkah yang tersembunyi
                    Text("···")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.22))

                case .done:
                    // Langkah yang sudah dilewati — putih redup, kecil
                    Circle()
                        .fill(Color.white.opacity(0.35))
                        .frame(width: 5, height: 5)

                case .current:
                    // Langkah aktif — lebih besar dan berwarna
                    Circle()
                        .fill(activeColor)
                        .frame(width: 9, height: 9)
                        .animation(.easeInOut(duration: 0.25), value: currentStep)

                case .next:
                    // Langkah mendatang — putih sangat redup, kecil
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 5, height: 5)
                }
            }

            // Label teks di sebelah kanan dots
            Text("\(currentStep + 1) of \(totalSteps) points passed")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.28))
                .padding(.leading, 4)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - GPSBadgeView
//
// Badge kecil di pojok kiri atas yang menunjukkan status GPS.
// Saat ini selalu tampil hijau ("GPS aktif").
// Bisa dikembangkan untuk menunjukkan akurasi GPS sesungguhnya.
// ─────────────────────────────────────────────────────────────────────────────
struct GPSBadgeView: View {
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 11))
            Text("GPS:")
                .font(.system(size: 11, weight: .semibold))
            SignalBars() // Ikon 3 bar sinyal
        }
        .foregroundColor(.green)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.green.opacity(0.12))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.green.opacity(0.4), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// Tiga batang sinyal dengan tinggi berbeda (kecil, sedang, besar).
private struct SignalBars: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .frame(width: 3.5, height: CGFloat(5 + i * 3)) // Makin kanan makin tinggi
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Preview
//
// Data dummy untuk melihat tampilan di Xcode Canvas tanpa perlu device sungguhan.
// ─────────────────────────────────────────────────────────────────────────────
#Preview {
    let locs = [
        Location(name: "Titik 1", coordinate: .init(latitude: -6.291, longitude: 106.643), altitude: 10, emoji: "mappin",     notes: ""),
        Location(name: "Titik 2", coordinate: .init(latitude: -6.292, longitude: 106.644), altitude: 20, emoji: "tent.fill",  notes: ""),
        Location(name: "Titik 3", coordinate: .init(latitude: -6.293, longitude: 106.645), altitude: 30, emoji: "flag.fill",  notes: ""),
        Location(name: "Titik 4", coordinate: .init(latitude: -6.294, longitude: 106.646), altitude: 40, emoji: "flame.fill", notes: ""),
    ]
    CompassNavigationView(allLocations: locs, destinationIndex: 1, onEndNavigation: {})
}

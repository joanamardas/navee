//
//  UnifiedMarkSheet.swift
//  Navee
//

import SwiftUI
import CoreLocation

// MARK: - Sheet Content State

enum MarkSheetContent: Equatable {
    case list
    case detail(Location)
    case edit(Location.ID)

    static func == (lhs: MarkSheetContent, rhs: MarkSheetContent) -> Bool {
        switch (lhs, rhs) {
        case (.list, .list):                   return true
        case (.detail(let a), .detail(let b)): return a.id == b.id
        case (.edit(let a),   .edit(let b)):   return a == b
        default:                               return false
        }
    }
}

// MARK: - Custom Small Detent

struct SmallDetent: CustomPresentationDetent {
    static func height(in context: Context) -> CGFloat? { 240 }
}

// MARK: - UnifiedMarkSheet

struct UnifiedMarkSheet: View {
    @Binding var locations:    [Location]
    @Binding var content:      MarkSheetContent?
    var userLocation:          CLLocation?
    var onNavigate:            (Location) -> Void
    var onSelectOnMap:         (Location) -> Void

    @State private var selectedDetent:    PresentationDetent
    @State private var isDismissing:      Bool = false
    @State private var isGoingToEdit:     Bool = false
    @State private var isExpandingForEdit: Bool = false
    @State private var locationToDelete: Location? = nil

    private let spring: Animation = .spring(response: 0.4, dampingFraction: 0.82)

    init(
        locations:     Binding<[Location]>,
        content:       Binding<MarkSheetContent?>,
        userLocation:  CLLocation?,
        onNavigate:    @escaping (Location) -> Void,
        onSelectOnMap: @escaping (Location) -> Void
    ) {
        self._locations    = locations
        self._content      = content
        self.userLocation  = userLocation
        self.onNavigate    = onNavigate
        self.onSelectOnMap = onSelectOnMap

        if case .detail = content.wrappedValue {
            self._selectedDetent = State(initialValue: .custom(SmallDetent.self))
        } else {
            self._selectedDetent = State(initialValue: .large)
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                currentView
            }
            // Semua transisi konten pakai opacity — tidak ada slide
            // supaya tidak clash dengan animasi sheet naik/turun
            .animation(.easeInOut(duration: 0.2), value: content)
        }
        .onAppear {
            isDismissing       = false
            isGoingToEdit      = false
            isExpandingForEdit = false
        }
        .presentationDetents(availableDetents, selection: $selectedDetent)
        .presentationDragIndicator(.visible)
        .presentationBackground(.black)
        .presentationBackgroundInteraction(.enabled)
        .preferredColorScheme(.dark)
        .onChange(of: content) { _, newContent in
            if newContent != nil { isDismissing = false }
            // Jangan sentuh selectedDetent saat dismiss (content = nil)
            // supaya sheet langsung nutup ke bawah tanpa naik dulu
            guard !isDismissing, let newContent else { return }
            selectedDetent = targetDetent(for: newContent)
        }
        .onChange(of: selectedDetent) { _, newDetent in
            guard !isDismissing, !isGoingToEdit else { return }
            // Drag naik dari detail → switch ke list
            if case .detail = content, newDetent == .large {
                content = .list
            }
        }
    }

    // MARK: - Current View
    // Semua case pakai opacity — sheet yang animasi naik/turun, bukan konten slide

    @ViewBuilder
    private var currentView: some View {
        switch content {
        case .detail(let location):
            detailView(for: location)
                .id("detail-\(location.id)")
                .transition(.opacity)
        case .edit(let id):
            editView(for: id)
                .id("edit-\(id)")
                .transition(.opacity)
        default:
            listView
                .id("list")
                .transition(.opacity)
        }
    }

    // MARK: - Detents

    private var availableDetents: Set<PresentationDetent> {
        // Saat dismiss, hanya [.large] supaya sheet tidak snap naik dulu
        if isDismissing { return [.large] }
        // Saat expanding ke edit, lock ke [small, large] supaya iOS
        // tahu dari mana sheet naik — jangan hapus small dulu sebelum animasi selesai
        if isExpandingForEdit { return [.custom(SmallDetent.self), .large] }
        switch content {
        case .detail: return [.custom(SmallDetent.self), .large]
        default:      return [.large]
        }
    }

    private func targetDetent(for c: MarkSheetContent?) -> PresentationDetent {
        if case .detail = c { return .custom(SmallDetent.self) }
        return .large
    }

    // MARK: - Dismiss

    private func dismiss() {
        isDismissing       = true
        isGoingToEdit      = false
        isExpandingForEdit = false
        selectedDetent     = .large  // sync dulu sebelum availableDetents berubah
        content            = nil
    }

    // MARK: - Case 1: List

    private var listView: some View {
        Group {
            if locations.isEmpty {
                EmptySavedMarksView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(locations) { location in
                        SavedMarkRow(
                            location:     location,
                            userLocation: userLocation,
                            onSelect: {
                                onSelectOnMap(location)
                                content        = .detail(location)
                                selectedDetent = .custom(SmallDetent.self)
                            }
                        )
                        .listRowBackground(Color.black)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                        .listRowSeparatorTint(Color.white.opacity(0.1))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                locationToDelete = location
//                                locations.removeAll { $0.id == location.id }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            
                            Button {
                                onSelectOnMap(location)
                                content        = .edit(location.id)
                                selectedDetent = .large
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .alert("Delete this location?", isPresented: Binding(
                    get: { locationToDelete != nil },
                    set: { if !$0 { locationToDelete = nil } }
                )) {
                    Button("Delete", role: .destructive) {
                        if let loc = locationToDelete {
                            locations.removeAll { $0.id == loc.id }
                            locationToDelete = nil
                        }
                    }
                    Button("Cancel", role: .cancel) {
                        locationToDelete = nil
                    }
                } message: {
                    Text("This action cannot be undone.")
                }
            }
        }
        .navigationTitle("Saved Points")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .close) { dismiss() }
            }
        }
    }

    // MARK: - Case 2: Detail

    private func detailView(for location: Location) -> some View {
        let live = locations.first(where: { $0.id == location.id }) ?? location

        return BottomPinDetailView(
            location:     live,
            userLocation: userLocation,
            onNavigate: {
                dismiss()
                onNavigate(live)
            },
            onEdit: {
                // Lock availableDetents ke [small, large] supaya sheet
                // bisa naik smooth dari small. Konten ganti bersamaan (fade).
                // Setelah animasi selesai (~420ms) baru release lock.
                isGoingToEdit      = true
                isExpandingForEdit = true
                selectedDetent     = .large
                content            = .edit(live.id)
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(420))
                    isExpandingForEdit = false
                    isGoingToEdit      = false
                }
            }
        )
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .close) { dismiss() }
            }
        }
    }

    // MARK: - Case 3: Edit

    @ViewBuilder
    private func editView(for id: Location.ID) -> some View {
        if let index = locations.firstIndex(where: { $0.id == id }) {
            ModifyPin(
                location:     $locations[index],
                userLocation: userLocation,
                onSave: {
                    if let loc = locations.first(where: { $0.id == id }) {
                        content        = .detail(loc)
                        selectedDetent = .custom(SmallDetent.self)
                    } else {
                        content = .list
                    }
                },
                onDelete: {
                    locations.removeAll { $0.id == id }
                    content = locations.isEmpty ? nil : .list
                }
            )
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        if let loc = locations.first(where: { $0.id == id }) {
                            content        = .detail(loc)
                            selectedDetent = .custom(SmallDetent.self)
                        } else {
                            content = .list
                        }
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                }
            }
        }
    }
}

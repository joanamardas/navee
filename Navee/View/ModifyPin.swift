//
//  ModifyPin.swift
//  Navee
//

import SwiftUI
import CoreLocation

struct ModifyPin: View {
    @Binding var location: Location
    var userLocation: CLLocation?
    var onSave:   () -> Void
    var onDelete: () -> Void

    @State private var draft:            Location
    @State private var photo: Data?
    @State private var showDeleteAlert = false

    private let nameLimit = 20

    init(
        location: Binding<Location>,
        userLocation: CLLocation?,
        onSave: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self._location    = location
        self.userLocation = userLocation
        self.onSave       = onSave
        self.onDelete     = onDelete
        self._draft       = State(initialValue: location.wrappedValue)
    }

    var body: some View {
        List {
            nameSection
            IconPickerSection(selectedIcon: $draft.emoji)
            photoSection
            infoSection
            deleteSection
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .navigationTitle("Edit Point")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    location = draft
                    onSave()
                } label: {
                    Image(systemName: "checkmark")
                }
                .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .preferredColorScheme(.dark)
        .alert("Delete Location?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) { onDelete() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action cannot be undone.")
        }
    }

    // MARK: - Name

    private var nameSection: some View {
        Section {
            HStack {
                TextField("Point name", text: $draft.name)
                    .onChange(of: draft.name) { _, new in
                        if new.count > nameLimit {
                            draft.name = String(new.prefix(nameLimit))
                        }
                    }
                Spacer()
                Text("\(min(draft.name.count, nameLimit))/\(nameLimit)")
                    .font(.caption)
                    .foregroundStyle(draft.name.count >= nameLimit ? .red : .secondary)
                    .monospacedDigit()
                    .animation(.none, value: draft.name.count)
            }
        }
    }

    // MARK: - Photo

    // var tempat buat nyimpen photoData
    private var photoSection: some View {
        Section {
            PointPhotoPickerView(photoData: $draft.photoData)
                .listRowInsets(EdgeInsets())
        }
    }

    // MARK: - Info

    private var infoSection: some View {
        Section {
            InfoRow(label: "Distance", value: draft.formattedDistance(from: userLocation, suffix: "away"))
            InfoRow(label: "Altitude", value: "\(Int(draft.altitude)) masl")
            InfoRow(label: "Coordinates", value: String(format: "%.4f, %.4f", draft.coordinate.latitude, draft.coordinate.longitude))
            InfoRow(label: "Saved", value: draft.timestamp.relativeFormatted())
        }
    }

    // MARK: - Delete

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                Text("Delete Location")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
}

// MARK: - IconPickerSection

private struct IconPickerSection: View {
    @Binding var selectedIcon: String
    @State private var scrollOffset: CGFloat = 0
    @State private var contentWidth: CGFloat = 0
    @State private var viewWidth:    CGFloat = 0

    private var showLeftFade:  Bool { scrollOffset > 8 }
    private var showRightFade: Bool { scrollOffset < contentWidth - viewWidth - 8 }

    var body: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                IconPicker(selectedIcon: $selectedIcon)
                    .padding(.leading, 2)
                    .padding(.trailing, 32) // trailing lebih lebar supaya icon terakhir keliatan terpotong fade
                    .background(
                        GeometryReader { geo in
                            Color.clear.onAppear { contentWidth = geo.size.width }
                        }
                    )
            }
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.x
            } action: { _, new in
                scrollOffset = new
            }
            .background(
                GeometryReader { geo in
                    Color.clear.onAppear { viewWidth = geo.size.width }
                }
            )
            .overlay(alignment: .leading) {
                if showLeftFade {
                    fadeMask(direction: .leading)
                        .transition(.opacity)
                }
            }
            .overlay(alignment: .trailing) {
                fadeMask(direction: .trailing) // kanan selalu ada sampai mentok
                    .opacity(showRightFade ? 1 : 0)
            }
            .animation(.easeInOut(duration: 0.2), value: showLeftFade)
            .animation(.easeInOut(duration: 0.2), value: showRightFade)
        }
    }

    private func fadeMask(direction: UnitPoint) -> some View {
        LinearGradient(
            colors: [
                Color(UIColor.secondarySystemGroupedBackground),
                .clear
            ],
            startPoint: direction,
            endPoint: direction == .leading ? .trailing : .leading
        )
        .frame(width: 56) // lebih lebar supaya lebih kelihatan
        .allowsHitTesting(false)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ModifyPin(
            location: .constant(Location(
                name:       "Point 1",
                coordinate: .init(latitude: -6.2, longitude: 106.8166),
                altitude:   12,
                emoji:      "flame.fill",
                notes:      ""
            )),
            userLocation: CLLocation(latitude: -6.2012, longitude: 106.8154),
            onSave:   {},
            onDelete: {}
        )
    }
    .preferredColorScheme(.dark)
}

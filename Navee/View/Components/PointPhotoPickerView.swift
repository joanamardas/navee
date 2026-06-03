//
//  PointPhotoPickerView.swift
//  Navee
//
//  Photo picker section for the Edit Point screen.
//  Drop this inside any List Section — it shows a camera placeholder
//  or the saved photo, and lets the user take a new photo or pick
//  one from their library.

import SwiftUI
import PhotosUI

// MARK: - PointPhotoPickerView

struct PointPhotoPickerView: View {
    @State var isActive = false
    
    @Binding var photoData: Data?

    @State private var showOptions      = false
    @State private var showCamera       = false
    @State private var showPhotosPicker = false
    @State private var pickerItem:       PhotosPickerItem?

    var body: some View {
        photoContent
            .frame(maxWidth: .infinity)
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
            .onTapGesture { showOptions = true }
            .confirmationDialog("Photo", isPresented: $showOptions, titleVisibility: .hidden) {
                Button("Take Photo")           { showCamera       = true }
                Button("Choose from Library")  { showPhotosPicker = true }
                if photoData != nil {
                    Button("Remove Photo", role: .destructive) { photoData = nil }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPickerView(photoData: $photoData)
                    .ignoresSafeArea()
            }
            .photosPicker(
                isPresented: $showPhotosPicker,
                selection:   $pickerItem,
                matching:    .images
            )
            .onChange(of: pickerItem) { _, item in
    
                // code ini ambil/pick photo, trus simpen ke photoData
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self) {
                        photoData = data
                    }
                    pickerItem = nil
                }
            }
    }

    // MARK: - Photo / Placeholder

    @ViewBuilder
    private var photoContent: some View {
        if let data = photoData, let image = UIImage(data: data) { // A conditional view means showing different UI depending on a condition. If a photo exists → show the photo, if no photo exists → show the camera placeholder.
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .overlay(alignment: .topTrailing) {
                    Button { photoData = nil } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color.black.opacity(0.6))
                    }
                    .padding(8)
                }
        } else {
            ZStack {
                Color(UIColor.tertiarySystemFill)
                Image(systemName: "camera.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Camera UIViewControllerRepresentable

private struct CameraPickerView: UIViewControllerRepresentable {
    @Binding var photoData: Data?
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker        = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate   = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: CameraPickerView
        init(_ parent: CameraPickerView) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.photoData = image.jpegData(compressionQuality: 0.8)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

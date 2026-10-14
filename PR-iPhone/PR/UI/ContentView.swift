import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

private enum WorkspaceMode: String, CaseIterable {
    case photo = "ФОТО"
    case video = "ВИДЕО"
}

struct ContentView: View {
    @EnvironmentObject private var project: EditorProject
    @State private var mode: WorkspaceMode = .photo
    @State private var photoItem: PhotosPickerItem?
    @State private var videoItem: PhotosPickerItem?
    @State private var importFromFiles = false
    @State private var showShare = false
    @State private var isImporting = false
    @State private var showExportHistory = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(PRTheme.border)
            HStack(spacing: 19) {
                ForEach(WorkspaceMode.allCases, id: \.self) { section in
                    Button {
                        project.videoPlayer?.pause()
                        mode = section
                    } label: {
                        VStack(spacing: 8) {
                            Text(section.rawValue)
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .tracking(1.6)
                                .foregroundStyle(mode == section ? .white : PRTheme.muted)
                            Rectangle()
                                .fill(mode == section ? PRTheme.accent : .clear)
                                .frame(height: 2)
                        }
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Text("v1.0")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(PRTheme.muted)
                    .padding(.bottom, 8)
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            Divider().overlay(PRTheme.border)

            Group {
                switch mode {
                case .photo: PhotoEditorView()
                case .video: VideoEditorView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider().overlay(PRTheme.border)
            bottomBar
        }
        .background(PRTheme.background.ignoresSafeArea())
        .fileImporter(isPresented: $importFromFiles,
                      allowedContentTypes: mode == .photo ? [.image] : [.movie, .video],
                      allowsMultipleSelection: false) { result in
            guard case let .success(urls) = result, let url = urls.first else {
                if case let .failure(error) = result { project.errorMessage = error.localizedDescription }
                return
            }
            Task { await importFile(url) }
        }
        .onChange(of: photoItem) { _, newItem in
            guard let newItem else { return }
            Task { await importPhoto(newItem) }
        }
        .onChange(of: videoItem) { _, newItem in
            guard let newItem else { return }
            Task { await importVideo(newItem) }
        }
        .alert("Ошибка PR", isPresented: Binding(get: { project.errorMessage != nil },
                                             set: { if !$0 { project.errorMessage = nil } })) {
            Button("Закрыть", role: .cancel) { project.errorMessage = nil }
        } message: {
            Text(project.errorMessage ?? "")
        }
        .sheet(isPresented: $showExportHistory) {
            NavigationStack {
                ExportHistoryView()
                    .navigationTitle("Экспорт")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .topBarTrailing) {
                        Button("Готово") { showExportHistory = false }
                    } }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var header: some View {
        HStack(spacing: 11) {
            Text("PR")
                .font(.system(size: 23, weight: .light, design: .rounded))
                .tracking(-1.7)
                .foregroundStyle(.white)
            Rectangle().fill(PRTheme.border).frame(width: 1, height: 22)
            Text("EDITOR")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .tracking(2)
                .foregroundStyle(PRTheme.muted)
            Spacer()
            AeroButton(symbol: "folder", title: "Файл") { importFromFiles = true }
            if mode == .photo {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    photoLibraryButton
                }
                .buttonStyle(.plain)
            } else {
                PhotosPicker(selection: $videoItem, matching: .videos) {
                    photoLibraryButton
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 10)
    }

    private var photoLibraryButton: some View {
        Image(systemName: "photo.on.rectangle.angled")
            .font(.system(size: 16, weight: .regular))
            .foregroundStyle(PRTheme.accent)
            .frame(width: 38, height: 37)
            .background(PRTheme.panelLight.opacity(0.55), in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(PRTheme.border))
            .accessibilityLabel("Выбрать из Фото")
    }

    private var bottomBar: some View {
        HStack(spacing: 10) {
            if isImporting {
                ProgressView().controlSize(.mini)
                Text("ИМПОРТ...").font(.system(size: 10, design: .monospaced))
            } else {
                Circle().fill(project.exportURL == nil ? PRTheme.muted : Color.green.opacity(0.8))
                    .frame(width: 5, height: 5)
                Text(project.exportURL == nil ? "ГОТОВ К РАБОТЕ" : "ЭКСПОРТ ГОТОВ")
                    .font(.system(size: 10, design: .monospaced))
            }
            Spacer()
            if let url = project.exportURL {
                ShareLink(item: url) {
                    Label("Поделиться", systemImage: "square.and.arrow.up")
                        .font(.system(size: 12))
                }
                .foregroundStyle(PRTheme.accent)
            }
            Button { showExportHistory = true } label: {
                Image(systemName: "tray.full")
                    .font(.system(size: 13))
                    .foregroundStyle(PRTheme.muted)
            }
            .accessibilityLabel("История экспортов")
        }
        .foregroundStyle(PRTheme.muted)
        .padding(.horizontal, 17)
        .frame(height: 43)
        .background(PRTheme.panel.opacity(0.6))
    }

    @MainActor
    private func importPhoto(_ item: PhotosPickerItem) async {
        isImporting = true
        defer { isImporting = false }
        do {
            guard let bytes = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: bytes) else { throw EditorError.invalidImage }
            project.loadPhoto(image)
        } catch { project.errorMessage = error.localizedDescription }
        photoItem = nil
    }

    @MainActor
    private func importVideo(_ item: PhotosPickerItem) async {
        isImporting = true
        defer { isImporting = false }
        do {
            guard let video = try await item.loadTransferable(type: ImportedVideo.self) else {
                throw EditorError.noVideoTrack
            }
            try await project.loadLocalVideo(video.url)
        } catch { project.errorMessage = error.localizedDescription }
        videoItem = nil
    }

    @MainActor
    private func importFile(_ url: URL) async {
        isImporting = true
        defer { isImporting = false }
        do {
            switch mode {
            case .photo: project.loadPhoto(try EditorFiles.imageFromFile(url))
            case .video: try await project.loadVideo(url)
            }
        } catch { project.errorMessage = error.localizedDescription }
    }
}

struct ExportHistoryView: View {
    var files: [URL] {
        ((try? FileManager.default.contentsOfDirectory(at: EditorFiles.exportDirectory(),
                                                       includingPropertiesForKeys: [.creationDateKey])) ?? [])
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    var body: some View {
        List {
            if files.isEmpty {
                ContentUnavailableView("Пока нет экспортов", systemImage: "tray")
            } else {
                ForEach(files, id: \.self) { url in
                    ShareLink(item: url) {
                        Label(url.lastPathComponent, systemImage: url.pathExtension == "mp4" ? "film" : "photo")
                            .font(.system(size: 12))
                            .lineLimit(1)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(PRTheme.background)
    }
}

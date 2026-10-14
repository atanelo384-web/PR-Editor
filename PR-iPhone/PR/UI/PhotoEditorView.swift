import SwiftUI

private enum PhotoTool: String, CaseIterable {
    case color = "Тон"
    case crop = "Кадр"
    case looks = "Фильтр"
    case text = "Текст"
}

struct PhotoEditorView: View {
    @EnvironmentObject private var project: EditorProject
    @State private var tool: PhotoTool = .color
    @State private var isExporting = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Rectangle().fill(Color(red: 0.065, green: 0.073, blue: 0.083))
                if let preview = project.photoPreview {
                    Image(uiImage: preview)
                        .resizable()
                        .scaledToFit()
                        .padding(14)
                        .shadow(color: .black.opacity(0.44), radius: 13, y: 6)
                } else {
                    BlankWorkspace(symbol: "photo.artframe", message: "Новое изображение",
                                   detail: "Откройте фото из медиатеки или через «Файл»")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            Divider().overlay(PRTheme.border)

            HStack(spacing: 7) {
                AeroButton(symbol: "arrow.uturn.backward", title: "Отменить", isDisabled: !project.canUndo) {
                    project.undo()
                }
                AeroButton(symbol: "arrow.uturn.forward", title: "Повтор", isDisabled: !project.canRedo) {
                    project.redo()
                }
                Spacer(minLength: 0)
                AeroButton(symbol: "square.and.arrow.up", title: "JPEG", isDisabled: project.originalPhoto == nil || isExporting) {
                    isExporting = true
                    defer { isExporting = false }
                    do { try project.exportPhoto() }
                    catch { project.errorMessage = error.localizedDescription }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            HStack(spacing: 5) {
                ForEach(PhotoTool.allCases, id: \.self) { option in
                    EditorChip(title: option.rawValue, selected: tool == option) { tool = option }
                }
                Spacer(minLength: 0)
                Button("Сброс") { project.resetPhoto() }
                    .font(.system(size: 11))
                    .foregroundStyle(PRTheme.muted)
                    .disabled(project.originalPhoto == nil)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 11)

            ScrollView {
                VStack(alignment: .leading, spacing: 13) {
                    switch tool {
                    case .color: colorControls
                    case .crop: cropControls
                    case .looks: lookControls
                    case .text: textControls
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 26)
            }
            .frame(height: 186)
            .background(PRTheme.panel.opacity(0.54))
            .disabled(project.originalPhoto == nil)
        }
    }

    private var colorControls: some View {
        Group {
            EditorSectionHeading(title: "Коррекция")
            EditorSlider(label: "Экспозиция", value: Binding(get: { project.photoState.exposure },
                                                            set: { project.photoState.exposure = $0 }),
                         range: -2...2, format: "%+.2f", onEditingChanged: editSlider)
            EditorSlider(label: "Контраст", value: Binding(get: { project.photoState.contrast },
                                                          set: { project.photoState.contrast = $0 }),
                         range: 0.3...2.2, onEditingChanged: editSlider)
            EditorSlider(label: "Насыщенность", value: Binding(get: { project.photoState.saturation },
                                                               set: { project.photoState.saturation = $0 }),
                         range: 0...2.2, onEditingChanged: editSlider)
        }
    }

    private func editSlider(_ editing: Bool) {
        if editing { project.beginContinuousEdit() }
        else { project.endContinuousEdit() }
    }

    private var cropControls: some View {
        Group {
            EditorSectionHeading(title: "Пропорции и ориентация")
            HStack(spacing: 6) {
                ForEach(CropMode.allCases) { option in
                    EditorChip(title: option.rawValue, selected: project.photoState.crop == option) {
                        project.editPhoto { $0.crop = option }
                    }
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 7) {
                AeroButton(symbol: "rotate.left", title: "−90°") { project.editPhoto { $0.rotation -= 1 } }
                AeroButton(symbol: "rotate.right", title: "+90°") { project.editPhoto { $0.rotation += 1 } }
                AeroButton(symbol: "flip.horizontal", title: "Зеркало") { project.editPhoto { $0.mirrored.toggle() } }
                Spacer(minLength: 0)
            }
            Text("Обрезка выполняется по центру снимка без потери исходника.")
                .font(.system(size: 11)).foregroundStyle(PRTheme.muted)
        }
    }

    private var lookControls: some View {
        Group {
            EditorSectionHeading(title: "Цветовой профиль")
            HStack(spacing: 6) {
                ForEach(ImageLook.allCases) { look in
                    EditorChip(title: look.rawValue, selected: project.photoState.look == look) {
                        project.editPhoto { $0.look = look }
                    }
                }
                Spacer(minLength: 0)
            }
            Text("Фильтры работают поверх настроек цвета. Настройки можно отменять.")
                .font(.system(size: 11)).foregroundStyle(PRTheme.muted)
        }
    }

    private var textControls: some View {
        Group {
            EditorSectionHeading(title: "Текстовый слой")
            TextField("Введите подпись...", text: Binding(
                get: { project.photoState.textOverlay },
                set: { value in
                    if value.count <= 100 { project.photoState.textOverlay = value }
                }), onEditingChanged: editSlider)
                .font(.system(size: 13))
                .padding(11)
                .background(PRTheme.background, in: RoundedRectangle(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(PRTheme.border))
            HStack {
                Text("Белый текст, нижняя часть кадра")
                    .font(.system(size: 11)).foregroundStyle(PRTheme.muted)
                Spacer()
                AeroButton(symbol: "xmark", title: "Удалить") {
                    project.editPhoto { $0.textOverlay = "" }
                }
            }
        }
    }
}

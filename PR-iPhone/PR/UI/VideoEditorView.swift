import SwiftUI
import AVKit

struct VideoEditorView: View {
    @EnvironmentObject private var project: EditorProject

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Color.black
                if let player = project.videoPlayer {
                    VideoPlayer(player: player)
                        .onDisappear { player.pause() }
                } else {
                    BlankWorkspace(symbol: "film.stack", message: "Новый видеоклип",
                                   detail: "Выберите видео из медиатеки или через «Файл»")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            Divider().overlay(PRTheme.border)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 9) {
                    AeroButton(symbol: "playpause", title: "Пуск / пауза", isDisabled: project.videoURL == nil) {
                        project.togglePlayback()
                    }
                    Spacer()
                    Text("\(timecode(project.trimEnd - project.trimStart))")
                        .font(.system(size: 11, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(PRTheme.muted)
                }

                EditorSectionHeading(title: "Таймлайн · обрезка")
                timeline

                EditorSlider(label: "Начало", value: Binding(
                    get: { project.trimStart },
                    set: { value in
                        project.trimStart = min(max(0, value), project.trimEnd - 0.05)
                        project.seek(to: project.trimStart)
                    }), range: 0...max(0.01, project.trimEnd - 0.05), format: "%.1f сек")
                EditorSlider(label: "Конец", value: Binding(
                    get: { project.trimEnd },
                    set: { value in
                        project.trimEnd = min(project.videoDuration, max(project.trimStart + 0.05, value))
                    }), range: min(project.trimStart + 0.05, max(0.05, project.videoDuration))...max(0.05, project.videoDuration),
                    format: "%.1f сек")
                EditorSlider(label: "Громкость", value: Binding(
                    get: { project.volume },
                    set: { value in
                        project.volume = value
                        project.videoPlayer?.volume = Float(value)
                    }), range: 0...1, format: "%.0f%%", displayMultiplier: 100)

                HStack {
                    Text("MP4 · Исходная ориентация")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(PRTheme.muted)
                    Spacer()
                    if project.isExporting { ProgressView().controlSize(.small) }
                    AeroButton(symbol: "square.and.arrow.up", title: project.isExporting ? "Монтаж..." : "Экспорт MP4",
                               isDisabled: project.videoURL == nil || project.isExporting) {
                        Task { await project.exportVideo() }
                    }
                }
            }
            .padding(15)
            .background(PRTheme.panel.opacity(0.54))
            .disabled(project.videoURL == nil)
        }
    }

    private var timeline: some View {
        GeometryReader { geometry in
            let duration = max(0.001, project.videoDuration)
            let left = geometry.size.width * (project.trimStart / duration)
            let width = geometry.size.width * ((project.trimEnd - project.trimStart) / duration)
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(LinearGradient(colors: [PRTheme.panelLight, PRTheme.background],
                                         startPoint: .top, endPoint: .bottom))
                RoundedRectangle(cornerRadius: 2)
                    .fill(PRTheme.accent.opacity(0.40))
                    .frame(width: max(2, width))
                    .offset(x: left)
                Rectangle().fill(PRTheme.accent)
                    .frame(width: 3).offset(x: left)
                Rectangle().fill(PRTheme.accent)
                    .frame(width: 3).offset(x: max(0, left + width - 3))
            }
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(PRTheme.border, lineWidth: 1))
            .clipped()
        }
        .frame(height: 38)
        .accessibilityLabel("Выбранный фрагмент от \(timecode(project.trimStart)) до \(timecode(project.trimEnd))")
    }

    private func timecode(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "00:00" }
        let whole = Int(max(0, seconds))
        return String(format: "%02d:%02d", whole / 60, whole % 60)
    }
}

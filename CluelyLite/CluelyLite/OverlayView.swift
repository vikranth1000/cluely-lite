import SwiftUI
import AppKit
import Combine

final class OverlayController: ObservableObject {
    @Published var input: String = ""
    @Published var focusAsk: Bool = false
    @Published var response: String = ""
    @Published var isExpanded: Bool = false
    @Published var responsePanelVisible: Bool = false

    var requestCollapse: (() -> Void)?
    var requestExpand: ((Bool) -> Void)?
    var beginDrag: (() -> Void)?
    var updateDrag: ((CGSize, Bool) -> Void)?
    var adjustWidth: ((CGFloat, Bool) -> Void)?
    var presentResponsePanel: ((String) -> Void)?
    var hideResponsePanel: (() -> Void)?

    private let client = AgentClient()
    private let snapshotter = AccessibilitySnapshotter()
    private let actionPerformer = AccessibilityActionPerformer()
    private var submitTask: Task<Void, Never>?
    @Published private(set) var pendingTool: AgentClient.Tool?

    func submit() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }

        if let pending = pendingTool, trimmed.lowercased() == "confirm" {
            confirmPendingAction(pending)
            return
        }
        if trimmed.lowercased() == "cancel", pendingTool != nil {
            pendingTool = nil
            response = "Pending action cancelled."
            input = ""
            return
        }

        input = trimmed
        response = ""
        responsePanelVisible = false
        hideResponsePanel?()
        pendingTool = nil
        submitTask?.cancel()

        submitTask = Task { [weak self] in
            guard let self else { return }
            do {
                await MainActor.run {
                    NotificationCenter.default.post(name: .init("CluelyLiteProcessing"), object: nil)
                }

                var snapshotError: Error?
                let snapshot: [[String: Any]]
                do {
                    snapshot = try snapshotter.captureSnapshot()
                } catch {
                    snapshotError = error
                    snapshot = []
                }

                let result = try await client.send(instruction: trimmed, snapshot: snapshot.isEmpty ? nil : snapshot)
                await MainActor.run {
                    self.process(result: result, snapshotError: snapshotError)
                }

                if let tool = result.tool {
                    try await self.handle(tool: tool)
                }
            } catch is CancellationError {
                await MainActor.run {
                    NotificationCenter.default.post(name: .init("CluelyLiteProcessed"), object: nil)
                }
            } catch {
                await MainActor.run {
                    self.handleFailure(message: error.localizedDescription)
                }
            }
        }
    }

    deinit { submitTask?.cancel() }

    func openResponsePanel() {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }
        responsePanelVisible = true
        presentResponsePanel?(trimmed)
    }

    func closeResponsePanel() {
        responsePanelVisible = false
        hideResponsePanel?()
    }

    private func confirmPendingAction(_ tool: AgentClient.Tool) {
        input = ""
        response = "Confirming action..."
        submitTask?.cancel()
        submitTask = Task { [weak self] in
            guard let self else { return }
            do {
                try actionPerformer.perform(tool: tool, confirm: true)
                await MainActor.run {
                    self.response = "Action executed."
                    self.pendingTool = nil
                    self.submitTask = nil
                    self.openResponsePanel()
                }
            } catch {
                await MainActor.run {
                    self.handleFailure(message: error.localizedDescription)
                }
            }
        }
    }

    private func process(result: AgentClient.Result, snapshotError: Error?) {
        var message = result.message
        if let snapshotError {
            message = friendlySnapshotMessage(base: message, error: snapshotError)
        }
        response = message
        pendingTool = nil
        submitTask = nil
        openResponsePanel()
        NotificationCenter.default.post(name: .init("CluelyLiteProcessed"), object: nil)
    }

    private func handleFailure(message: String) {
        response = "Error: \(message)"
        submitTask = nil
        openResponsePanel()
        NotificationCenter.default.post(name: .init("CluelyLiteProcessed"), object: nil)
    }

    private func friendlySnapshotMessage(base: String, error: Error) -> String {
        guard let snapshotError = error as? AccessibilitySnapshotter.SnapshotError else { return base }
        switch snapshotError {
        case .accessibilityDisabled:
            return base + "\nGrant Cluely-Lite accessibility access in System Settings > Privacy & Security > Accessibility."
        case .focusedAppUnavailable:
            return base + "\nI could not determine which app is active. Bring the window you care about to the front and try again."
        case .windowUnavailable:
            return base + "\nI could not find the focused window. Click the target app and try again."
        }
    }

    private func handle(tool: AgentClient.Tool) async throws {
        do {
            try actionPerformer.perform(tool: tool, confirm: false)
        } catch let error as AccessibilityActionPerformer.ActionError {
            await MainActor.run {
                self.response = error.localizedDescription
                if case .confirmationRequired = error {
                    self.pendingTool = tool
                }
                self.openResponsePanel()
            }
        }
    }
}

struct OverlayView: View {
    @ObservedObject var controller: OverlayController
    @FocusState private var isFocused: Bool
    @State private var isProcessing = false
    @State private var dragInProgress = false
    @State private var resizeInProgress = false

    init(controller: OverlayController) {
        self.controller = controller
    }

    var body: some View {
        pill
            .onChange(of: controller.input) { _ in isProcessing = false }
            .onReceive(NotificationCenter.default.publisher(for: .init("CluelyLiteProcessing"))) { _ in isProcessing = true }
            .onReceive(NotificationCenter.default.publisher(for: .init("CluelyLiteProcessed"))) { _ in isProcessing = false }
    }

    private var pill: some View {
        let corner = controller.isExpanded ? 22.0 : 18.0
        return HStack(spacing: controller.isExpanded ? 12 : 10) {
            dragHandle

            if controller.isExpanded {
                expandedContent
                sendButton
            } else {
                collapsedContent
            }

            resizeHandle
        }
        .padding(.horizontal, controller.isExpanded ? 18 : 14)
        .padding(.vertical, controller.isExpanded ? 12 : 8)
        .frame(minHeight: controller.isExpanded ? 60 : 32)
        .background(pillBackground(cornerRadius: corner))
        .contentShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .onTapGesture {
            guard controller.isExpanded == false else { return }
            controller.requestExpand?(true)
        }
    }

    private var dragHandle: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: controller.isExpanded ? 16 : 14, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.vertical, controller.isExpanded ? 6 : 4)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2, coordinateSpace: .global)
                    .onChanged { value in
                        if dragInProgress == false {
                            dragInProgress = true
                            controller.beginDrag?()
                        }
                        controller.updateDrag?(value.translation, false)
                    }
                    .onEnded { value in
                        controller.updateDrag?(value.translation, true)
                        dragInProgress = false
                    }
            )
            .accessibilityLabel("Drag to move overlay")
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: controller.pendingTool != nil ? 6 : 8) {
            TextField("Ask about your screen...", text: $controller.input, prompt: Text("Ask about your screen..."))
                .textFieldStyle(.plain)
                .focused($isFocused)
                .onChange(of: controller.focusAsk) { newValue in
                    if newValue {
                        DispatchQueue.main.async {
                            isFocused = true
                            controller.focusAsk = false
                        }
                    }
                }
                .onSubmit { submitIfNeeded() }
                .font(.system(size: 15))
                .padding(.vertical, 6)

            if controller.pendingTool != nil {
                Text("Pending action detected — type 'confirm' or 'cancel'.")
                    .font(.caption2)
                    .foregroundColor(.orange)
            } else if controller.responsePanelVisible {
                Text("Response shown below. Press Esc to close it when you are finished.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                Text("Press Return to send. Press Esc to collapse.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var collapsedContent: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Cluely-Lite ready")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("Press Ask or ⌘+\\ to expand")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 8)
            collapsedButtons
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var collapsedButtons: some View {
        HStack(spacing: 8) {
            Button {
                controller.requestExpand?(true)
            } label: {
                Label("Ask", systemImage: "paperplane.fill")
                    .symbolRenderingMode(.hierarchical)
                    .labelStyle(.titleAndIcon)
                    .font(.caption)
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)

            if controller.responsePanelVisible {
                Button {
                    controller.closeResponsePanel()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(6)
                        .background(Color.black.opacity(0.25), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Close response transcript")
            } else if controller.response.isEmpty == false {
                Button {
                    controller.openResponsePanel()
                } label: {
                    Label("View", systemImage: "doc.text.magnifyingglass")
                        .labelStyle(.titleAndIcon)
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var sendButton: some View {
        Button(action: submitIfNeeded) {
            if isProcessing {
                ProgressView().scaleEffect(0.85)
            } else {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.accentColor)
            }
        }
        .buttonStyle(.plain)
        .disabled(controller.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
        .keyboardShortcut(.return, modifiers: [])
        .accessibilityLabel("Send request")
    }

    private var resizeHandle: some View {
        VStack(spacing: 4) {
            Capsule().fill(Color.secondary.opacity(0.45)).frame(width: 3, height: controller.isExpanded ? 18 : 12)
            Capsule().fill(Color.secondary.opacity(0.25)).frame(width: 3, height: controller.isExpanded ? 18 : 12)
        }
        .padding(.vertical, controller.isExpanded ? 4 : 2)
        .padding(.leading, 6)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .global)
                .onChanged { value in
                    if resizeInProgress == false {
                        resizeInProgress = true
                    }
                    controller.adjustWidth?(value.translation.width, false)
                }
                .onEnded { value in
                    controller.adjustWidth?(value.translation.width, true)
                    resizeInProgress = false
                }
        )
        .accessibilityLabel("Resize overlay width")
    }

    private func pillBackground(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: controller.isExpanded ? 1.2 : 0.8)
            )
            .shadow(color: Color.black.opacity(controller.isExpanded ? 0.22 : 0.15), radius: controller.isExpanded ? 18 : 12, y: 6)
            .opacity(controller.isExpanded ? 0.96 : 0.84)
    }

    private func submitIfNeeded() {
        let trimmed = controller.input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }
        controller.submit()
    }
}

struct OverlayButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.primary)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.2 : 0.1))
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct OverlayTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                    )
            )
            .font(.system(size: 14))
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

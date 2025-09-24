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
    var adjustWidth: ((CGFloat, Bool) -> Void)?
    var presentResponsePanel: ((String) -> Void)?
    var hideResponsePanel: (() -> Void)?

    private let client = AgentClient()
    private let snapshotter = AccessibilitySnapshotter()
    private let actionPerformer = AccessibilityActionPerformer()
    private var submitTask: Task<Void, Never>?
    @Published private(set) var pendingTool: AgentClient.Tool?

    func submit() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false else { return }

        if let pending = pendingTool, text.lowercased() == "confirm" {
            confirmPendingAction(pending)
            return
        }

        if text.lowercased() == "cancel", pendingTool != nil {
            pendingTool = nil
            response = "Pending action cancelled."
            input = ""
            return
        }

        input = text
        response = ""
        responsePanelVisible = false
        hideResponsePanel?()
        pendingTool = nil
        submitTask?.cancel()

        submitTask = Task {
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

                let result = try await client.send(instruction: text, snapshot: snapshot.isEmpty ? nil : snapshot)
                await MainActor.run {
                    self.processResult(result, snapshotError: snapshotError)
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

    deinit {
        submitTask?.cancel()
    }

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
        submitTask = Task {
            do {
                try self.actionPerformer.perform(tool: tool, confirm: true)
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

    private func processResult(_ result: AgentClient.Result, snapshotError: Error?) {
        var message = result.message
        if let snapshotError = snapshotError {
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
        guard let snapshotError = error as? AccessibilitySnapshotter.SnapshotError else {
            return base
        }
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
            } else {
                collapsedContent
            }

            if controller.isExpanded {
                sendButton
                resizeHandle
            } else if !controller.response.isEmpty {
                Button {
                    controller.openResponsePanel()
                } label: {
                    Image(systemName: "text.justify.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.accentColor.opacity(0.9))
                }
                .buttonStyle(.plain)
                .help("Show full response")
                resizeHandle
            } else {
                resizeHandle
            }
        }
        .padding(.horizontal, controller.isExpanded ? 18 : 14)
        .padding(.vertical, controller.isExpanded ? 14 : 8)
        .frame(minHeight: controller.isExpanded ? 60 : 32)
        .background(pillBackground(cornerRadius: corner))
        .contentShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .overlay(alignment: .topTrailing) { expandedCloseButton }
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
            .padding(.trailing, 4)
            .padding(.leading, 2)
            .accessibilityLabel("Drag to move overlay")
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: controller.pendingTool != nil ? 6 : 2) {
            HStack(alignment: .top, spacing: 8) {
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

                Button {
                    controller.closeResponsePanel()
                    controller.requestCollapse?()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(6)
                        .background(Color.black.opacity(0.28), in: Circle())
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }

            if controller.pendingTool != nil {
                Text("Pending action detected — type 'confirm' or 'cancel'.")
                    .font(.caption2)
                    .foregroundColor(.orange)
            } else if controller.responsePanelVisible {
                Text("Response displayed below. Close it when you’re done.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var collapsedContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(controller.response.isEmpty ? "Cluely-Lite ready" : controller.response)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)

            if controller.response.isEmpty {
                Text("Hover or press ⌘↩ to open")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else if !controller.responsePanelVisible {
                Text("Tap to reopen the response")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onTapGesture {
            if controller.response.isEmpty {
                controller.requestExpand?(true)
            } else {
                controller.openResponsePanel()
            }
        }
    }

    private var sendButton: some View {
        Button(action: submitIfNeeded) {
            if isProcessing {
                ProgressView()
                    .scaleEffect(0.85)
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
        VStack(spacing: 3) {
            Capsule().fill(Color.secondary.opacity(0.4)).frame(width: 3, height: 10)
            Capsule().fill(Color.secondary.opacity(0.25)).frame(width: 3, height: 10)
        }
        .padding(.vertical, controller.isExpanded ? 4 : 2)
        .padding(.leading, 6)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { controller.adjustWidth?($0.translation.width, false) }
                .onEnded { controller.adjustWidth?($0.translation.width, true) }
        )
        .accessibilityLabel("Resize overlay")
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

    private var expandedCloseButton: some View {
        Group {
            if controller.isExpanded == false && controller.responsePanelVisible {
                Button {
                    controller.closeResponsePanel()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(6)
                        .background(Color.black.opacity(0.28), in: Circle())
                }
                .buttonStyle(.plain)
                .offset(x: -6, y: 6)
            }
        }
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

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
    var presentResponsePanel: ((String) -> Void)?
    var hideResponsePanel: (() -> Void)?

    private let client = AgentClient()
    private let snapshotter = AccessibilitySnapshotter()
    private let actionPerformer = AccessibilityActionPerformer()
    private var submitTask: Task<Void, Never>?
    @Published private(set) var pendingTool: AgentClient.Tool?

    func submit() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

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
                // Notify UI that processing has started
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
                    let baseMessage = result.message.isEmpty ? "Agent completed request." : result.message
                    if let snapshotError = snapshotError {
                        self.response = baseMessage + " (snapshot unavailable: \(snapshotError.localizedDescription))"
                    } else {
                        self.response = baseMessage
                    }
                    self.pendingTool = nil
                    self.submitTask = nil
                    self.responsePanelVisible = true
                    self.presentResponsePanel?(self.response)
                    
                    // Notify UI that processing is complete
                    NotificationCenter.default.post(name: .init("CluelyLiteProcessed"), object: nil)
                }
                if let tool = result.tool {
                    try await self.handle(tool: tool)
                }
            } catch is CancellationError {
                // Ignore cancellation when a newer submit has started.
                await MainActor.run {
                    NotificationCenter.default.post(name: .init("CluelyLiteProcessed"), object: nil)
                }
            } catch {
                await MainActor.run {
                    self.response = "Error: \(error.localizedDescription)"
                    self.submitTask = nil
                    self.responsePanelVisible = true
                    self.presentResponsePanel?(self.response)
                    NotificationCenter.default.post(name: .init("CluelyLiteProcessed"), object: nil)
                }
            }
        }
    }

    deinit {
        submitTask?.cancel()
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
                    self.responsePanelVisible = true
                    self.presentResponsePanel?(self.response)
                }
            } catch {
                await MainActor.run {
                    self.response = "Action failed: \(error.localizedDescription)"
                    self.submitTask = nil
                    self.responsePanelVisible = true
                    self.presentResponsePanel?(self.response)
                }
            }
        }
    }

    func openResponsePanel() {
        guard !response.isEmpty else { return }
        responsePanelVisible = true
        presentResponsePanel?(response)
    }

    func closeResponsePanel() {
        responsePanelVisible = false
        hideResponsePanel?()
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
            .onChange(of: controller.input) { _ in
                isProcessing = false
            }
            .onReceive(NotificationCenter.default.publisher(for: .init("CluelyLiteProcessing"))) { _ in
                isProcessing = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .init("CluelyLiteProcessed"))) { _ in
                isProcessing = false
            }
    }

    private var pill: some View {
        let corner = controller.isExpanded ? 22.0 : 18.0
        return HStack(spacing: controller.isExpanded ? 12 : 8) {
            Image(systemName: controller.isExpanded ? "bubble.left.and.text.bubble.fill" : "sparkles")
                .font(.system(size: controller.isExpanded ? 18 : 14, weight: .semibold))
                .foregroundStyle(Color.accentColor.opacity(controller.isExpanded ? 1 : 0.9))

            if controller.isExpanded {
                VStack(alignment: .leading, spacing: controller.pendingTool != nil ? 4 : 0) {
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
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                collapsedLabel
            }

            if controller.isExpanded {
                Button(action: submitIfNeeded) {
                    if isProcessing {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.accentColor)
                    }
                }
                .buttonStyle(.plain)
                .disabled(controller.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
                .keyboardShortcut(.return, modifiers: [])
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
            }
        }
        .padding(.horizontal, controller.isExpanded ? 18 : 14)
        .padding(.vertical, controller.isExpanded ? 12 : 6)
        .frame(minHeight: controller.isExpanded ? 56 : 28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(pillBackground(cornerRadius: corner))
        .overlay(alignment: .topTrailing) { closeButton }
        .contentShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .onTapGesture {
            guard !controller.isExpanded else { return }
            controller.requestExpand?(true)
        }
    }

    private var collapsedLabel: some View {
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

    private func pillBackground(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: controller.isExpanded ? 1.2 : 0.8)
            )
            .shadow(color: Color.black.opacity(controller.isExpanded ? 0.22 : 0.15), radius: controller.isExpanded ? 18 : 12, y: 6)
            .opacity(controller.isExpanded ? 0.95 : 0.82)
    }

    private var closeButton: some View {
        Group {
            if controller.isExpanded {
                Button {
                    controller.closeResponsePanel()
                    controller.requestCollapse?()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
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
        guard !trimmed.isEmpty else { return }
        controller.submit()
    }

}// Custom button style for overlay
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

// Custom text field style for overlay
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

// macOS visual effect wrapper
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blendingMode
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
//
//  OverlayView.swift
//  CluelyLite
//
//  Created by Vikranth Reddimasu on 9/23/25.
//

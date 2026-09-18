import SwiftUI
import UIKit
import AVFoundation
import Security

struct ContentView: View {
    @StateObject private var camera = RearCameraModel()
    @State private var showCamera = true
    @State private var showLicense = false
    @State private var checkingLicense = false
    @State private var licenseMessage = ""
    @State private var livePhotoEnabled = false
    @State private var nightModeEnabled = false
    @State private var flashMode = 0
    @State private var advancedPanelVisible = false
    @State private var isVideoMode = false
    @State private var selectedZoom: CGFloat = 1.5
    @State private var toast: String?
    @State private var isShutterPressed = false
    @State private var focusPoint: CGPoint?

    private let zooms: [CGFloat] = [0.5, 1.5, 2.0, 3.0]

    var body: some View {
        Group { if showCamera { cameraScreen } else { AppHomeView() } }
            .preferredColorScheme(.dark)
    }

    private var cameraScreen: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / 1170
            let topHeight = 360 * scale
            let bottomHeight = 720 * scale
            ZStack {
                Color.black.ignoresSafeArea()
                CameraPreview(session: camera.session, focusPoint: $focusPoint)
                    .ignoresSafeArea()
                    .overlay(alignment: .top) { Color.black.frame(height: topHeight) }
                    .overlay(alignment: .bottom) { Color.black.frame(height: bottomHeight) }

                VStack(spacing: 0) {
                    topControls(scale: scale)
                        .frame(height: topHeight)
                    Spacer(minLength: 0)
                    bottomControls(scale: scale, height: bottomHeight)
                        .frame(height: bottomHeight)
                }

                if let focusPoint {
                    FocusReticle(point: focusPoint)
                        .transition(.opacity)
                        .zIndex(50)
                }
                if let toast {
                    Text(toast)
                        .font(.system(size: 21 * scale, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20 * scale)
                        .padding(.vertical, 11 * scale)
                        .background(.black.opacity(0.62), in: Capsule())
                        .position(x: proxy.size.width / 2, y: 385 * scale)
                        .transition(.opacity)
                        .zIndex(60)
                }
                if showLicense {
                    LicenseGateView(isLoading: checkingLicense, message: $licenseMessage,
                                    onCancel: { showLicense = false }, onActivate: activateLicense)
                        .transition(.opacity).zIndex(100)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
    }

    private func topControls(scale: CGFloat) -> some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 145 * scale)
            HStack(spacing: 25 * scale) {
                CameraTopButton(symbol: nightModeEnabled ? "moon.fill" : "moon", active: nightModeEnabled) { toggleNight() }
                CameraTopButton(symbol: flashMode == 0 ? "bolt.slash" : "bolt.fill", active: flashMode != 0) { toggleFlash() }
                CameraTopButton(symbol: livePhotoEnabled ? "livephoto" : "livephoto.slash", active: livePhotoEnabled) { toggleLive() }
                CameraTopButton(symbol: "circle.grid.3x3.fill", active: false) { toggleAdvanced() }
            }
            .padding(.horizontal, 25 * scale)
            .frame(height: 92 * scale)
            .background(Color(white: 0.15), in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1.5 * scale))
            .padding(.horizontal, 30 * scale)
            Spacer()
        }
    }

    private func bottomControls(scale: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 0) {
            if advancedPanelVisible {
                AdvancedCameraPanel(scale: scale, onClose: toggleAdvanced)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                zoomPicker(scale: scale).frame(height: 120 * scale)
            }
            Spacer(minLength: 0)
            HStack(alignment: .center) {
                GalleryThumbnail(image: camera.lastPhoto)
                    .frame(width: 120 * scale, height: 120 * scale)
                Spacer()
                Button(action: capture) {
                    Circle()
                        .fill(isVideoMode ? Color.red : Color.white)
                        .frame(width: 176 * scale, height: 176 * scale)
                        .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 8 * scale))
                        .scaleEffect(isShutterPressed ? 0.86 : 1)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isVideoMode ? "Gravar vídeo" : "Tirar foto")
                Spacer()
                Button(action: {}) { Image(systemName: "camera.rotate").font(.system(size: 43 * scale, weight: .medium)).foregroundStyle(.white) }
                    .frame(width: 120 * scale, height: 120 * scale)
            }
            .padding(.horizontal, 80 * scale)
            .frame(height: 260 * scale)
            modePicker(scale: scale)
                .frame(height: 130 * scale)
        }
        .padding(.top, 15 * scale)
        .background(Color.black)
    }

    private func zoomPicker(scale: CGFloat) -> some View {
        HStack(spacing: 16 * scale) {
            ForEach(zooms) { value in
                Button { selectZoom(value) } label: {
                    Text(value == 0.5 ? "0,5" : value == 1.5 ? "1,5x" : value == 2 ? "2" : "3")
                        .font(.system(size: 28 * scale, weight: .semibold))
                        .foregroundStyle(selectedZoom == value ? .yellow : .white)
                        .frame(width: 86 * scale, height: 86 * scale)
                        .background(selectedZoom == value ? .white.opacity(0.16) : .clear, in: Circle())
                }.buttonStyle(.plain)
            }
        }
    }

    private func modePicker(scale: CGFloat) -> some View {
        HStack(spacing: 0) {
            Button { withAnimation(.easeInOut(duration: 0.35)) { isVideoMode = true } } label: { Text("VÍDEO") }
            Button { withAnimation(.easeInOut(duration: 0.35)) { isVideoMode = false } } label: { Text("FOTO") }
        }
        .font(.system(size: 30 * scale, weight: .bold))
        .foregroundStyle(.white)
        .frame(width: 470 * scale, height: 90 * scale)
        .background(.white.opacity(0.08), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.35), lineWidth: 2 * scale))
        .overlay(alignment: isVideoMode ? .leading : .trailing) { Capsule().fill(.white.opacity(0.11)).frame(width: 235 * scale, height: 86 * scale) }
    }

    private func toggleNight() { nightModeEnabled.toggle(); showToast(nightModeEnabled ? "MODO NOITE AUTOMÁTICO" : "MODO NOITE DESATIVADO") }
    private func toggleFlash() { flashMode = flashMode == 0 ? 1 : 0; showToast(flashMode == 1 ? "FLASH AUTOMÁTICO" : "FLASH DESATIVADO") }
    private func toggleLive() { livePhotoEnabled.toggle(); showToast(livePhotoEnabled ? "LIVE" : "LIVE DESATIVADO") }
    private func toggleAdvanced() { withAnimation(.easeInOut(duration: 0.3)) { advancedPanelVisible.toggle() } }
    private func selectZoom(_ value: CGFloat) { selectedZoom = value; camera.setZoom(value); showToast(value == 0.5 ? "13 mm" : value == 1.5 ? "35 mm" : value == 2 ? "2x" : "3x") }
    private func capture() {
        if isVideoMode { showToast("VÍDEO") ; return }
        withAnimation(.easeOut(duration: 0.08)) { isShutterPressed = true }
        camera.capturePhoto()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { withAnimation { isShutterPressed = false } }
    }
    private func showToast(_ message: String) {
        withAnimation(.easeOut(duration: 0.15)) { toast = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { withAnimation(.easeOut(duration: 0.25)) { toast = nil } }
    }
    private func activateLicense(key: String) {
        checkingLicense = true
        Task { do { _ = try await LicenseService.shared.activate(key: key); await MainActor.run { checkingLicense = false; showLicense = false; camera.stop(); showCamera = false } } catch { await MainActor.run { checkingLicense = false; licenseMessage = error.localizedDescription } } }
    }
    private func handleFlashTap() { toggleFlash() }
    private func bundleImage(named name: String) -> Image {
        guard let path = Bundle.main.path(forResource: name, ofType: "png"), let image = UIImage(contentsOfFile: path) else { return Image(systemName: "rectangle.fill") }
        return Image(uiImage: image)
    }
}

private struct CameraTopButton: View {
    let symbol: String
    let active: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: 36, weight: .medium)).foregroundStyle(active ? .yellow : .white).frame(width: 64, height: 64).contentShape(Rectangle()) }
            .buttonStyle(.plain)
    }
}

private struct FocusReticle: View {
    let point: CGPoint
    var body: some View { RoundedRectangle(cornerRadius: 3).stroke(.yellow, lineWidth: 2).frame(width: 90, height: 90).position(point).overlay(Image(systemName: "sun.max.fill").foregroundStyle(.yellow).position(x: point.x + 55, y: point.y - 35)) }
}

private struct GalleryThumbnail: View {
    let image: UIImage?
    var body: some View { Group { if let image { Image(uiImage: image).resizable().scaledToFill() } else { Color.white.opacity(0.08) } }.clipShape(RoundedRectangle(cornerRadius: 12)) }
}

private struct AdvancedCameraPanel: View {
    let scale: CGFloat
    let onClose: () -> Void
    private let items = [("bolt.fill", "Flash"), ("livephoto", "Live"), ("timer", "Timer"), ("plusminus", "Exposição"), ("camera.aperture", "Estilos"), ("camera.filters", "Filtros"), ("rectangle", "Proporção"), ("moon.fill", "Noite")]
    var body: some View {
        VStack(spacing: 14 * scale) {
            HStack(spacing: 10 * scale) { ForEach(0..<4) { index in CameraPanelItem(symbol: items[index].0, label: items[index].1) } }
            HStack(spacing: 10 * scale) { ForEach(4..<8) { index in CameraPanelItem(symbol: items[index].0, label: items[index].1) } }
        }
        .padding(18 * scale)
        .background(Color(white: 0.14), in: RoundedRectangle(cornerRadius: 28 * scale))
        .overlay(RoundedRectangle(cornerRadius: 28 * scale).stroke(.white.opacity(0.16), lineWidth: 1.5 * scale))
        .padding(.horizontal, 20 * scale)
        .padding(.bottom, 300 * scale)
    }
}
private struct CameraPanelItem: View {
    let symbol: String
    let label: String
    var body: some View { VStack(spacing: 5) { Image(systemName: symbol).font(.system(size: 23, weight: .medium)); Text(label).font(.system(size: 10, weight: .medium)) }.foregroundStyle(.white).frame(maxWidth: .infinity) }
}

private struct LicenseGateView: View {
    let isLoading: Bool
    @Binding var message: String
    let onCancel: () -> Void
    let onActivate: (String) -> Void
    @State private var key = ""

    var body: some View {
        ZStack {
            Color.black.opacity(0.96).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "key.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.yellow)
                Text("Key necessária")
                    .font(.system(size: 26, weight: .bold))
                Text("Digite uma key de 1, 7 ou 30 dias para entrar no aplicativo.")
                    .font(.system(size: 15))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.7))
                TextField("3105-7D-...", text: $key)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 16)
                    .frame(height: 52)
                    .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.2)))
                if !message.isEmpty {
                    Text(message).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
                }
                Button {
                    guard key.trimmingCharacters(in: .whitespacesAndNewlines).count >= 8 else {
                        message = "Digite uma key válida."
                        return
                    }
                    message = ""
                    onActivate(key.trimmingCharacters(in: .whitespacesAndNewlines))
                } label: {
                    Group {
                        if isLoading { ProgressView().tint(.black) }
                        else { Text("Ativar key") }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                }
                .foregroundStyle(.black)
                .background(Color.yellow, in: RoundedRectangle(cornerRadius: 14))
                .disabled(isLoading)
                Button("Voltar para a câmera", action: onCancel)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(28)
            .frame(maxWidth: 430)
        }
    }
}

private enum LicenseError: LocalizedError {
    case invalidResponse
    case server(String)
    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Resposta inválida do servidor."
        case .server(let message): return message
        }
    }
}

private final class LicenseService {
    static let shared = LicenseService()
    // Public HTTPS endpoint of the online license-control service.
    private let baseURL = URL(string: "https://3000-iz7my112fal5cha1lykwv-f382c1ca.us1.manus.computer")!
    private let session = URLSession(configuration: .ephemeral)

    private let keychainService = "3105.license.identity"
    private lazy var deviceId: String = {
        if let stored = loadDeviceId() { return stored }
        let generated = "device-" + UUID().uuidString
        saveDeviceId(generated)
        return generated
    }()

    private func loadDeviceId() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "device-id",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func saveDeviceId(_ value: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "device-id",
            kSecValueData as String: Data(value.utf8)
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    func verify() async throws -> Bool {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/trpc/license.verify"), resolvingAgainstBaseURL: false)!
        let input = try JSONSerialization.data(withJSONObject: ["json": ["deviceId": deviceId]])
        components.queryItems = [URLQueryItem(name: "input", value: String(data: input, encoding: .utf8))]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try parseValid(data)
    }

    func activate(key: String) async throws -> Bool {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/trpc/license.activate"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "batch", value: "1")]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["0": ["json": ["key": key, "deviceId": deviceId]]])
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try parseValid(data)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw LicenseError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = ((object["error"] as? [String: Any])?["json"] as? [String: Any])?["message"] as? String {
                throw LicenseError.server(message)
            }
            throw LicenseError.server("Key inválida, expirada ou vinculada a outro aparelho.")
        }
    }

    private func parseValid(_ data: Data) throws -> Bool {
        let object = try JSONSerialization.jsonObject(with: data)
        let entries: [[String: Any]]
        if let dictionary = object as? [String: Any] { entries = [dictionary] }
        else if let array = object as? [[String: Any]] { entries = array }
        else { throw LicenseError.invalidResponse }
        for entry in entries {
            guard let result = entry["result"] as? [String: Any],
                  let payload = result["data"] as? [String: Any] else { continue }
            if let valid = payload["json"] as? Bool { return valid }
            if let json = payload["json"] as? [String: Any],
               let valid = json["valid"] as? Bool { return valid }
        }
        throw LicenseError.invalidResponse
    }
}

private final class RearCameraModel: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "3105.rear-camera")
    private let photoOutput = AVCapturePhotoOutput()
    private var device: AVCaptureDevice?
    private var configured = false
    @Published var lastPhoto: UIImage?
    func start() {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else { AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in if granted { self?.configureAndStart() } }; return }
        configureAndStart()
    }
    func stop() { queue.async { [weak self] in if self?.session.isRunning == true { self?.session.stopRunning() } } }
    private func configureAndStart() {
        queue.async { [weak self] in
            guard let self, !self.configured else { return }
            self.session.beginConfiguration(); self.session.sessionPreset = .photo
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back), let input = try? AVCaptureDeviceInput(device: device), self.session.canAddInput(input) else { self.session.commitConfiguration(); return }
            self.device = device; self.session.addInput(input)
            if self.session.canAddOutput(self.photoOutput) { self.session.addOutput(self.photoOutput) }
            self.configured = true; self.session.commitConfiguration(); self.session.startRunning()
        }
    }
    func setZoom(_ factor: CGFloat) {
        queue.async { [weak self] in guard let self, let device = self.device else { return }; do { try device.lockForConfiguration(); device.videoZoomFactor = min(max(factor, 1), device.activeFormat.videoMaxZoomFactor); device.unlockForConfiguration() } catch {} }
    }
    func capturePhoto() {
        queue.async { [weak self] in guard let self else { return }; self.photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self) }
    }
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil, let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else { return }
        DispatchQueue.main.async { self.lastPhoto = image }
    }
}

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    @Binding var focusPoint: CGPoint?
    func makeCoordinator() -> Coordinator { Coordinator(focusPoint: $focusPoint) }
    func makeUIView(context: Context) -> PreviewView { let view = PreviewView(); view.videoPreviewLayer.session = session; view.videoPreviewLayer.videoGravity = .resizeAspectFill; view.onTap = { point in context.coordinator.focus(at: point, in: view) }; return view }
    func updateUIView(_ view: PreviewView, context: Context) { view.videoPreviewLayer.session = session }
    final class Coordinator { @Binding var focusPoint: CGPoint?; init(focusPoint: Binding<CGPoint?>) { _focusPoint = focusPoint }; func focus(at point: CGPoint, in view: PreviewView) { focusPoint = point; view.onFocus?(point) } }
}
private final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    var onTap: ((CGPoint) -> Void)?
    var onFocus: ((CGPoint) -> Void)?
    override init(frame: CGRect) { super.init(frame: frame); addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))) }
    required init?(coder: NSCoder) { fatalError() }
    @objc private func tapped(_ recognizer: UITapGestureRecognizer) { onTap?(recognizer.location(in: self)) }
}

#Preview { ContentView() }



import SwiftUI
import UIKit

struct AppHomeView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var patchDraftCoordinator: PatchDraftCoordinator
    @EnvironmentObject private var patchStore: PatchProjectStore
    @EnvironmentObject private var repositoryStore: PackageRepositoryStore
    @AppStorage(FeatureVisibility.developerModeStorageKey)
    private var developerModeEnabled = false
    @State private var tabNavigation: AppTabNavigationState
    @State private var showSettings = false
    @State private var showLogs = false

    init() {
#if targetEnvironment(simulator)
        let arguments = ProcessInfo.processInfo.arguments
        let initialTab: Int
        if arguments.contains("--simulate-new-tab") {
            initialTab = 1
        } else if arguments.contains("--simulate-sources-tab") {
            initialTab = 2
        } else if arguments.contains("--simulate-installed-tab")
                    || arguments.contains("--simulate-patch-tab")
                    || arguments.contains("--simulate-wallpaper-tab") {
            initialTab = 3
        } else if arguments.contains("--simulate-files-tab") {
            initialTab = 4
        } else if arguments.contains("--simulate-search-tab") {
            initialTab = 5
        } else {
            initialTab = 0
        }
        _tabNavigation = State(initialValue: AppTabNavigationState(selectedTab: initialTab))
        _showSettings = State(
            initialValue: arguments.contains("--simulate-settings")
        )
#else
        _tabNavigation = State(initialValue: AppTabNavigationState())
#endif
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                regularLayout
            } else {
                compactLayout
            }
        }
        .tint(AppTheme.accent)
        .imageScale(.small)
        .preferredColorScheme(.dark)
        .onChange(of: patchDraftCoordinator.request?.id) { requestID in
            if requestID != nil { tabNavigation.select(AppSection.installed.rawValue) }
        }
        .onChange(of: patchDraftCoordinator.importRequest?.id) { requestID in
            if requestID != nil { tabNavigation.select(AppSection.installed.rawValue) }
        }
        .onChange(of: developerModeEnabled) { _ in
            tabNavigation.reconcileSelection(with: featureVisibility)
        }
        .onAppear {
            tabNavigation.reconcileSelection(with: featureVisibility)
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showLogs) { LogView() }
        .patchStorePresentation(patchStore)
        .repositoryStorePresentation(repositoryStore, patchStore: patchStore)
    }

    private var compactLayout: some View {
        TabView(selection: tabSelection) {
            ForEach(featureVisibility.visibleSections) { section in
                sectionContent(section)
                    .tabItem {
                        CompactTabLabel(
                            title: language.text(section.titleKey),
                            systemImage: section.systemImage
                        )
                    }
                    .tag(section.rawValue)
            }
        }
    }

    private var regularLayout: some View {
        NavigationSplitView {
            List {
                ForEach(featureVisibility.visibleSections) { section in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            tabNavigation.select(section.rawValue)
                        }
                    } label: {
                        Label(language.text(section.titleKey), systemImage: section.systemImage)
                            .fontWeight(section.rawValue == tabNavigation.selectedTab ? .semibold : .regular)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        section.rawValue == tabNavigation.selectedTab
                            ? AppTheme.accent.opacity(0.14)
                            : Color.clear
                    )
                    .accessibilityAddTraits(
                        section.rawValue == tabNavigation.selectedTab ? .isSelected : []
                    )
                }
            }
            .navigationTitle("3105")
            .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 300)
        } detail: {
            sectionContent(selectedVisibleSection)
                .id(selectedVisibleSection.rawValue)
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private func sectionContent(_ section: AppSection) -> some View {
        switch section {
        case .home:
            RepositoryHomeView(
                onOpenSettings: openSettings,
                onOpenLogs: openLogs,
                onOpenInject: { tabNavigation.select(AppSection.installed.rawValue) }
            )
        case .new:
            RepositoryNewView(
                onOpenSettings: openSettings,
                onOpenLogs: openLogs
            )
        case .sources:
            RepositorySourcesView(
                onOpenSettings: openSettings,
                onOpenLogs: openLogs
            )
        case .installed:
            PatchProjectsView(
                onOpenSettings: openSettings,
                onOpenLogs: openLogs
            )
        case .files:
            AppDataBrowserView(
                tabSession: filesTabSession,
                onOpenSettings: openSettings,
                onOpenLogs: openLogs
            )
        case .search:
            RepositorySearchView(
                onOpenSettings: openSettings,
                onOpenLogs: openLogs
            )
        }
    }

    private var tabSelection: Binding<Int> {
        Binding(
            get: { tabNavigation.selectedTab },
            set: { tabNavigation.select($0) }
        )
    }

    private var filesTabSession: Binding<FilesTabSession> {
        Binding(
            get: { tabNavigation.filesTabs },
            set: { tabNavigation.setFilesTabs($0) }
        )
    }

    private var featureVisibility: FeatureVisibility {
        FeatureVisibility(developerModeEnabled: developerModeActive)
    }

    private var developerModeActive: Bool {
#if targetEnvironment(simulator)
        developerModeEnabled
            || ProcessInfo.processInfo.arguments.contains("--simulate-developer-mode")
            || ProcessInfo.processInfo.arguments.contains("--simulate-files-tab")
#else
        developerModeEnabled
#endif
    }

    private var selectedVisibleSection: AppSection {
        let selected = AppSection(rawValue: tabNavigation.selectedTab)
        return selected.flatMap {
            featureVisibility.isVisible($0) ? $0 : nil
        } ?? .home
    }

    private func openSettings() {
        showSettings = true
    }

    private func openLogs() {
        showLogs = true
    }
}

private struct CompactTabLabel: View {
    let title: String
    let systemImage: String

    @ViewBuilder
    var body: some View {
        if let image = UIImage(
            systemName: systemImage,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .medium)
        )?.withRenderingMode(.alwaysTemplate) {
            Image(uiImage: image)
        } else {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .medium))
        }
        Text(title)
    }
}

private extension AppSection {
    var titleKey: String {
        switch self {
        case .home: return "tab.home"
        case .new: return "tab.new"
        case .sources: return "tab.sources"
        case .installed: return "tab.inject"
        case .files: return "tab.files"
        case .search: return "tab.search"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .new: return "clock.fill"
        case .sources: return "shippingbox.fill"
        case .installed: return "cube.fill"
        case .files: return "folder.fill"
        case .search: return "magnifyingglass"
        }
    }
}

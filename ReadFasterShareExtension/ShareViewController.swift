import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let closeButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()

        Task { @MainActor in
            await importSharedLink()
        }
    }

    @MainActor
    private func configureView() {
        view.backgroundColor = .systemBackground

        let iconView = UIImageView(image: UIImage(systemName: "link.badge.plus"))
        iconView.tintColor = .systemBlue
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 40, weight: .semibold)

        titleLabel.font = .preferredFont(forTextStyle: .title2)
        titleLabel.textAlignment = .center
        titleLabel.text = "Importing to Read Faster"

        messageLabel.font = .preferredFont(forTextStyle: .body)
        messageLabel.textColor = .secondaryLabel
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.text = "Preparing your shared link..."

        closeButton.configuration = .bordered()
        closeButton.setTitle("Close", for: .normal)
        closeButton.isHidden = true
        closeButton.addTarget(self, action: #selector(closeExtension), for: .touchUpInside)

        let stackView = UIStackView(arrangedSubviews: [
            iconView,
            titleLabel,
            messageLabel,
            activityIndicator,
            closeButton
        ])
        stackView.axis = .vertical
        stackView.spacing = 18
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        activityIndicator.startAnimating()
    }

    @MainActor
    private func importSharedLink() async {
        do {
            let rawLink = try await extractSharedLink()
            try SharedImportDefaultsStore.savePendingURL(rawLink)

            messageLabel.text = "Opening Read Faster..."

            guard let callbackURL = SharedImportDefaultsStore.callbackURL else {
                throw ShareImportError.invalidCallbackURL
            }

            extensionContext?.open(callbackURL) { [weak self] _ in
                self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            }
        } catch {
            activityIndicator.stopAnimating()
            closeButton.isHidden = false
            messageLabel.text = error.localizedDescription
        }
    }

    private func extractSharedLink() async throws -> String {
        guard let inputItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            throw ShareImportError.noSupportedLink
        }

        for inputItem in inputItems {
            for provider in inputItem.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
                   let url = try await loadURL(from: provider) {
                    return url.absoluteString
                }

                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
                   let rawText = try await loadString(from: provider),
                   let normalizedURL = normalizeSharedURL(from: rawText) {
                    return normalizedURL.absoluteString
                }
            }
        }

        throw ShareImportError.noSupportedLink
    }

    private func loadURL(from provider: NSItemProvider) async throws -> URL? {
        let item = try await loadItem(from: provider, typeIdentifier: UTType.url.identifier)

        if let url = item as? URL {
            return url
        }

        if let url = item as? NSURL {
            return url as URL
        }

        if let string = item as? String {
            return normalizeSharedURL(from: string)
        }

        if let string = item as? NSString {
            return normalizeSharedURL(from: string as String)
        }

        return nil
    }

    private func loadString(from provider: NSItemProvider) async throws -> String? {
        let item = try await loadItem(from: provider, typeIdentifier: UTType.plainText.identifier)

        if let string = item as? String {
            return string
        }

        if let string = item as? NSString {
            return string as String
        }

        return nil
    }

    private func loadItem(from provider: NSItemProvider, typeIdentifier: String) async throws -> NSSecureCoding {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let item else {
                    continuation.resume(throwing: ShareImportError.noSupportedLink)
                    return
                }

                continuation.resume(returning: item)
            }
        }
    }

    private func normalizeSharedURL(from rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let explicitURL = URL(string: trimmed),
           let scheme = explicitURL.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            return explicitURL
        }

        if let implicitHTTPSURL = URL(string: "https://\(trimmed)") {
            return implicitHTTPSURL
        }

        return nil
    }

    @objc
    private func closeExtension() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}

private enum SharedImportConfiguration {
    static let appGroupIdentifier = "group.com.jakoblangtry.readfaster"
    static let pendingURLDefaultsKey = "pendingSharedURL"
    static let callbackScheme = "readfaster"
    static let callbackHost = "import-shared"
}

private enum SharedImportDefaultsStore {
    static func savePendingURL(_ rawValue: String) throws {
        guard let defaults = UserDefaults(suiteName: SharedImportConfiguration.appGroupIdentifier) else {
            throw ShareImportError.sharedContainerUnavailable
        }

        defaults.set(rawValue, forKey: SharedImportConfiguration.pendingURLDefaultsKey)
    }

    static var callbackURL: URL? {
        URL(string: "\(SharedImportConfiguration.callbackScheme)://\(SharedImportConfiguration.callbackHost)")
    }
}

private enum ShareImportError: LocalizedError {
    case noSupportedLink
    case sharedContainerUnavailable
    case invalidCallbackURL

    var errorDescription: String? {
        switch self {
        case .noSupportedLink:
            return "Share a web link or text containing a link."
        case .sharedContainerUnavailable:
            return "The shared import container is unavailable."
        case .invalidCallbackURL:
            return "Read Faster could not be opened."
        }
    }
}

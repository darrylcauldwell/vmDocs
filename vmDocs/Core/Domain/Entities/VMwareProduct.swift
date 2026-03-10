import Foundation

/// Represents all VMware products covered by the documentation
enum VMwareProduct: String, Codable, CaseIterable, Identifiable, Sendable {
    case vSphere = "vSphere"
    case vCenter = "vCenter"
    case ESXi = "ESXi"
    case vSAN = "vSAN"
    case NSX = "NSX"
    case Tanzu = "Tanzu"
    case Aria = "Aria"
    case Workstation = "Workstation"
    case Fusion = "Fusion"
    case HCX = "HCX"
    case CloudFoundation = "VCF"
    case CloudDirector = "CloudDirector"
    case Horizon = "Horizon"
    case LiveRecovery = "LiveRecovery"
    case Skyline = "Skyline"
    case PrivateAI = "PrivateAI"
    case Unknown = "Unknown"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .vSphere: return "VMware vSphere"
        case .vCenter: return "VMware vCenter Server"
        case .ESXi: return "VMware ESXi"
        case .vSAN: return "VMware vSAN"
        case .NSX: return "VMware NSX"
        case .Tanzu: return "VMware Tanzu"
        case .Aria: return "VMware Aria"
        case .Workstation: return "VMware Workstation"
        case .Fusion: return "VMware Fusion"
        case .HCX: return "VMware HCX"
        case .CloudFoundation: return "VMware Cloud Foundation"
        case .CloudDirector: return "VMware Cloud Director"
        case .Horizon: return "VMware Horizon"
        case .LiveRecovery: return "VMware Live Recovery"
        case .Skyline: return "VMware Skyline"
        case .PrivateAI: return "VMware Private AI"
        case .Unknown: return "VMware (Other)"
        }
    }

    var iconName: String {
        switch self {
        case .vSphere: return "server.rack"
        case .vCenter: return "building.2"
        case .ESXi: return "cpu"
        case .vSAN: return "externaldrive.connected.to.line.below"
        case .NSX: return "network"
        case .Tanzu: return "square.stack.3d.up"
        case .Aria: return "chart.bar.xaxis"
        case .Workstation: return "desktopcomputer"
        case .Fusion: return "laptopcomputer"
        case .HCX: return "arrow.left.arrow.right"
        case .CloudFoundation: return "cloud"
        case .CloudDirector: return "cloud.fill"
        case .Horizon: return "rectangle.on.rectangle"
        case .LiveRecovery: return "arrow.counterclockwise"
        case .Skyline: return "waveform.path.ecg"
        case .PrivateAI: return "brain"
        case .Unknown: return "questionmark.circle"
        }
    }

    /// URL path component used on Broadcom TechDocs
    var urlPathComponent: String {
        switch self {
        case .vSphere: return "vsphere"
        case .vCenter: return "vcenter"
        case .ESXi: return "esxi"
        case .vSAN: return "vsan"
        case .NSX: return "nsx"
        case .Tanzu: return "tanzu"
        case .Aria: return "aria"
        case .Workstation: return "workstation"
        case .Fusion: return "fusion"
        case .HCX: return "hcx"
        case .CloudFoundation: return "cloud-foundation"
        case .CloudDirector: return "cloud-director"
        case .Horizon: return "horizon"
        case .LiveRecovery: return "live-recovery"
        case .Skyline: return "skyline"
        case .PrivateAI: return "private-ai"
        case .Unknown: return ""
        }
    }

    /// Infer product from a URL path
    static func fromURL(_ url: URL) -> VMwareProduct {
        let path = url.path.lowercased()

        for product in VMwareProduct.allCases where product != .Unknown {
            if path.contains(product.urlPathComponent) ||
               path.contains(product.rawValue.lowercased()) {
                return product
            }
        }

        // Additional patterns
        if path.contains("vcf") || path.contains("cloud-foundation") {
            return .CloudFoundation
        }
        if path.contains("vcd") {
            return .CloudDirector
        }

        return .Unknown
    }
}

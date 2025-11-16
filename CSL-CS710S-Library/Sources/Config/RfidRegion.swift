import Foundation

/// RFID frequency regions
public enum RfidRegion: String, CaseIterable {
    case FCC = "FCC"           // US/Canada
    case ETSI = "ETSI"         // Europe
    case JP = "JP"             // Japan
    case JP2012 = "JP2012"     // Japan 2012
    case TW = "TW"             // Taiwan
    case CN = "CN"             // China
    case KR = "KR"             // Korea
    case AU = "AU"             // Australia
    case MY = "MY"             // Malaysia
    case SG = "SG"             // Singapore
    case TH = "TH"             // Thailand
    case ID = "ID"             // Indonesia
    case PH = "PH"             // Philippines
    case BR1 = "BR1"           // Brazil 1
    case BR2 = "BR2"           // Brazil 2
    case IN = "IN"             // India
    case ZA = "ZA"             // South Africa
    case HK = "HK"             // Hong Kong
}

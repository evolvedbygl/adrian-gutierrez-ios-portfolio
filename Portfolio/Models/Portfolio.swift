import Foundation

// MARK: - Portfolio

/// The root content document. Every screen renders from this model; no copy
/// lives in views.
///
/// Decoding is deliberately forgiving: any missing field falls back to an empty
/// default and unknown fields are ignored, so a partially-written or newer
/// `portfolio.json` never crashes the app. Documents that decode but contain
/// nothing to show are rejected separately via ``isRenderable``.
struct Portfolio: Codable, Equatable, Sendable {
    var name: String
    var headline: String
    var tagline: String
    var availability: String
    var about: [String]
    var experience: [Experience]
    var projects: [Project]
    var capabilityGroups: [CapabilityGroup]
    var beforeSoftware: [String]
    var contact: Contact

    init(
        name: String = "",
        headline: String = "",
        tagline: String = "",
        availability: String = "",
        about: [String] = [],
        experience: [Experience] = [],
        projects: [Project] = [],
        capabilityGroups: [CapabilityGroup] = [],
        beforeSoftware: [String] = [],
        contact: Contact = Contact()
    ) {
        self.name = name
        self.headline = headline
        self.tagline = tagline
        self.availability = availability
        self.about = about
        self.experience = experience
        self.projects = projects
        self.capabilityGroups = capabilityGroups
        self.beforeSoftware = beforeSoftware
        self.contact = contact
    }
}

extension Portfolio {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            name: try c.decodeIfPresent(String.self, forKey: .name) ?? "",
            headline: try c.decodeIfPresent(String.self, forKey: .headline) ?? "",
            tagline: try c.decodeIfPresent(String.self, forKey: .tagline) ?? "",
            availability: try c.decodeIfPresent(String.self, forKey: .availability) ?? "",
            about: try c.decodeIfPresent([String].self, forKey: .about) ?? [],
            experience: try c.decodeIfPresent([Experience].self, forKey: .experience) ?? [],
            projects: try c.decodeIfPresent([Project].self, forKey: .projects) ?? [],
            capabilityGroups: try c.decodeIfPresent([CapabilityGroup].self, forKey: .capabilityGroups) ?? [],
            beforeSoftware: try c.decodeIfPresent([String].self, forKey: .beforeSoftware) ?? [],
            contact: try c.decodeIfPresent(Contact.self, forKey: .contact) ?? Contact()
        )
    }

    /// `true` when the document has enough content to be worth showing. A
    /// syntactically valid but empty document (for example `{}` served by a
    /// misconfigured host) must never replace good content.
    var isRenderable: Bool {
        let hasIdentity = !headline.isBlank || !name.isBlank
        let hasBody = !about.isEmpty || !experience.isEmpty || !projects.isEmpty
        return hasIdentity && hasBody
    }

    /// First word of ``name``, used for friendly labels ("Share Adrian's portfolio").
    var firstName: String {
        name.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? ""
    }

    /// Up to two initials from ``name``, used by the portrait placeholder.
    var initials: String {
        let letters = name.split(whereSeparator: \.isWhitespace).prefix(2).compactMap(\.first)
        return String(letters).uppercased()
    }
}

// MARK: - Experience

struct Experience: Codable, Equatable, Sendable {
    var title: String
    var company: String
    var detail: String
    /// One-sentence overview shown under the company line.
    var summary: String
    /// `yyyy-MM`. Optional.
    var startDate: String?
    /// `yyyy-MM`. `nil` means the role is current.
    var endDate: String?
    var bullets: [String]

    init(
        title: String = "",
        company: String = "",
        detail: String = "",
        summary: String = "",
        startDate: String? = nil,
        endDate: String? = nil,
        bullets: [String] = []
    ) {
        self.title = title
        self.company = company
        self.detail = detail
        self.summary = summary
        self.startDate = startDate
        self.endDate = endDate
        self.bullets = bullets
    }

    /// Human-readable range, e.g. "Oct 2021 – Jun 2026", "Jun 2026 – Present", "Dec 2020".
    var dateRangeText: String {
        DateRangeFormatter.text(start: startDate, end: endDate)
    }
}

extension Experience {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            title: try c.decodeIfPresent(String.self, forKey: .title) ?? "",
            company: try c.decodeIfPresent(String.self, forKey: .company) ?? "",
            detail: try c.decodeIfPresent(String.self, forKey: .detail) ?? "",
            summary: try c.decodeIfPresent(String.self, forKey: .summary) ?? "",
            startDate: try c.decodeIfPresent(String.self, forKey: .startDate),
            endDate: try c.decodeIfPresent(String.self, forKey: .endDate),
            bullets: try c.decodeIfPresent([String].self, forKey: .bullets) ?? []
        )
    }
}

// MARK: - Project

struct Project: Codable, Equatable, Sendable {
    var name: String
    var description: String
    /// Short release-state label, e.g. "Live on the App Store". Optional.
    var status: String
    var linkLabel: String
    var linkURL: String

    init(
        name: String = "",
        description: String = "",
        status: String = "",
        linkLabel: String = "",
        linkURL: String = ""
    ) {
        self.name = name
        self.description = description
        self.status = status
        self.linkLabel = linkLabel
        self.linkURL = linkURL
    }

    /// The outbound link, only when it is a well-formed http(s) URL.
    var link: URL? { SafeURL.web(from: linkURL) }
}

extension Project {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            name: try c.decodeIfPresent(String.self, forKey: .name) ?? "",
            description: try c.decodeIfPresent(String.self, forKey: .description) ?? "",
            status: try c.decodeIfPresent(String.self, forKey: .status) ?? "",
            linkLabel: try c.decodeIfPresent(String.self, forKey: .linkLabel) ?? "",
            linkURL: try c.decodeIfPresent(String.self, forKey: .linkURL) ?? ""
        )
    }
}

// MARK: - CapabilityGroup

struct CapabilityGroup: Codable, Equatable, Sendable {
    var title: String
    var items: [String]

    init(title: String = "", items: [String] = []) {
        self.title = title
        self.items = items
    }
}

extension CapabilityGroup {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            title: try c.decodeIfPresent(String.self, forKey: .title) ?? "",
            items: try c.decodeIfPresent([String].self, forKey: .items) ?? []
        )
    }
}

// MARK: - Contact

struct Contact: Codable, Equatable, Sendable {
    var email: String
    var phone: String
    var linkedIn: String
    var github: String
    var website: String
    /// Closing line shown above the contact buttons. Optional.
    var message: String
    var location: String

    init(
        email: String = "",
        phone: String = "",
        linkedIn: String = "",
        github: String = "",
        website: String = "",
        message: String = "",
        location: String = ""
    ) {
        self.email = email
        self.phone = phone
        self.linkedIn = linkedIn
        self.github = github
        self.website = website
        self.message = message
        self.location = location
    }

    // The content document is remote and therefore untrusted, so every URL the
    // app can open is derived through `SafeURL`, which validates scheme and shape.
    var mailURL: URL? { SafeURL.mail(from: email) }
    var phoneURL: URL? { SafeURL.phone(from: phone) }
    var linkedInURL: URL? { SafeURL.web(from: linkedIn) }
    var githubURL: URL? { SafeURL.web(from: github) }
    var websiteURL: URL? { SafeURL.web(from: website) }

    /// `true` when at least one contact action can be offered.
    var hasAnyAction: Bool {
        mailURL != nil || phoneURL != nil || linkedInURL != nil || githubURL != nil
    }
}

extension Contact {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            email: try c.decodeIfPresent(String.self, forKey: .email) ?? "",
            phone: try c.decodeIfPresent(String.self, forKey: .phone) ?? "",
            linkedIn: try c.decodeIfPresent(String.self, forKey: .linkedIn) ?? "",
            github: try c.decodeIfPresent(String.self, forKey: .github) ?? "",
            website: try c.decodeIfPresent(String.self, forKey: .website) ?? "",
            message: try c.decodeIfPresent(String.self, forKey: .message) ?? "",
            location: try c.decodeIfPresent(String.self, forKey: .location) ?? ""
        )
    }
}

// MARK: - Helpers

extension String {
    var isBlank: Bool { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

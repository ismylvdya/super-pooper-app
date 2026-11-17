import Foundation

/// The section a task stands in, as its line says it (🏊:morning, 🏊:after_work): a default section by
/// its id, the user's own by its title in the form a tag takes. A line with none stands by its routine, or in the
/// section that catches the rest.
enum PoolSectionTag {
    /// The tag's word for a section of the day.
    static func tag(of section: DaySection, definitions: [PoolSectionDefinition]) -> String? {
        guard let title = section.title, section.isCustom else { return section.id }
        return tag(ofTitle: title)
    }

    /// A title as a tag's word: lower case, a space or a sign a tag cannot hold as `_`.
    static func tag(ofTitle title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return String(trimmed.map { $0.isLetter || $0.isNumber || $0 == "-" ? $0 : "_" })
    }

    /// The title an own section gets from a tag no section of the day has yet.
    static func title(ofTag tag: String) -> String {
        let words = tag.replacingOccurrences(of: "_", with: " ")
        return words.prefix(1).uppercased() + words.dropFirst()
    }

    /// The day's section a tag names: a default one by its id, an own one by its title.
    static func section(named tag: String, in sections: DaySections, definitions: [PoolSectionDefinition]) -> DaySection? {
        sections.order.first { self.tag(of: $0, definitions: definitions) == tag }
    }
}

extension DaySections {
    /// An own section, at the end, for each tag the tasks name that no section of the day has (written by hand, or on
    /// another device): the line says where it stands, the day's order is the app's.
    func addingTagged(_ tags: [String], definitions: [PoolSectionDefinition], makeID: () -> String) -> DaySections {
        var result = self
        for tag in tags where PoolSectionTag.section(named: tag, in: result, definitions: definitions) == nil {
            guard !definitions.contains(where: { $0.id == tag }) else { continue }
            result.order.append(DaySection(id: makeID(), title: PoolSectionTag.title(ofTag: tag), isCustom: true))
        }
        return result
    }
}

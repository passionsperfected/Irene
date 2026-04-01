import SwiftUI

struct EventDetailView: View {
    let event: CalendarEvent?
    let onSave: (String, Date, Date, Bool, String?, String?) async throws -> Void
    let isNew: Bool

    @Environment(\.ireneTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date().addingTimeInterval(3600)
    @State private var isAllDay: Bool = false
    @State private var location: String = ""
    @State private var notes: String = ""
    @State private var errorMessage: String?

    init(event: CalendarEvent? = nil, isNew: Bool = true, onSave: @escaping (String, Date, Date, Bool, String?, String?) async throws -> Void) {
        self.event = event
        self.isNew = isNew
        self.onSave = onSave
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text(isNew ? "New Event" : "Event Details")
                        .font(Typography.bodySemiBold(size: 16))
                        .foregroundStyle(theme.primaryText)
                    Spacer()
                    if isNew {
                        Button("Save") { save() }
                            .font(Typography.bodySemiBold(size: 13))
                            .foregroundStyle(theme.accent)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    sectionLabel("TITLE")
                    TextField("Event title", text: $title)
                        .font(Typography.body(size: 14))
                        .textFieldStyle(.plain)
                        .foregroundStyle(theme.primaryText)
                        .padding(10)
                        .background(theme.secondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Toggle("All Day", isOn: $isAllDay)
                    .font(Typography.body(size: 13))
                    .foregroundStyle(theme.primaryText)
                    .toggleStyle(.switch)
                    .tint(theme.accent)

                VStack(alignment: .leading, spacing: 6) {
                    sectionLabel("START")
                    DatePicker("", selection: $startDate, displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute])
                        .labelsHidden()
                }

                VStack(alignment: .leading, spacing: 6) {
                    sectionLabel("END")
                    DatePicker("", selection: $endDate, in: startDate..., displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute])
                        .labelsHidden()
                }

                VStack(alignment: .leading, spacing: 6) {
                    sectionLabel("LOCATION")
                    TextField("Location", text: $location)
                        .font(Typography.body(size: 13))
                        .textFieldStyle(.plain)
                        .foregroundStyle(theme.primaryText)
                        .padding(10)
                        .background(theme.secondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 6) {
                    sectionLabel("NOTES")
                    TextEditor(text: $notes)
                        .font(Typography.body(size: 13))
                        .foregroundStyle(theme.primaryText)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 60)
                        .padding(8)
                        .background(theme.secondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(Typography.body(size: 12))
                        .foregroundStyle(.red)
                }
            }
            .padding(20)
        }
        .background(theme.background)
        .frame(minWidth: 380, minHeight: 480)
        .onAppear {
            if let event {
                title = event.title
                startDate = event.startDate
                endDate = event.endDate
                isAllDay = event.isAllDay
                location = event.location ?? ""
                notes = event.notes ?? ""
            }
        }
    }

    private func save() {
        Task {
            do {
                try await onSave(
                    title,
                    startDate,
                    endDate,
                    isAllDay,
                    location.isEmpty ? nil : location,
                    notes.isEmpty ? nil : notes
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(Typography.label())
            .textCase(.uppercase)
            .tracking(2)
            .foregroundStyle(theme.secondaryText)
    }
}

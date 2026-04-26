import SwiftUI

struct EventDetailView: View {
    let event: CalendarEvent?
    let onSave: (String, Date, Date, Bool, String?, String?) async throws -> Void
    let onDelete: (() async throws -> Void)?

    @Environment(\.ireneTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date().addingTimeInterval(3600)
    @State private var isAllDay: Bool = false
    @State private var location: String = ""
    @State private var notes: String = ""
    @State private var errorMessage: String?
    @State private var showDeleteConfirm = false

    var isNew: Bool { event == nil }

    init(
        event: CalendarEvent? = nil,
        onSave: @escaping (String, Date, Date, Bool, String?, String?) async throws -> Void,
        onDelete: (() async throws -> Void)? = nil
    ) {
        self.event = event
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Text(isNew ? "New Event" : "Edit Event")
                        .font(Typography.bodySemiBold(size: 16))
                        .foregroundStyle(theme.primaryText)
                    Spacer()

                    Button("Save") { save() }
                        .font(Typography.bodySemiBold(size: 13))
                        .foregroundStyle(theme.accent)

                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(theme.secondaryText.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }

                // Title
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

                // All Day
                Toggle("All Day", isOn: $isAllDay)
                    .font(Typography.body(size: 13))
                    .foregroundStyle(theme.primaryText)
                    .toggleStyle(.switch)
                    .tint(theme.accent)

                // Start
                VStack(alignment: .leading, spacing: 6) {
                    sectionLabel("START")
                    DatePicker("", selection: $startDate, displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute])
                        .labelsHidden()
                }

                // End
                VStack(alignment: .leading, spacing: 6) {
                    sectionLabel("END")
                    DatePicker("", selection: $endDate, in: startDate..., displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute])
                        .labelsHidden()
                }

                // Location
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

                // Notes
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

                // Calendar info (read-only for existing events)
                if let event, !event.calendarName.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11))
                            .foregroundStyle(theme.secondaryText)
                        Text(event.calendarName)
                            .font(Typography.body(size: 12))
                            .foregroundStyle(theme.secondaryText)
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(Typography.body(size: 12))
                        .foregroundStyle(.red)
                }

                // Delete button for existing events
                if !isNew, onDelete != nil {
                    Spacer(minLength: 10)
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Text("Delete Event")
                            .font(Typography.bodySemiBold(size: 13))
                            .foregroundStyle(.red.opacity(0.8))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .alert("Delete Event?", isPresented: $showDeleteConfirm) {
                        Button("Delete", role: .destructive) { deleteEvent() }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This will remove the event from your calendar.")
                    }
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
                    title, startDate, endDate, isAllDay,
                    location.isEmpty ? nil : location,
                    notes.isEmpty ? nil : notes
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func deleteEvent() {
        Task {
            do {
                try await onDelete?()
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

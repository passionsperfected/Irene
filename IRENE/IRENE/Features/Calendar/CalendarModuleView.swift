import SwiftUI

struct CalendarModuleView: View {
    @State private var viewModel = CalendarViewModel()
    @State private var showNewEvent = false
    @State private var editingEvent: CalendarEvent?

    @Environment(\.ireneTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().overlay(theme.border.opacity(0.3))

            if !viewModel.hasAccess {
                permissionView
            } else {
                calendarContent
            }
        }
        .background(theme.background)
        .task { await viewModel.requestAccess() }
        .sheet(isPresented: $showNewEvent) {
            EventDetailView { title, start, end, allDay, location, notes in
                try await viewModel.createEvent(
                    title: title, startDate: start, endDate: end,
                    isAllDay: allDay, location: location, notes: notes
                )
            }
        }
        .sheet(item: $editingEvent) { event in
            EventDetailView(
                event: event,
                onSave: { title, start, end, allDay, location, notes in
                    try await viewModel.updateEvent(
                        id: event.id, title: title, startDate: start, endDate: end,
                        isAllDay: allDay, location: location, notes: notes
                    )
                },
                onDelete: {
                    try await viewModel.deleteEvent(id: event.id)
                }
            )
        }
        .overlay {
            Button { showNewEvent = true } label: { Color.clear }
                .keyboardShortcut("n", modifiers: .command)
                .frame(width: 0, height: 0)
                .opacity(0)
                .allowsHitTesting(false)
        }
        #if os(macOS)
        .alert(
            "Open \(viewModel.appLaunchPrompt?.displayName ?? "Calendar")?",
            isPresented: Binding(
                get: { viewModel.appLaunchPrompt != nil },
                set: { if !$0 { viewModel.appLaunchPrompt = nil } }
            ),
            presenting: viewModel.appLaunchPrompt
        ) { app in
            Button("Open \(app.displayName)") {
                Task { await viewModel.confirmLaunchApp() }
            }
            Button("Not Now", role: .cancel) {
                viewModel.cancelLaunchApp()
            }
        } message: { app in
            Text("IRENE works best with \(app.displayName) open so your changes stay in sync.")
        }
        #endif
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Text("Calendar")
                .font(Typography.bodySemiBold(size: 14))
                .foregroundStyle(theme.primaryText)

            Spacer()

            HStack(spacing: 8) {
                Button { viewModel.previousMonth() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.secondaryText)
                }
                .buttonStyle(.plain)

                Button { viewModel.goToToday() } label: {
                    Text("Today")
                        .font(Typography.caption(size: 10))
                        .foregroundStyle(theme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(theme.accent.opacity(0.1))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button { viewModel.nextMonth() } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.secondaryText)
                }
                .buttonStyle(.plain)
            }

            Button { showNewEvent = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13))
                    .foregroundStyle(theme.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var calendarContent: some View {
        HStack(spacing: 0) {
            // Left: Month view
            VStack(spacing: 12) {
                Text(viewModel.selectedDate.formatted(.dateTime.month(.wide).year()))
                    .font(Typography.subheading(size: 16))
                    .foregroundStyle(theme.primaryText)

                DatePicker(
                    "Select Date",
                    selection: $viewModel.selectedDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .padding(.horizontal, 8)

                Spacer()
            }
            .frame(minWidth: 280, maxWidth: 320)
            .padding(.top, 12)

            Divider().overlay(theme.border.opacity(0.3))

            // Right: Day detail
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(viewModel.selectedDate.formatted(date: .complete, time: .omitted))
                        .font(Typography.bodySemiBold(size: 13))
                        .foregroundStyle(theme.primaryText)
                    Spacer()
                    Text("\(viewModel.eventsForSelectedDate.count) events")
                        .font(Typography.caption(size: 10))
                        .foregroundStyle(theme.secondaryText.opacity(0.6))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider().overlay(theme.border.opacity(0.3))

                if viewModel.eventsForSelectedDate.isEmpty {
                    EmptyStateView(
                        icon: "calendar",
                        title: "No Events",
                        message: "Nothing scheduled for this day",
                        action: { showNewEvent = true },
                        actionLabel: "New Event"
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(viewModel.eventsForSelectedDate) { event in
                                eventRow(event)
                                Divider().overlay(theme.border.opacity(0.1))
                            }
                        }
                    }
                }
            }
        }
    }

    private func eventRow(_ event: CalendarEvent) -> some View {
        Button {
            editingEvent = event
        } label: {
            HStack(spacing: 12) {
                // Time indicator
                Rectangle()
                    .fill(theme.accent)
                    .frame(width: 3)
                    .clipShape(RoundedRectangle(cornerRadius: 2))

                VStack(alignment: .leading, spacing: 3) {
                    Text(event.title)
                        .font(Typography.bodySemiBold(size: 13))
                        .foregroundStyle(theme.primaryText)

                    HStack(spacing: 8) {
                        if event.isAllDay {
                            Text("All Day")
                                .font(Typography.caption(size: 10))
                                .foregroundStyle(theme.accent)
                        } else {
                            Text("\(event.startDate.formatted(date: .omitted, time: .shortened)) – \(event.endDate.formatted(date: .omitted, time: .shortened))")
                                .font(Typography.caption(size: 10))
                                .foregroundStyle(theme.secondaryText)
                        }

                        if let location = event.location, !location.isEmpty {
                            HStack(spacing: 3) {
                                Image(systemName: "mappin")
                                    .font(.system(size: 8))
                                Text(location)
                                    .lineLimit(1)
                            }
                            .font(Typography.caption(size: 10))
                            .foregroundStyle(theme.secondaryText.opacity(0.6))
                        }
                    }

                    if let notes = event.notes, !notes.isEmpty {
                        Text(notes)
                            .font(Typography.body(size: 11))
                            .foregroundStyle(theme.secondaryText.opacity(0.5))
                            .lineLimit(2)
                    }
                }

                Spacer()

                Text(event.calendarName)
                    .font(Typography.caption(size: 8))
                    .foregroundStyle(theme.secondaryText.opacity(0.4))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var permissionView: some View {
        EmptyStateView(
            icon: "calendar.badge.exclamationmark",
            title: "Calendar Access Required",
            message: "IRENE needs access to your calendar to show and create events.",
            action: { Task { await viewModel.requestAccess() } },
            actionLabel: "Grant Access"
        )
    }
}

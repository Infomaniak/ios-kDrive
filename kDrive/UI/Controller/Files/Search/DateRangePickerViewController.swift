/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2021 Infomaniak Network SA

 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import HorizonCalendar
import InfomaniakCoreCommonUI
import InfomaniakCoreUIKit
import kDriveCore
import kDriveResources
import UIKit

extension Day {
    var date: Date? {
        return Calendar.current.date(from: components)
    }
}

extension DayRange {
    var dateInterval: DateInterval? {
        if let startDate = lowerBound.date,
           let upperDate = upperBound.date,
           let endDate = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: upperDate) {
            return DateInterval(start: startDate, end: endDate)
        }
        return nil
    }
}

class DateRangePickerViewController: UIViewController {
    var visibleDateRange: ClosedRange<Date>
    var didSelectRange: DateRangeHandler?

    typealias DateRangeHandler = (DateInterval) -> Void

    private enum CalendarSelection {
        case singleDay(Day)
        case dayRange(DayRange)
    }

    private lazy var dayDateFormatter: DateFormatter = {
        let dayDateFormatter = DateFormatter()
        dayDateFormatter.dateStyle = .long
        dayDateFormatter.timeStyle = .none
        return dayDateFormatter
    }()

    private lazy var monthHeaderDateFormatter: DateFormatter = {
        let monthHeaderDateFormatter = DateFormatter()
        monthHeaderDateFormatter.dateFormat = "MMMM yyyy"
        return monthHeaderDateFormatter
    }()

    private lazy var headerLabel: IKLabel = {
        let label = IKLabel()
        label.style = .header2
        label.textAlignment = .center
        return label
    }()

    private lazy var saveButton: IKLargeButton = {
        let button = IKLargeButton(frame: CGRect(x: 0, y: 0, width: 100, height: 50))
        button.setTitle(KDriveResourcesStrings.Localizable.buttonValid, for: .normal)
        button.addTarget(self, action: #selector(saveButtonPressed), for: .touchUpInside)
        return button
    }()

    private lazy var clearButton: IKLargeButton = {
        let button = IKLargeButton(frame: CGRect(x: 0, y: 0, width: 100, height: 50))
        button.style = .secondaryButton
        button.setTitle(KDriveResourcesStrings.Localizable.buttonClear, for: .normal)
        button.addTarget(self, action: #selector(clearButtonPressed), for: .touchUpInside)
        return button
    }()

    private lazy var calendarView = CalendarView(initialContent: makeContent())
    private lazy var calendar = Calendar.current
    private var calendarSelection: CalendarSelection? {
        didSet { updateHeaderTitle() }
    }

    init(visibleDateRange: ClosedRange<Date>) {
        self.visibleDateRange = visibleDateRange
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Add views

        updateHeaderTitle()
        view.addSubview(headerLabel)
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(calendarView)
        calendarView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(clearButton)
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(saveButton)
        saveButton.translatesAutoresizingMaskIntoConstraints = false

        // Constraints

        NSLayoutConstraint.activate([
            headerLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            headerLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            headerLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            calendarView.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 16),
            calendarView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            calendarView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            clearButton.topAnchor.constraint(equalTo: calendarView.bottomAnchor, constant: 16),
            clearButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            clearButton.trailingAnchor.constraint(lessThanOrEqualTo: saveButton.leadingAnchor, constant: -16),
            clearButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            clearButton.widthAnchor.constraint(equalToConstant: 70),
            clearButton.heightAnchor.constraint(equalToConstant: 50),
            saveButton.topAnchor.constraint(equalTo: calendarView.bottomAnchor, constant: 16),
            saveButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            saveButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            saveButton.widthAnchor.constraint(equalToConstant: 100),
            saveButton.heightAnchor.constraint(equalToConstant: 50)
        ])

        // Set up calendar

        calendarView.scroll(toMonthContaining: Date(), scrollPosition: .centered, animated: false)
        calendarView.daySelectionHandler = { [weak self] day in
            self?.didSelectDay(day)
        }
    }

    static func instantiatePanel(visibleDateRange: ClosedRange<Date>,
                                 didSelectRange: DateRangeHandler?) -> DriveFloatingPanelController {
        let dateRangePickerViewController = DateRangePickerViewController(visibleDateRange: visibleDateRange)
        dateRangePickerViewController.didSelectRange = didSelectRange
        let floatingPanelController = DriveFloatingPanelController()
        floatingPanelController.isRemovalInteractionEnabled = true
        floatingPanelController.layout = PlusButtonFloatingPanelLayout(height: 500)
        floatingPanelController.set(contentViewController: dateRangePickerViewController)
        return floatingPanelController
    }

    @objc func saveButtonPressed() {
        switch calendarSelection {
        case .singleDay(let day):
            if let startDate = day.date,
               let endDate = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: startDate) {
                didSelectRange?(DateInterval(start: startDate, end: endDate))
            }
            dismiss(animated: true)
        case .dayRange(let range):
            if let dateInterval = range.dateInterval {
                didSelectRange?(dateInterval)
            }
            dismiss(animated: true)
        case .none:
            break
        }
    }

    @objc func clearButtonPressed() {
        calendarSelection = nil
        calendarView.setContent(makeContent())
    }

    private func updateHeaderTitle() {
        switch calendarSelection {
        case .singleDay(let day):
            if let date = day.date {
                headerLabel.text = dayDateFormatter.string(from: date)
            }
        case .dayRange(let range):
            let dateIntervalFormatter = DateIntervalFormatter()
            dateIntervalFormatter.dateStyle = .long
            dateIntervalFormatter.timeStyle = .none
            if let interval = range.dateInterval {
                headerLabel.text = dateIntervalFormatter.string(from: interval)
            }
        case .none:
            headerLabel.text = KDriveResourcesStrings.Localizable.searchFiltersSelectDate
        }
    }

    private func didSelectDay(_ day: Day) {
        switch calendarSelection {
        case .singleDay(let selectedDay):
            if day > selectedDay {
                calendarSelection = .dayRange(selectedDay ... day)
            } else {
                calendarSelection = .singleDay(day)
            }
        case .none, .dayRange:
            calendarSelection = .singleDay(day)
        }

        calendarView.setContent(makeContent())

        if UIAccessibility.isVoiceOverRunning,
           let selectedDate = calendar.date(from: day.components) {
            calendarView.layoutIfNeeded()
            let accessibilityElementToFocus = calendarView.accessibilityElementForVisibleDate(selectedDate)
            UIAccessibility.post(notification: .screenChanged, argument: accessibilityElementToFocus)
        }
    }

    private func makeContent() -> CalendarViewContent {
        let calendar = Calendar.current

        let dateRanges: Set<ClosedRange<Date>>
        if case .dayRange(let dayRange) = calendarSelection,
           let lowerBound = calendar.date(from: dayRange.lowerBound.components),
           let upperBound = calendar.date(from: dayRange.upperBound.components) {
            dateRanges = [lowerBound ... upperBound]
        } else {
            dateRanges = []
        }

        return CalendarViewContent(
            calendar: calendar,
            visibleDateRange: visibleDateRange,
            monthsLayout: .vertical(options: VerticalMonthsLayoutOptions(alwaysShowCompleteBoundaryMonths: false))
        )
        .interMonthSpacing(24)
        .verticalDayMargin(8)
        .horizontalDayMargin(8)
        .dayItemProvider { [unowned self] day in
            configureDay(day)
        }
        .monthHeaderItemProvider { [unowned self] month in
            configureMonthHeader(month)
        }
        .dayRangeItemProvider(for: dateRanges) { [unowned self] dayRangeLayoutContext in
            configureDayRange(dayRangeLayoutContext)
        }
    }

    private func configureDay(_ day: Day) -> AnyCalendarItemModel {
        var invariantViewProperties = DayView.InvariantViewProperties.baseInteractive

        let isSelectedStyle: Bool
        switch calendarSelection {
        case .singleDay(let selectedDay):
            isSelectedStyle = day == selectedDay
        case .dayRange(let selectedDayRange):
            isSelectedStyle = day == selectedDayRange.lowerBound || day == selectedDayRange.upperBound
        case .none:
            isSelectedStyle = false
        }

        if isSelectedStyle {
            invariantViewProperties.backgroundShapeDrawingConfig.fillColor = KDriveResourcesAsset.infomaniakColor.color
            invariantViewProperties.textColor = .white
            invariantViewProperties.font = UIFont.boldSystemFont(ofSize: invariantViewProperties.font.pointSize)
        } else {
            invariantViewProperties.textColor = TextStyle.body2.color
        }

        let date = calendar.date(from: DateComponents(
            era: day.month.era,
            year: day.month.year,
            month: day.month.month,
            day: day.day
        ))!

        return CalendarItemModel<DayView>(
            invariantViewProperties: invariantViewProperties,
            viewModel: .init(
                dayText: "\(day.day)",
                accessibilityLabel: dayDateFormatter.string(from: date),
                accessibilityHint: nil
            )
        )
    }

    private func configureDayRange(_ dayRangeLayoutContext: CalendarViewContent.DayRangeLayoutContext) -> AnyCalendarItemModel {
        return CalendarItemModel<DayRangeIndicatorView>(
            invariantViewProperties: .init(),
            viewModel: .init(framesOfDaysToHighlight: dayRangeLayoutContext.daysAndFrames.map(\.frame))
        )
    }

    private func configureMonthHeader(_ month: Month) -> AnyCalendarItemModel {
        var invariantViewProperties = MonthHeaderView.InvariantViewProperties.base
        invariantViewProperties.font = TextStyle.header3.font
        invariantViewProperties.textColor = TextStyle.header3.color

        let firstDateInMonth = calendar.date(from: DateComponents(era: month.era, year: month.year, month: month.month))!
        let monthText = monthHeaderDateFormatter.string(from: firstDateInMonth)

        return CalendarItemModel<MonthHeaderView>(
            invariantViewProperties: invariantViewProperties,
            viewModel: .init(monthText: monthText, accessibilityLabel: monthText)
        )
    }
}

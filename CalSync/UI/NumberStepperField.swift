//
//  NumberStepperField.swift
//  CalSync
//
//  Created by Codex on 13.07.2026.
//

import SwiftUI

struct NumberStepperField: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let unit: String

    var body: some View {
        HStack(spacing: InterfaceMetrics.controlSpacing) {
            Text(title)
                .lineLimit(1)
            Spacer(minLength: InterfaceMetrics.sectionSpacing)
            HStack(spacing: 6) {
                Stepper("Изменить: \(title)", value: $value, in: range)
                    .labelsHidden()
                TextField(title, value: $value, format: .number)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .frame(width: InterfaceMetrics.numericFieldWidth)
                Text(unit)
                    .foregroundStyle(.secondary)
                    .frame(width: InterfaceMetrics.numericUnitWidth, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

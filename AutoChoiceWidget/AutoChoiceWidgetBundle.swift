// AutoChoice — AutoChoiceWidgetBundle.swift
// Widget bundle entry point. Registers all widget configurations.

import WidgetKit
import SwiftUI

@main
struct AutoChoiceWidgetBundle: WidgetBundle {
    var body: some Widget {
        LastResultWidget()
    }
}

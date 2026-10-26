import AppIntents
import WidgetKit

struct LuneConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Choose a Place" }

    @Parameter(title: "Place")
    var place: PlaceEntity?
}

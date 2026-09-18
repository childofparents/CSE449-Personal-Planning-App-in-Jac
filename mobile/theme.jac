"""Cadence's shared visual identity, expressed as native style tokens."""
import from "@jac/mobui" { StyleSheet }
obj Colors {
    has bg: str = "#f8f9fc",
        surface: str = "#ffffff",
        text: str = "#292b3e",
        muted: str = "#777b8d",
        accent: str = "#7465dc",
        border: str = "#eeeff5",
        onAccent: str = "#ffffff";
}
obj Spacing {
    has md: int = 12,
        lg: int = 16;
}
obj Radii {
    has md: int = 12;
}
obj Fonts {
    has md: int = 15;
}
glob:pub C = Colors(),
     S = Spacing(),
     R = Radii(),
     F = Fonts();
glob:pub styles = StyleSheet.create(
         {
             "screen": {"flex": 1, "backgroundColor": C.bg},
             "body": {
                 "padding": 20,
                 "gap": 18,
                 "paddingBottom": 32,
                 "width": "100%",
                 "maxWidth": 720,
                 "alignSelf": "center"
             },
             "row": {
                 "flexDirection": "row",
                 "alignItems": "center",
                 "gap": 10,
                 "flexWrap": "wrap"
             },
             "between": {
                 "flexDirection": "row",
                 "alignItems": "center",
                 "justifyContent": "space-between",
                 "gap": 10
             },
             "card": {
                 "backgroundColor": C.surface,
                 "borderRadius": 18,
                 "padding": 18,
                 "gap": 12,
                 "borderWidth": 1,
                 "borderColor": C.border
             },
             "title": {"fontSize": 28, "fontWeight": "700", "color": C.text},
             "heading": {"fontSize": 19, "fontWeight": "700", "color": C.text},
             "text": {"fontSize": 15, "lineHeight": 22, "color": C.text},
             "muted": {"fontSize": 13, "lineHeight": 20, "color": C.muted},
             "eyebrow": {
                 "fontSize": 11,
                 "letterSpacing": 2,
                 "fontWeight": "600",
                 "color": C.muted
             },
             "input": {
                 "minHeight": 48,
                 "borderWidth": 1,
                 "borderColor": "#e5e0ec",
                 "borderRadius": 10,
                 "paddingHorizontal": 12,
                 "paddingVertical": 12,
                 "backgroundColor": "#fcfbfe",
                 "color": C.text,
                 "fontSize": 16
             },
             "pill": {
                 "paddingHorizontal": 14,
                 "paddingVertical": 12,
                 "borderRadius": 12,
                 "borderWidth": 1,
                 "borderColor": C.border,
                 "backgroundColor": C.surface,
                 "minHeight": 44
             },
             "active": {"backgroundColor": "#eeebfc", "borderColor": "#c9c0f2"},
             "banner": {
                 "padding": 14,
                 "borderRadius": 12,
                 "backgroundColor": "#eeebfc",
                 "gap": 8
             },
             "error": {"padding": 14, "borderRadius": 12, "backgroundColor": "#fff0ed"},
             "bottom": {
                 "flexDirection": "row",
                 "paddingHorizontal": 12,
                 "paddingTop": 10,
                 "gap": 8,
                 "borderTopWidth": 1,
                 "borderColor": C.border,
                 "backgroundColor": C.surface
             },
             "event": {
                 "borderLeftWidth": 4,
                 "borderRadius": 14,
                 "backgroundColor": C.surface,
                 "padding": 16,
                 "gap": 8,
                 "borderWidth": 1,
                 "borderColor": C.border
             },
             "modal": {"flex": 1, "backgroundColor": C.bg},
             "stat": {
                 "flex": 1,
                 "minWidth": 85,
                 "backgroundColor": C.surface,
                 "padding": 14,
                 "borderRadius": 14,
                 "gap": 6
             },
             "map": {
                 "height": 200,
                 "width": "100%",
                 "borderRadius": 12,
                 "backgroundColor": "#eeebfc"
             }
         }
     );

def:pub categoryColor(value: str) -> str {
    colors: any = {
        "academics": "#7664d6",
        "gym": "#378d78",
        "social/campus": "#bd7a48",
        "personal": "#597fb4",
        "travel": "#858995"
    };
    return colors[value] or C.accent;
}

"""Browser preview frame; native variant owns device safe areas."""
import from "@jac/mobui" { View }
def:pub SafeRoot(children: any) -> JsxElement { <View style={{"height":"100vh","flex":1}}>{children}</View> }
def:pub SafeFrame(children: any, style: any, edges: any = None) -> JsxElement { <View style={style}>{children}</View> }

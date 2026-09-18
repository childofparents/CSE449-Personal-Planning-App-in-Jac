"""Respect iOS notches/home indicator and Android system insets."""
import from "react-native-safe-area-context" { SafeAreaProvider, SafeAreaView }
def:pub SafeRoot(children: any) -> JsxElement { <SafeAreaProvider>{children}</SafeAreaProvider> }
def:pub SafeFrame(children: any, style: any, edges: any = None) -> JsxElement { <SafeAreaView style={style} edges={edges or ["top","bottom"]}>{children}</SafeAreaView> }

import from "@jac/mobui" { View, Text, TextInput }
import from ..theme { styles, C }
def:pub Field(
    label: str,
    value: str,
    onChange: any,
    secret: bool = False,
    placeholder: str = "",
    numeric: bool = False
) -> JsxElement {
    <View style={{"gap": 6, "flexGrow": 1}}>
        <Text style={styles.muted}>{label}</Text>
        <TextInput
            accessibilityLabel={label}
            value={value}
            onChangeText={onChange}
            secureTextEntry={secret}
            placeholder={placeholder}
            placeholderTextColor={C.muted}
            autoCapitalize="none"
            autoCorrect={False}
            keyboardType={"number-pad" if numeric else "default"}
            style={styles.input}
        />
    </View>
}

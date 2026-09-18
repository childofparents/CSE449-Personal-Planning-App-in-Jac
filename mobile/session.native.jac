"""iOS Keychain / Android encrypted storage; never persist passwords."""
import from "expo-secure-store" { getItemAsync, setItemAsync, deleteItemAsync }
def:pub initialServer() -> str { return "http://127.0.0.1:8000"; }
async def:pub readSession() -> any { return JSON.parse((await getItemAsync("cadence-mobile")) or "null"); }
async def:pub writeSession(value: any) -> None { await setItemAsync("cadence-mobile",JSON.stringify(value)); }
async def:pub clearSession() -> None { await deleteItemAsync("cadence-mobile"); }


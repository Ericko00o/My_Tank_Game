# 坦克競技場 · Godot 版

這是與原網頁版並存的 Godot 4.7.2 / GDScript 首個可玩版本。此目錄不取代原本的 `index.html` 或 `server.js`。

## 目前內容

- 兩台坦克：鋼鐵、飛翼，各有普攻、E 技能與大招。
- 兩張地圖：冰天雪地、雨林古跡。
- 單人練習（簡單電腦對手），以及同一區域網路的 1v1 / 2v2。
- 三分鐘或先取得 25 次擊殺；死亡後四秒復活。
- 主機判定移動、障礙物、命中與傷害；加入玩家有移動預測和畫面平滑。

此版是獨立的精簡版本，不包含原網頁版的全部角色、四張地圖或完整模式。角色與地面圖片是為此版本產生的原創素材。

## 執行 Windows 版本

在已產生本機匯出檔的電腦上，雙擊 `Play.bat` 或 `build/TankArena.exe`。本機匯出檔會被 Git 忽略，不會隨儲存庫上傳；若沒有該檔案，請使用下列 Godot 編輯器方式，或依後述步驟重新匯出。

匯出後的 `TankArena.exe` 已包含遊戲資料。將執行檔及 `build/licenses` 資料夾一起提供給朋友，朋友不需要安裝 Godot。遊戲採用的 Godot 引擎及第三方授權聲明也位於 `licenses`。

## Godot 編輯器開啟

1. 下載 [Godot 4.7.2 標準版](https://godotengine.org/download/archive/4.7.2-stable/)並解壓縮。
2. 啟動 Godot，匯入此目錄的 `project.godot`。
3. 等待素材匯入完成，按 F6 執行目前場景或 F5 執行專案。

也可以在命令列執行 `godot --editor --path godot-game`，匯入素材後執行 `godot --path godot-game`。

## 區域網路對戰

1. 所有人啟動同一版本的遊戲，輸入名稱並選擇坦克。
2. 一人選擇地圖並按「建立房間」。畫面會顯示可用 IP；如有多個 IP，可用 Windows 的 `ipconfig` 確認實際區域網路 IPv4。
3. 其他人在「房主 IP」輸入房主的區域網路 IPv4，按「加入房間」。
4. 兩人或四人到齊後，由房主按「開始對戰」，系統依加入順序交替分隊。
5. 必要時請允許同一區域網路對房主的 UDP 23456 連線。此版本沒有外網穿透、登入、重連或專用伺服器。

## 操作與技能

- WASD / 方向鍵移動；滑鼠瞄準；左鍵普通攻擊。
- 鋼鐵：每第七發普攻穿透障礙與敵人；E 加速；空白鍵後左鍵選位置施放範圍轟炸。
- 飛翼：E 後左鍵點選範圍內敵人發射三枚導彈；空白鍵後左鍵選方向，蓄力 1 秒發射鐳射炮。
- Esc 取消技能瞄準；對戰結束或需要退出時按右上角返回大廳。

## 重新匯出 Windows

Godot 編輯器中安裝 4.7.2 對應的官方 Export Templates，選擇 Project → Export → Windows → Export Project。預設匯出路徑為 `build/TankArena.exe`，並將授權資料夾一同放進發行目錄。

## 測試

- `godot --headless --path godot-game --script res://tests/simulation_test.gd`
- `godot --headless --path godot-game --script res://tests/packet_test.gd`
- `network_smoke.gd` 和 `network_four_test.gd` 分別需同時啟動一個 `-- host` 與一個／三個 `-- client` 程序。

同機多人程序測試不能取代不同電腦和不同 Wi-Fi 環境下的實際遊玩測試。

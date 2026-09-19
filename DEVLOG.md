# MiniWarGame 開發日誌｜2026-09-19

今天 MiniWarGame 從原本的基礎戰鬥 Prototype，往「真正有兵種與空間差異的小型戰棋」前進了一大步。

---

## 今天完成的內容

### 1. Combat Log UI

把原本只存在 Output 裡的戰鬥過程正式搬到遊戲 UI。

現在攻擊時可以直接看到：

Attack → Hit → Wound → Save → Damage

Board 會產生結構化 Combat Result，HUD 只負責顯示，不重新計算戰鬥規則。

即使攻擊完全 Miss、Wound 失敗或敵人死亡，都能正常留下這次戰鬥結果。

---

### 2. AP = 0 的 Exhausted UX

實際遊玩時發現：

「我分不清哪隻棋子已經行動過。」

因此加入 Exhausted State。

現在 Unit AP 歸零後：

- 自動取消 Selected
- 清除 Movement Range
- 棋子顏色變暗
- 下一回合 reset AP 後恢復正常顏色
- AP = 0 的棋子不能再次 Selected

這讓「還能行動」與「本回合已經行動完」可以直接從棋盤辨認。

---

### 3. Hover Info 與 Selected 正式分離

定義：

- **Selected** = 我要操作這隻棋
- **Hovered** = 我只是想查看這隻棋

所以即使 Unit AP = 0、不能再操作，滑鼠移上去仍然可以查看：

- Unit Name
- Type
- HP
- AP

Enemy 也可以 Hover 查看。

另外加入 Show Enemy HP 開關：

- **OFF：** Enemy HP = `?`
- **ON：** 顯示實際 Enemy HP

目前先保留這個選項，之後透過 Playtest 判斷「完全資訊」還是「隱藏敵方 HP」比較有趣。

---

### 4. 決定不採用全域 Kill Reward

今天討論過：

Kill Enemy → +1 AP

雖然這會產生很有趣的連續行動，但也可能形成：

Kill → 更多 AP → 更多 Action → 更多 Kill → 更大的領先

也就是 Snowball。

因此決定：

「擊殺回 AP」不作為全遊戲基本規則。

未來改成 Berserker 的特殊能力 **Momentum**：

- 擊敗敵人恢復 1 AP
- 每回合最多觸發一次
- AP 不超過 max AP

今天尚未實作 Momentum。

---

### 5. Multi-Tile Footprint

今天最大的底層改動。

原本所有 Unit 都是 1×1。現在 Unit 新增：

```
footprint: Vector2i
```

目前允許：

- 1×1
- 2×1
- 1×2
- 2×2

並決定：

**2×1 與 1×2 是固定不同 Footprint。**

目前不做：

- Rotation
- Facing
- Rotate Action

`grid_position` 現在代表 Footprint 的 Anchor Tile。

例如：

```
grid_position = (3,3)
footprint = (2,2)
```

實際佔據：

```
(3,3) (4,3)
(3,4) (4,4)
```

---

### 6. Footprint 系統全面 Generic 化

這是今天很重要的一個架構決策：

**不要為不同 Size 寫不同 Movement Function。**

現在統一使用：

- Unit → `footprint` / `get_occupied_tiles()`
- Board → `can_place_unit()` / `get_reachable_tiles()` / occupancy / adjacency

因此不存在：

- `get_reachable_1x2()`
- `get_reachable_2x2()`
- `can_place_2x1()`

之類的特殊規則。

理論上未來即使出現 3×1，只要棋盤放得下，同一套演算法仍可以處理。

**Footprint 是 Data，不是另一套 Rule。**

---

### 7. Multi-Tile Movement / Occupancy

BFS 仍然只計算 Anchor。

但每個候選位置會檢查「整個 Footprint」：

- 是否全部在 Board 內
- 是否撞到其他 Unit
- 移動時排除自己原本的 Footprint

因此大型 Unit 移動時，即使新舊 Footprint 部分重疊，也不會把自己當成障礙。

MOVE_RANGE 仍然定義為：

**Anchor 移動一格 = 1 Movement Cost**

Unit 大小不會額外增加移動成本。

---

### 8. Multi-Tile Melee

原本近戰判斷：

Manhattan Distance == 1

現在改成：

Attacker 任意 occupied tile 與 Target 任意 occupied tile，只要有一組正交相鄰，就可以近戰攻擊。

因此大型 Unit 的攻擊距離是從 Footprint 邊緣判斷，而不是 Anchor。

---

### 9. Footprint Visual / Collision

大型 Unit 的 Body、Base、CollisionShape 會跟著 Footprint 改變。

例如 2×1 Unit 在畫面上真的會佔兩格寬度。

但一個大型 Unit 仍然只有：

- 一個 Unit Instance
- 一個 CollisionShape
- 一組 HP / AP / Stats

不是把 2×2 拆成四隻 Unit。

---

### 10. Footprint Highlight

Selected Unit 現在會把自己實際佔據的所有格亮起來。

Movement Range 也從「只顯示 Anchor」升級成：

- Movement Anchor：較明顯的綠色
- Destination Footprint：較淡的綠色
- Selected Footprint：暖黃色

最後 Highlight Priority：

Hover → Movement Anchor → Selected → Movement Footprint → Base

這裡有一個重要原則：

**狀態資訊不能蓋掉 Action 資訊。**

如果某格同時是 Selected Footprint，又是合法 Movement Anchor，必須優先告訴玩家：「這格可以點。」

Movement legality 仍然只由 `_reachable_anchors` / `can_place_unit()` 決定，顏色只是 UI。

**Visual ≠ Rule Authority。**

---

### 11. Unit Archetype 正式加入

今天正式出現第一批兵種：

#### Scout

| | |
|---|---|
| Footprint | 1×1 |
| HP | 4 |
| AP | 3 |
| Move | 3 |
| Attacks | 2 |
| Hit | 4+ |
| Wound | 4+ |
| Save | 5+ |
| Damage | 1 |

定位：Fast / Fragile

#### Guard

| | |
|---|---|
| Footprint | 1×1 |
| HP | 7 |
| AP | 2 |
| Move | 1 |
| Attacks | 2 |
| Hit | 4+ |
| Wound | 4+ |
| Save | 3+ |
| Damage | 1 |

定位：Slow / Durable

#### Berserker

| | |
|---|---|
| Footprint | 2×1 |
| HP | 6 |
| AP | 2 |
| Move | 2 |
| Attacks | 3 |
| Hit | 4+ |
| Wound | 3+ |
| Save | 4+ |
| Damage | 1 |

定位：Aggressive / Large

未來 Berserker 預計加入 Momentum。

---

### 12. Archetype 架構決策

決定：**Archetype 決定 Footprint。**

- Scout → 1×1
- Guard → 1×1
- Berserker → 2×1

Archetype 同時也是 Unit 初始 Stats 的來源。

目前集中在 `Unit._apply_archetype()`。

Board / AI 不知道 Scout、Guard、Berserker 是什麼。它們只讀：

- `unit.move_range`
- `unit.footprint`
- `unit.current_ap`
- `unit.attacks`
- …

這讓 Archetype 不會污染 Board 的通用規則。

---

### 13. 修掉 Hover Unit Death Lifecycle Bug

Playtest 發現：

Hovered Unit 被擊殺並 `queue_free()` 後，HUD 曾經還拿著已經 freed 的 Unit reference。

已修正：

- HUD 不再把 freed object 當 Unit 使用
- queued-for-deletion Unit 不再成為 Hover Target
- Unit 死亡後 Hover Info 正常清除

---

## 今天最後做了一次 Code Health Check

請 Cursor 只 Review、不修改程式。

結果：

**CRITICAL：0**

目前沒有發現需要立即重構、或會穩定造成 Crash / Gameplay Error 的問題。

比較重要的後續項目：

1. Enemy AI 現在只鎖定第一個 Player，需要改善 Target Selection。
2. Active Unit lifecycle protection 可以補得和 Hover 一樣完整。
3. Momentum 必須插在正確的 Attack Lifecycle。

目前 Attack Lifecycle：

```
Spend AP
→ Resolve Attack
→ Damage / Death
→ [未來 Momentum]
→ Exhausted Cleanup
```

這樣最後 1 AP 擊殺時：

```
AP 1
→ Attack
→ AP 0
→ Kill
→ Momentum +1
→ 最終 AP 1
→ 不會進入 Exhausted
```

---

## 架構健檢結論

目前不需要：

- BoardManager
- CombatManager
- TurnManager
- AbilityManager
- Event Bus
- Autoload
- Resource Database
- Behavior Tree

Board 雖然逐漸變大，但目前仍然可以合理視為 **Spatial + Action Authority**。

| 層 | 責任 |
|---|---|
| Unit | Archetype、Stats、Footprint、HP、AP、Visual State |
| Board | 空間規則、移動、佔格、攻擊合法性、戰鬥結算 |
| Game | Turn、Enemy AI |
| HUD | Display Only |

目前 Prototype 還沒有因為快速開發而累積到「必須大重構」的程度。

---

## 下一次開發入口

下次預計：

1. 改善 Enemy AI Target Selection
2. 補 Active Unit lifecycle safety
3. 實作 Berserker 第一個特殊能力：**Momentum**
   - Defeat Enemy → Recover 1 AP
   - Once Per Turn
   - Cannot exceed Max AP

今天先停在這裡。

MiniWarGame 已經從「兩顆不同顏色的方塊互打」，開始變成「具有兵種、Footprint、移動差異、AP、戰鬥、死亡、AI 與資訊 UI 的小型戰棋 Prototype。」

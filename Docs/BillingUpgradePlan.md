# BioScan Apps 额度与 Lifetime 统一升级文档

## 1. 文档目的

统一 Rock、Fish、Mushroom、Dr.Bird 和 Plant/iNature 的识别额度、赠送额度、付费扫描包和 Lifetime 会员逻辑，避免各 App 使用不同的存储模型和会员判断方式。

本次升级目标：

- 所有 App 使用同一个公共额度组件；
- 所有 App 统一使用“剩余次数”模型；
- 统一免费额度、赠送额度和付费额度的扣除顺序；
- 接入取消购买后一次性赠送 10 次识别；
- 统一 Lifetime 的购买、恢复、缓存和离线策略；
- 支持旧版本数据迁移，不影响已有用户额度和购买权益。

> 本文是 iOS 会员与额度实现的兼容性基线。任何后续重构都必须满足：老用户
> Lifetime 不丢失、已购额度不减少、已消耗免费次数不被重置、同一笔 consumable
> 交易最多入账一次。

## 0. 实施状态与范围

本轮只处理 iOS，覆盖 BioScanKit、Fish、Mushroom、Rock、NatureEar（Dr.Bird）和
Plant/iNature。Android 不在本轮变更范围。

| 项目 | 免费额度存储 | 付费额度存储 | Lifetime 兼容 |
| --- | --- | --- | --- |
| Fish | `fish.billing.free_remaining_v1`（remaining） | `fish.billing.paid_credits` | lifetime + lifetimeV2 |
| Mushroom | `mushroom.billing.free_scans_remaining`（remaining） | `mushroom.billing.paid_scans_remaining` | lifetime + lifetimeV2 |
| Rock | `scan_balance.free_remaining`（remaining） | `scan_balance.paid_remaining` | legacy + V2 + V3 |
| NatureEar | `free_scan_used_count_v1`（used） | `natureear_credits` | `com.zhuoben.NatureEar.unlimited` |
| Plant/iNature | `free_scan_used_count_v1`（used） | `recognition_credits` | legacy + V2 |

上述 key 和历史产品 ID 都属于持久化协议，不得直接删除或改名。

## 2. 当前实现现状

### 2.1 Rock

Rock 在 `RevenueCatService` 内部直接管理：

- 免费剩余次数；
- 付费剩余次数；
- Lifetime product ID；
- RevenueCat entitlement；
- UserDefaults 持久化。

当前新用户免费额度为 5 次，扣除顺序为免费次数优先，然后扣付费次数。Lifetime 用户跳过扣除。

### 2.2 Fish

Fish 使用 BioScanKit 的 `CreditLedger`，配置独立的 UserDefaults Key：

- `fish.billing.free_remaining_v1`；
- `fish.billing.paid_credits`；
- `fish.billing.lifetime_cache`。

当前新用户免费额度为 5 次，Lifetime 通过 Ledger 设置为 unlimited。

### 2.3 Mushroom

Mushroom 自己管理免费和付费次数，并保存：

- `mushroom.billing.free_scans_remaining`；
- `mushroom.billing.paid_scans_remaining`；
- `mushroom.billing.lifetime_unlocked`。

当前新用户免费额度为 5 次。Lifetime 本地缓存较强，购买状态会写入本地 Bool。

### 2.4 Dr.Bird

Dr.Bird 使用“已使用免费次数”模型：

```text
freeRemaining = max(5 - freeUsedCount, 0)
```

这与其他 App 的“剩余次数”模型不同，迁移时需要转换。

### 2.5 Plant/iNature

Plant/iNature 将免费使用次数和付费 credits 分开管理：

- `free_scan_used_count_v1`；
- `recognition_credits`；
- `membership_tier`；
- `membership_lifetime_purchase_verified_v1`。

它同样使用“已使用免费次数”模型，并且 Lifetime 缓存策略与其他 App 不一致。

### 2.6 10 次赠送功能

BioScanKit 已经存在以下能力：

- `PurchaseRecovery`；
- `PurchaseRecoverySheet`；
- `PurchaseRecoveryReviewGate`；
- 默认 `bonusCredits = 10`。

但是当前几个 App 只记录成功识别，没有真正接入：

- 取消购买后的赠送弹窗；
- 一次性领取；
- 10 次额度入账；
- 赠送状态持久化。

## 3. 目标架构

公共组件建议拆分为四层：

```text
BioScanBilling
├── CreditLedger
├── EntitlementManager
├── RecognitionAccessController
└── BillingMigration
```

### 3.1 CreditLedger

负责所有本地额度的读取、扣除、增加和持久化。

推荐余额模型：

```swift
public struct CreditBalance: Equatable, Sendable {
    public let freeRemaining: Int
    public let bonusRemaining: Int
    public let paidRemaining: Int
    public let hasUnlimitedAccess: Bool

    public var totalRemaining: Int {
        hasUnlimitedAccess
            ? Int.max
            : freeRemaining + bonusRemaining + paidRemaining
    }
}
```

额度桶说明：

- `freeRemaining`：新用户免费额度；
- `bonusRemaining`：系统赠送额度，例如取消购买后赠送 10 次；
- `paidRemaining`：用户购买的扫描包；
- `hasUnlimitedAccess`：Lifetime 无限权限。

### 3.2 扣除顺序

统一为：

```text
Lifetime
    不扣除

免费额度 > 0
    扣 freeRemaining

免费额度用完且赠送额度 > 0
    扣 bonusRemaining

前两者用完且付费额度 > 0
    扣 paidRemaining

全部为 0
    返回 noCredits
```

公共接口建议：

```swift
public func consumeOneCredit() -> ConsumeResult
public func addBonusCredits(_ amount: Int, campaignID: String) -> Bool
public func addPaidCredits(_ amount: Int, transactionID: String?)
public func setUnlimited(_ enabled: Bool)
public var balance: CreditBalance { get }
```

### 3.3 EntitlementManager

统一封装 RevenueCat 会员状态判断：

```swift
public enum EntitlementState: Equatable, Sendable {
    case unknown
    case standard
    case lifetime
}
```

Lifetime 判断必须同时兼容：

1. RevenueCat `pro` entitlement；
2. 当前 Lifetime product ID；
3. 历史 Lifetime product ID；
4. 本地缓存的已验证状态。

推荐判断逻辑：

```text
customerInfo.entitlements["pro"].isActive == true
    或
购买商品 ID 属于 lifetimeProductIDs
    或
本地缓存仍在有效校验期内
```

### 3.4 RecognitionAccessController

所有 App 的识别流程都通过公共入口执行：

```swift
public func performRecognition<Result>(
    source: RecognitionSource,
    operation: () async throws -> Result
) async throws -> Result
```

执行流程：

```text
1. 校验图片和识别参数；
2. 检查 Lifetime 或剩余额度；
3. 防止重复提交；
4. 创建额度 reservation；
5. 开始真正的模型推理；
6. 推理已开始后提交一次额度扣除；
7. 图片无效、权限失败或推理未开始时回滚 reservation；
8. 返回识别结果。
```

这样可以避免空图片、权限失败、用户重复点击和引导演示流程误扣次数。

## 4. 10 次赠送接入方案

### 4.1 触发条件

赠送功能应在用户取消一次购买后显示，而不是在用户评价 App 后显示。

```text
用户打开购买页
    ↓
用户取消购买
    ↓
判断本活动是否尚未领取
    ↓
显示“领取 10 次免费识别”弹窗
```

赠送不应依赖：

- App Store 评分；
- 用户选择星级；
- 用户提交评论；
- 外部链接点击。

### 4.2 活动 ID

每个 App 使用独立 campaign ID：

```text
rock_purchase_recovery_v1
fish_purchase_recovery_v1
mushroom_purchase_recovery_v1
bird_purchase_recovery_v1
plant_purchase_recovery_v1
```

### 4.3 领取流程

```text
用户点击领取
    ↓
检查 campaignID 是否已领取
    ↓
CreditLedger.addBonusCredits(10, campaignID: ...)
    ↓
记录 transaction / campaign 状态
    ↓
关闭弹窗并刷新余额
```

## 5. 版本升级兼容性规范

### 5.1 不变量

升级前后必须满足：

```text
paidAfter >= paidBefore
bonusAfter >= bonusBefore
freeAfter == freeBefore
lifetimeAfter == lifetimeBefore（远端明确校验结果除外）
同一 transactionID 的累计入账次数 <= 1
```

不得因为新增 `didSeed` 标记而重新发放免费次数。若旧余额 key 已存在，即使值为
0，也代表用户已经拥有过该额度；升级时只写 seed 标记，不改余额。

### 5.2 `.used` 与 `.remaining`

两种模型不可直接更换 key：

```text
remaining = max(allowance - used, 0)
used = max(allowance - remaining, 0)
```

如果未来必须迁移，迁移函数需要同时读取旧值、写入新值并在最后写入独立版本标记。
重复运行必须得到相同结果。

### 5.3 安全迁移顺序

1. 读取旧版余额、Lifetime、本地交易集合及迁移标记；
2. 对所有数值执行非负约束，但不擅自补满；
3. 写入新账本结构；
4. 重新读取并校验余额和权益；
5. 最后写入 `migrationVersion`；
6. 校验失败时保留旧数据，下一次启动可安全重试。

旧 key 至少保留一个稳定版本周期。迁移发布后不得立即清理，以便降级安装或紧急回滚。

## 6. Consumable 交易交付规则

- 付费额度入账必须携带非空、稳定的 App Store transaction ID；
- transaction ID 缺失时不得猜测 ID 或直接加额度，应显示“购买待确认”并触发交易刷新；
- 已处理 ID 与余额更新必须按“余额先写、处理标记后写”的顺序，避免付款后永久丢额度；
- 长期目标是把余额和已处理 ID 存入同一个可原子提交的账本；
- 恢复购买只恢复 Lifetime。Consumable 不承诺跨设备恢复，除非引入服务端账本。

当前 `UserDefaults` 实现改善了最危险的“先标记、后加余额”顺序，但仍不具备跨进程
事务能力。切换到单对象账本或数据库前，不得删除旧字段。

### 6.1 单对象账本的安全落地步骤

单对象账本不能在一个版本内直接替换旧 key，按三个版本阶段推进：

1. **准备版本**：继续以旧 key 为准，同时写入带 schemaVersion 和 checksum 的影子账本；
2. **验证版本**：启动时比较新旧账本并记录差异，仍以旧 key 为准，不自动合并较大值；
3. **切换版本**：仅对已连续校验成功的安装切换新账本为主，并继续镜像旧 key；
4. 至少再经过一个稳定版本后，才允许停止旧 key 双写；历史 key 仍不删除。

不能使用 `max(old, new)` 自动解决冲突，因为这会把已经消耗的额度复活。冲突时应保留
旧账本为权威并上报诊断，或要求服务端/客服人工校正。

## 7. Lifetime 校验与离线策略

- 每个 App 必须保留全部历史 Lifetime 产品 ID；
- 购买成功可立即写本地缓存，避免 RevenueCat entitlement 配置延迟影响 UI；
- 正常联网刷新可以应用 RevenueCat 的明确结果；
- 网络错误或缺少 CustomerInfo 不能被当作“不是会员”；
- Restore 结果必须区分“恢复成功”“没有购买”“请求失败”；
- 产品 ID 更新时先增加新 ID，至少经过一个稳定版本后再评估旧 ID，原则上永久保留。

## 8. 识别与扣减时序

推荐时序：检查额度 → 执行有效识别 → 原子扣减 → 发布结果。

发布结果前必须检查最终扣减结果。识别期间余额可能被另一个任务改变；最终扣减失败时
不能继续展示免费结果，应进入 no-credits/Paywall 流程。Guide Demo 明确跳过扣减。

## 9. 测试矩阵

每个发布版本至少覆盖：

| 场景 | 预期 |
| --- | --- |
| 全新安装 | 仅首次获得 5 次免费额度 |
| 老版本 free=0 且没有 seed 标记 | 保持 0，并补写 seed 标记 |
| 老版本 free=2、paid=7 | 升级后仍为 2、7 |
| `.used=2` | 剩余 3 次，不重置 |
| Lifetime 历史产品 | 离线缓存和 Restore 均保持 Lifetime |
| 同一 transactionID 回调两次 | 只入账一次 |
| transactionID 为 nil/空串 | 不入账，进入待确认/错误路径 |
| 识别期间额度被耗尽 | 不发布未扣费结果 |
| Lifetime 执行识别 | 所有额度桶保持不变 |
| App 在迁移中断后重启 | 可重试且不重复赠送/扣减 |

## 10. 发布与回滚

1. 先发布包含兼容读取与遥测的版本，不清理旧 key；
2. 观察购买成功但未入账、重复交易、迁移失败和余额为负等指标；
3. 分阶段放量，重点验证从当前线上版本直接升级；
4. 回滚版本必须仍能读取原有 key；
5. 在真实 Sandbox 覆盖购买、取消、Pending、Restore、退款后的会员状态；
6. 未完成真实设备验证前，不将“本地单测通过”等同于交易链路已验证。

## 11. 本轮实施清单

- [x] seed 标记新增时保留既有 remaining 余额；
- [x] 付费额度拒绝 nil/空 transaction ID；
- [x] 调整本地写入顺序，先增加余额再记录 transaction ID；
- [x] Plant/iNature 最终扣减失败时不再发布结果；
- [x] NatureEar 移除 CustomerInfo 强制解包；
- [x] 额度累计与总额计算增加整数溢出保护；
- [x] Paywall 增加交易缺失和重复交付回归测试；
- [ ] 将 UserDefaults 多 key 账本升级为单对象原子账本；
- [ ] 为各 App 增加旧版本快照升级测试；
- [ ] 完成 App Store Sandbox 与真实设备验证。

必须保证 `claimBonus` 幂等：同一个 campaign ID 无论点击多少次，只能发放一次。

### 4.4 展示文案

设置页建议明确区分三类额度：

```text
Free: 3
Bonus: 10
Purchased: 20
```

总额度可以显示：

```text
33 identifications remaining
```

不要只显示“Free”，否则用户会误以为 App 完全免费无限使用。

## 5. Lifetime 购买与恢复

### 5.1 购买成功

```text
RevenueCat purchase
    ↓
读取 customerInfo
    ↓
判断 entitlement / product ID
    ↓
Lifetime → setUnlimited(true)
扫描包 → addPaidCredits(amount)
    ↓
刷新 UI 和本地缓存
```

### 5.2 恢复购买

```text
restorePurchases
    ↓
RevenueCat 返回 customerInfo
    ↓
判断 Lifetime
    ↓
更新 EntitlementManager
    ↓
ledger.setUnlimited(true)
    ↓
刷新余额和付费页
```

恢复购买只负责恢复 Lifetime 这类非消耗型权益。当前本地扫描包余额不应承诺跨设备恢复，除非建立账户绑定的服务端额度账本。

### 5.3 缓存策略

推荐：本地缓存先恢复 UI，后台再验证。

```text
启动 App
    ↓
读取本地 Lifetime 缓存
    ↓
立即展示会员状态
    ↓
后台请求 RevenueCat
    ↓
明确确认有会员 → 缓存 true
明确确认无会员 → 缓存 false
网络失败 → 保留上次缓存
```

不建议每次启动时先清空 Lifetime 缓存，否则会造成会员状态闪烁和离线不可用。

## 6. 数据存储规范

统一 Key 格式：

```text
bioscan.billing.<appID>.free_remaining
bioscan.billing.<appID>.bonus_remaining
bioscan.billing.<appID>.paid_remaining
bioscan.billing.<appID>.lifetime_cache
bioscan.billing.<appID>.lifetime_verified_at
bioscan.billing.<appID>.claimed_campaigns
bioscan.billing.<appID>.schema_version
```

示例：

```text
bioscan.billing.fish.free_remaining
bioscan.billing.fish.bonus_remaining
bioscan.billing.fish.paid_remaining
```

不同 App 必须使用不同 `appID`，避免同一设备上的 App 互相读取额度。

## 7. 旧数据迁移

### 7.1 Rock、Fish、Mushroom

这些 App 已经使用剩余次数模型，可以直接迁移：

```text
旧 free key → 新 free_remaining
旧 paid key → 新 paid_remaining
旧 lifetime cache → 新 lifetime_cache
```

迁移成功后写入：

```text
schema_version = 2
```

### 7.2 Dr.Bird、Plant/iNature

这两个 App 保存的是“已使用次数”，需要转换：

```text
freeRemaining = max(initialFreeAllowance - freeUsedCount, 0)
```

转换后删除或停止读取旧的 used key，避免两个模型同时变化。

### 7.3 10 次赠送迁移

赠送额度必须使用新的 `bonus_remaining`，不能直接修改免费额度。

```text
旧用户未领取活动
    不自动发放

用户触发取消购买流程后
    才允许领取一次 10 次赠送
```

## 8. 各 App 接入配置

每个 App 只提供配置，不再自行实现额度业务：

```swift
BillingConfiguration(
    appID: "fish",
    initialFreeCredits: 5,
    entitlementID: "pro",
    lifetimeProductIDs: [
        "com.zhuoben.drfish.lifetime",
        "com.zhuoben.drfish.lifetimeV2"
    ],
    consumableProducts: [
        "com.zhuoben.drfish.scans5": 5,
        "com.zhuoben.drfish.scans20": 20
    ],
    recoveryCampaignID: "fish_purchase_recovery_v1",
    recoveryBonusCredits: 10
)
```

Rock、Mushroom、Dr.Bird、Plant 分别替换自己的 `appID`、产品 ID 和 RevenueCat API 配置即可。

## 9. 测试要求

### 9.1 CreditLedger

必须覆盖：

- 新用户初始化 5 次；
- 免费额度优先扣除；
- 免费用完后扣赠送额度；
- 赠送用完后扣付费额度；
- 无额度时返回 `noCredits`；
- Lifetime 状态下不扣任何额度；
- 购买扫描包后增加正确次数；
- 同一交易 ID 不重复加额度；
- 同一 campaign ID 不重复发放 10 次。

### 9.2 Lifetime

必须覆盖：

- 新 Lifetime 商品购买；
- 历史 Lifetime 商品恢复；
- entitlement 生效但商品 ID 不存在；
- 商品 ID 存在但 entitlement 尚未同步；
- 网络失败时保留本地缓存；
- 明确确认无会员后清除缓存；
- Lifetime 用户重启 App 后仍可识别。

### 9.3 识别流程

必须覆盖：

- 空图片不扣次数；
- 权限拒绝不扣次数；
- 引导演示不扣次数；
- 重复点击只扣一次；
- 模型未开始推理时回滚额度；
- 低置信度结果是否扣除必须明确并统一；
- 识别成功后余额立即刷新。

### 9.4 真机和沙盒

每个 App 至少验证：

- 新安装用户；
- 已使用部分免费额度的升级用户；
- 已购买扫描包用户；
- Lifetime 新购用户；
- Lifetime 恢复用户；
- 取消购买并领取 10 次赠送的用户；
- 无网络启动；
- 卸载重装后的本地额度行为。

## 10. 发布顺序

建议按以下顺序发布：

### 第一步：公共组件

- 扩展 `CreditLedger`，加入 bonus bucket；
- 增加 `EntitlementManager`；
- 增加 `RecognitionAccessController`；
- 增加 schema migration；
- 完成单元测试。

### 第二步：Fish 和 Rock

这两个 App 已经使用剩余次数模型，迁移成本最低，作为第一批接入对象。

### 第三步：Mushroom

移除自己的额度和 Lifetime 重复实现，改为公共组件。

### 第四步：Dr.Bird 和 Plant

完成“已使用次数”到“剩余次数”的数据迁移后再接入公共组件。

### 第五步：逐 App 开启 10 次赠送

建议先只在一个 App 开启，验证领取率、重复领取和额度正确性，再推广到其他 App。

## 11. 验收标准

升级完成后必须满足：

- 五个 App 的免费额度都显示和扣除一致；
- 五个 App 的 Lifetime 判断一致；
- Lifetime 用户不会消耗免费、赠送或付费额度；
- 取消购买后最多领取一次 10 次赠送；
- 10 次赠送会计入总剩余次数；
- 老用户升级后额度不丢失；
- 同一设备上的不同 App 额度互不影响；
- 无网络时已验证 Lifetime 用户仍能正常识别；
- 购买、恢复、赠送和扣除都有可追踪日志；
- 所有相关单元测试和真机沙盒测试通过。

## 12. 最终目标

最终业务链路统一为：

```text
免费 5 次
    ↓
取消购买后可领取赠送 10 次
    ↓
购买扫描包继续识别
    ↓
购买 Lifetime 后无限识别
```

App 侧只负责业务页面和识别模型，所有额度、赠送、购买、恢复、Lifetime 和迁移逻辑由 BioScanKit 统一管理。

## 13. 当前实施状态（2026-08-21）

本节用于区分已完成代码和仍需完成的工作，避免把设计方案误认为已完成能力。

### 13.1 已完成

- `CreditStorageConfiguration` 已增加独立的 `bonusCreditsKey`；
- `CreditBalance` 已增加 `bonus` 字段；
- `CreditBalance.total` 已包含 free、bonus 和 paid 三类额度；
- `CreditLedger.grantRecoveryCredits` 已写入 bonus 额度桶；
- `CreditLedger.addPurchasedCredits` 仍只写入 paid 额度桶；
- recovery 使用 `recovery:<campaignID>` 进行幂等去重；
- 五个 App 的公共 Paywall 配置已增加独立 bonus Key；
- 已增加 bonus 优先于 paid 的 CreditLedger 单元测试；
- 已增加 Lifetime 不扣除任何额度桶的单元测试；
- Fish、Rock、Mushroom、Dr.Bird、Plant/iNature 的实际识别扣除均已改为公共 `CreditLedger`；
- Rock、Mushroom、Dr.Bird 的购买扫描包已使用 StoreTransaction ID 幂等入账；
- Rock、Mushroom、Dr.Bird 的 Lifetime 验证结果已写入公共 Ledger；
- Rock、Mushroom 和 Dr.Bird iOS Simulator 全量构建已通过。
- Plant/iNature 的启动流程不再主动清除本地 Lifetime 缓存；只有成功获取 CustomerInfo 后才根据远端结果更新缓存。
- Plant/iNature 购买扫描包回调缺少 CustomerInfo 时不会清除已有 Lifetime 缓存。
- Rock、Mushroom、Dr.Bird、Plant/iNature 的共享 Paywall 购买路径已统一改为 `ledger` 记账；旧 Billing Service 仅在 App 原有设置页购买时入账，共享 Paywall 路径不再重复入账。

### 13.2 当前公共 Ledger 的扣除顺序

```text
Lifetime
    不扣除

freeRemaining > 0
    扣 freeRemaining

freeRemaining == 0 且 bonusRemaining > 0
    扣 bonusRemaining

bonusRemaining == 0 且 paidRemaining > 0
    扣 paidRemaining
```

### 13.3 尚未完成，暂不能发布

- 各 App 仍保留 RevenueCat/StoreKit 适配服务；这些服务负责商品、购买与恢复，但额度读写已委托公共 Ledger；
- 各 App 尚未全部改用 `RecognitionAccessController` 串行封装“检查、推理、扣除”，当前仍由业务流程调用 Ledger；
- 部分余额页面只显示总余额，尚未全部展示 free、bonus、paid 分项；
- 旧版本写入 paid 桶的 recovery 赠送无法仅凭本地数据区分来源；
- Dr.Bird 和 Plant 使用 `.used` 兼容旧 used-count，不进行破坏性搬迁；
- 五个 App 的真机沙盒购买、取消购买、领取 10 次和恢复 Lifetime 测试尚未全部通过。

### 13.4 当前发布风险

在真机沙盒回归全部通过前，不应直接发布本次额度拆分版本，主要剩余风险包括：

- RevenueCat 后台商品或 entitlement 配置与代码中的 product ID 不一致；
- 沙盒购买回调、恢复购买或离线启动的边界状态未被覆盖；
- 用户在识别过程中并发触发两次操作，而 App 尚未采用公共串行控制器；
- Plant CocoaPods/SwiftPM 工程当前仍受本机缓存权限和 module map 环境影响，无法完成稳定的命令行构建验证。

### 13.5 发布前必须完成

每个 App 都必须将识别入口接入公共访问控制器：

```text
识别入口
    ↓
统一 RecognitionAccessController
    ↓
读取公共 CreditLedger
    ↓
free → bonus → paid
    ↓
开始有效推理后提交扣除
```

同时移除或停用 App 内重复的免费次数、付费次数、Lifetime、赠送入账和总数计算逻辑。

### 13.6 兼容策略

本次拆分不会删除现有 paid Key：

```text
旧 paid 余额 → 继续作为 paidRemaining 使用
新 recovery 赠送 → 写入 bonusRemaining
```

已经在旧版本领取过 recovery 赠送、但当时写入 paid 桶的用户，不能仅凭本地数据判断来源，因此：

- 不自动再次补发 10 次；
- 保留旧 paid 余额；
- 新 campaign 只允许领取一次；
- 如需精确区分历史赠送，必须增加服务端账本或保留旧 campaign 记录。

### 13.7 最终验收门槛

只有满足以下条件，才能将升级标记为完成：

- 五个 App 的实际识别入口都使用公共 Ledger；
- 新用户获得 5 次免费额度；
- 取消购买后 10 次进入 bonus 桶；
- bonus 在 paid 之前被消耗；
- 购买扫描包只增加 paid；
- Lifetime 不消耗任何额度；
- 旧用户 paid 余额不丢失；
- recovery campaign 不能重复领取；
- 余额页面与实际识别结果一致；
- 真机沙盒覆盖购买、取消、领取、恢复和离线启动；
- 五个 App 分别完成构建和回归测试。

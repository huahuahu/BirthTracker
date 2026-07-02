# 关系视角与生日称谓设计

## 背景

BirthTracker 的核心目标仍然很简单：记录生日、查看生日、提醒生日。区别点是被记录的人之间存在关系，用户可以从不同人的视角查看同一组生日。例如从孩子 A 的视角看某人是爷爷，从孩子 B 的视角看同一个人可能是外公、祖父母或其他称谓。

本设计聚焦第一版关系系统：保存少量显式关系事实，在读取时推断常见亲属称谓，不把所有人对所有人的推断结果写进数据库。

## 目标

- 支持 `Person`、`Birthday` 和人与人之间的关系事实。
- 同一对人可以同时存在多种关系，例如既是兄弟又是同学。
- 任意已记录的人都可以作为查看视角。
- 支持用户为有方向的人对人选择主显示关系，例如 A 看 B 的主关系可以不同于 B 看 A。
- 通过显式亲属事实推断常见三代家庭称谓，包括父母、子女、配偶、兄弟姐妹、祖父母、孙辈、叔伯姑姨、侄甥和堂表兄弟姐妹。
- 支持朋友、同学、同事等非亲属关系；它们可显示为标签，但不参与亲属推断。
- SwiftData 主数据库只保存真实用户数据，不保存 n×n 的推断称谓。

## 非目标

- 第一版不支持任意深度亲属链。
- 第一版不支持半兄弟姐妹；直接录入的兄弟姐妹默认表示同父同母，或至少共享所有已知父母。
- 第一版不自动创建“未知父母”等虚拟人物。
- 第一版不把推断出的父子、祖孙、堂表亲等结果写回 SwiftData。
- 第一版不做完整姻亲推断，例如连襟、妯娌、配偶的兄弟姐妹等可以后续再扩展。

## 核心概念

### Person 与 Birthday

`Person` 是主数据库里的 SwiftData 存储模型，表示一个可出现在生日列表、关系图和视角选择器中的人。

`Birthday` 是 `Person` 持有的可选生日值对象。没有生日的 Person 仍可作为关系图节点或查看视角存在，但不会出现在“即将生日”列表和生日提醒中。后续生日列表、提醒和年龄计算继续基于现有生日能力，只是在展示时额外叠加当前视角下的关系称谓。

`Person` 需要新增一个可选的称谓性别字段，用于中文称谓推断：

- 男
- 女
- 未知

当称谓性别未知时，系统使用中性称谓，例如祖父母、兄弟姐妹、侄甥、堂表亲。

### RelationshipFact

`RelationshipFact` 是一条用户明确录入的关系事实，作为 SwiftData `@Model` 存储在主数据库中。

它不使用 SwiftData `@Relationship` 直接连接两端 Person，而是保存两端 Person 的稳定业务 UUID。这样可以避开 CloudKit 对 relationship optional 的限制、减少对象图循环风险，也让关系推断更像可测试的图计算。

字段：

- `id`
- `firstPersonID`
- `secondPersonID`
- `kindRawValue`
- `firstRoleRawValue`
- `secondRoleRawValue`
- `notes`
- `createdAt`
- `updatedAt`

关系类型分为两组：

| 类型 | 参与亲属推断 | 说明 |
| --- | --- | --- |
| `parentChild` | 是 | 一端 role 是 parent，另一端 role 是 child |
| `sibling` | 是 | 两端 role 都是 sibling，表示默认同父同母/共享所有已知父母 |
| `spouse` | 是 | 两端 role 都是 spouse；第一版主要用于直接配偶关系 |
| `friend` | 否 | 社交标签，双向生效 |
| `classmate` | 否 | 社交标签，双向生效 |
| `coworker` | 否 | 社交标签，双向生效 |

同一对人可以存在多条 `RelationshipFact`。例如既是兄弟又是同学，就存一条 `sibling` fact 和一条 `classmate` fact。

对称关系按 UUID 排序规范化两端，避免 A-B 和 B-A 两种重复写法。由于 CloudKit 不支持 unique constraint，去重必须在应用服务层和 resolver 内存层完成。

### RelationshipDisplayPreference

`RelationshipDisplayPreference` 保存方向性的主显示关系偏好，也作为 SwiftData `@Model` 存储。

字段：

- `id`
- `perspectivePersonID`
- `targetPersonID`
- `primaryFactID`
- `createdAt`
- `updatedAt`

`perspectivePersonID -> targetPersonID` 是有方向的。A 看 B 可以选择 sibling 作为主关系，B 看 A 可以选择 classmate 作为主关系。`primaryFactID` 指向某条显式 `RelationshipFact` 的 UUID；如果该 fact 因同步延迟或删除而不存在，系统回退到自动选择的主关系。

第一版不需要自由文本自定义称谓。中文称谓由 resolver 根据事实、视角、生日和称谓性别生成。

## RelationshipResolver

`RelationshipResolver` 是纯 Swift 推断模块，不是 SwiftData model。

输入：

- 所有已加载的人
- 所有 `RelationshipFact`
- 所有 `RelationshipDisplayPreference`
- 当前 `perspectivePersonID`

输出：

- 目标人 ID
- 主显示称谓
- 附加关系标签
- 推断来源路径
- 是否存在冲突或缺失端点

### 推断流程

1. 将显式 facts 规范化为内存图。
1. 从 `parentChild` fact 建立父母和子女集合。
1. 从 `sibling` fact 建立兄弟姐妹集合；兄弟姐妹关系可传递，并共享所有已知父母，但不会把共享父母写回 SwiftData。
1. 从 `spouse` fact 建立配偶集合。
1. 保留 `friend`、`classmate`、`coworker` 作为社交标签，不参与亲属推断。
1. 对当前视角执行有界推断，只覆盖常见三代关系。
1. 合并手动主关系偏好、推断亲属称谓和社交标签。

### 主称谓优先级

1. 有效的方向性 `RelationshipDisplayPreference`
1. 直接亲属事实
1. 三代内推断亲属关系
1. 社交关系
1. 无关系标签

### 三代亲属规则

第一版需要覆盖：

- 父母：目标是视角人的 parent。
- 子女：目标是视角人的 child。
- 配偶：目标是视角人的 spouse。
- 兄弟姐妹：目标与视角人同属 sibling group。
- 祖父母：目标是视角人父母的 parent。
- 孙辈：目标是视角人子女的 child。
- 叔伯姑姨：目标是视角人父母的 sibling。
- 侄甥：目标是视角人 sibling 的 child。
- 堂表兄弟姐妹：目标是视角人父母 sibling 的 child。

年龄大小称谓依赖生日数据。只有当双方生日足够比较时才显示哥哥、弟弟、姐姐、妹妹、堂兄、堂弟等细分称谓；否则显示兄弟姐妹或堂表亲。

堂/表、爷爷/外公等中文细分称谓依赖父母侧和称谓性别。信息不足时使用中性称谓，避免猜错。

## 用户体验

### 生日时间线

生日时间线顶部增加“从谁的视角看”选择器，候选是所有已记录 Person。

未选择视角时，列表只显示姓名、生日和倒计时，不显示关系称谓。选择视角后，每张生日卡片显示：

- 姓名
- 下次生日和倒计时
- 当前视角下的主称谓
- 可选附加标签，例如同学、朋友、同事

切换视角只触发 resolver 重新计算，不写数据库。

### 人物详情与关系管理

生日基础表单继续专注于姓名、生日、备注等个人信息。关系管理放在人物详情或独立关系管理页。

关系管理页支持：

- 选择另一个已记录 Person。
- 添加一条或多条关系事实。
- 为当前方向选择主显示关系。
- 查看显式关系、推断关系路径和社交标签。
- 显示冲突或缺失端点提示。

### 提醒

提醒文案使用默认视角的 resolver 结果。默认视角未设置时，提醒只使用姓名，例如“Alex 明天生日”；默认视角已设置时，可以显示“爷爷明天生日”。

## 数据一致性与错误处理

- 新增关系事实前，服务层按规范化 person pair、kind 和 roles 做应用层去重。
- 删除 Person 时，服务层先删除引用该 person UUID 的 `RelationshipFact` 和 `RelationshipDisplayPreference`，再删除 Person。
- SwiftData 保存失败必须提示用户，不做静默成功。
- CloudKit 同步延迟导致 fact 只同步到一端 Person 时，resolver 暂时忽略该 fact，并在详情或 debug 信息中标记缺失端点。
- preference 指向的 fact 不存在时，resolver 回退到自动主关系。
- 重复 fact 在 resolver 内存层去重，避免重复标签。
- 冲突事实不会自动修复；resolver 返回冲突标记，由 UI 引导用户检查关系。

## 测试策略

### SwiftData 持久化测试

- `RelationshipFact` 可以 round-trip。
- 同一对人可以保存多条不同类型 fact。
- `RelationshipDisplayPreference` 可以按方向保存 A→B 和 B→A 的不同主关系。
- 删除 Person 会清理引用该 person UUID 的 facts 和 preferences。
- 保存失败会向调用层抛出或返回错误。

### Resolver 单元测试

- parent-child 可推断父母和子女。
- sibling 可直接显示兄弟姐妹。
- sibling 共享已知父母，但不写回数据库。
- sibling + 已知父母可继续推断祖父母、叔伯姑姨和堂表亲。
- friend/classmate/coworker 只显示标签，不参与亲属推断。
- 同一对人多关系时，方向性主关系优先生效。
- 生日足够时区分长幼；信息不足时使用中性称谓。
- 称谓性别未知时使用中性称谓。
- 缺失端点不会崩溃。
- 重复 fact 不产生重复标签。
- 冲突 facts 会返回冲突标记。

## 开放但不阻塞第一版的问题

- 是否需要在后续支持半兄弟姐妹。
- 是否需要完整姻亲推断。
- 是否需要导入通讯录时自动建议关系。
- 是否需要关系图可视化页面。

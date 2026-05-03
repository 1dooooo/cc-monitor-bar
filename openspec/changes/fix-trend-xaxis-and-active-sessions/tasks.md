## 1. 趋势图 x 轴对齐修复

- [x] 1.1 为 StackedBarDay 设置固定宽度，确保 7 根柱子宽度一致
- [x] 1.2 调整 HStack spacing，确保柱子间距均匀
- [x] 1.3 日期标签与柱子宽度一致，居中对齐

## 2. 趋势图 tooltip 实现

- [x] 2.1 在 TrendChartSection 添加悬停状态跟踪
- [x] 2.2 为每根柱子添加 overlay tooltip
- [x] 2.3 实现 TrendTooltip 视图显示详细数据
- [x] 2.4 处理 tooltip 边界，确保不超出 Popover

## 3. 活跃会话数据验证

- [x] 3.1 检查 SessionUsage 数据传递逻辑
- [x] 3.2 确保 ActiveSessionSection 正确显示 SessionUsage 数据
- [x] 3.3 验证数据刷新时活跃会话自动更新

## 4. 验证

- [x] 4.1 编译通过
- [x] 4.2 验证趋势图 x 轴对齐正确
- [x] 4.3 验证 tooltip 悬停显示正常
- [x] 4.4 验证活跃会话数据准确

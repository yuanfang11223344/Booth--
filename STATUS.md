# Booth 编码工程状态

本工程提供可运行的 Booth 编码教材、Verilog RTL、仿真、波形、形式验证和通用综合对照。最后核验日期：2026-10-22。

## 工程内容

- 约 7 分 46 秒的中文 MP4 讲解、独立 M4A 音频及逐字稿，覆盖原论文、手算、RTL、真实波形和架构选择。

- 八种有符号 Booth RTL：radix-2/4/8 迭代，radix-4/8 并行线性与 CSA，以及 radix-4 CSA 流水；另有无符号 radix-4 封装和 `*` 推断对照。
- 八章中文教材从两补码和分组推导讲到部分积、硬件架构、波形、应用条件、形式证明和练习解答、原论文精读。
- `scripts/recode.py` 打印手算分组；`scripts/check_math.py` 检查重编码恒等式；真实 VCD 导出周期 CSV 和波形图片。
- `scripts/synth_compare.py` 对各顶层单独加载 RTL 依赖，产生 W=8/16 的 Yosys 通用映射网表、日志和 CSV；`scripts/plot_synth.py` 据此绘图。

## 验证记录

| 检查 | 实测结果 | 证据 |
| --- | --- | --- |
| `bash scripts/run.sh` | 2026-10-23 重跑通过；W=2–7 穷举，W=8/9/12/16/24/31/32 边界与随机测试 | `build/run_recheck_20261023.log` |
| `bash scripts/lint.sh` | 2026-10-23 重跑通过；54 项 RTL 参数展开和 12 个测试/形式顶层 | `build/lint_recheck_20261023.log` |
| `bash scripts/formal_check.sh --deep` | 退出码 0，55 项 PASS；包含 radix-8 迭代 W=8 乘积/控制归纳 | `build/formal/deep_final.log` |
| W=8 radix-8 迭代乘积及控制归纳 | 单项成功，归纳长度 5 | `build/formal/iter_r8_w8_composed_induct_trial.log` |
| W=8 radix-2 迭代乘积及控制归纳 | 成功，归纳长度 17 | `build/formal/iter_r2_w8_composed_induct.log` |
| 数学重编码检查 | W=2–16 共 131,068 个乘数位模式通过 | `scripts/check_math.py`、形式脚本日志 |

有符号等价仿真覆盖 **25,457** 对输入，每对检查八种 Booth 实现、`*` 基线与 testbench 数学乘积；无符号封装另覆盖 **25,379** 对输入。控制 testbench 检查忙时启动、完成脉冲、结果保持、复位取消和流水连续输入。W=8 的四种组合 Booth 架构和无符号封装有全输入 SAT 等价证明；三种迭代和流水版在 W=4/5 有任意控制输入的有限步证明，在 W=8 有聚焦交易证明。W=8 的流水、radix-4、radix-8 以及 radix-2 迭代已有乘积与控制归纳证明：先证明 radix-4 CSA 组合参考等于数学乘积，再证明各时序模块相对独立记分板的采样、结果与控制关系。归纳从零寄存器初态出发，不宣称任意内部初态或自动推广到其他位宽。

W=8/32 的三种迭代控制与流水控制通过有限步和归纳检查；W=32 的乘积只经边界与随机仿真。W=12 radix-4 CSA 全输入 SAT 曾在 300 秒限制内超时，记为未证成，并非发现反例。详细证明条件见[第六章](docs/06_综合与形式验证.md)。

## 综合与波形

W=16 的通用映射中，radix-4 线性/CSA 分别为 1767/1787 个组合 cell，radix-8 线性/CSA 为 2014/2049 个；radix-8 迭代为 879 个组合 cell、101 个 FF bit，拓扑长度 85。两次独立运行的 `build/synth/summary.csv` SHA-256 均为 `93cd4e9e0b3a7ff1fb392435366951e2820c282f0e27815ee22aea4e5356f598`。这些是指定 Yosys/ABC 通用映射结果，并非真实 FPGA/ASIC 面积、频率或功耗。图见 `assets/synth_w16.png`。

`assets/waveform_13x-7.png` 和 `assets/waveform_minx-1.png` 来自对应的 VCD，展示 radix-2/4/8 的中间寄存器和完成周期；流水波形另见 `assets/pipeline_13x-7.png`。当前环境没有可调用的 `wave-mcp` 工具，`scripts/vcd_report.py` 可在本地复现波形分析。

## 编辑器诊断复查（2026-10-23）

用户在 VS Code 看到的 30 个错误与 6 个警告来自 Digital IDE 把 `formal/`、`tb/` 文件单独交给 Verilator，却没有搜索 `rtl/`，因此出现 `Cannot find file containing module` 以及随之而来的层级信号错误。该插件当前安装的 0.5.0 版本还缺少 macOS 的 `digital-server`，重载后后端未启动；VS Code 显示零问题不能单独当作语法通过证据。

工程新增 `.vscode/settings.json`，在本工作区关闭故障中的 Digital IDE 诊断器，改用已安装的 Verilog-Hdl-Format 插件运行 Verilator，并指定 `rtl/` 搜索路径。命令行对全部 12 个测试/形式顶层分别使用相同搜索路径做 lint，零错误零默认告警；已把这项检查纳入 `scripts/lint.sh`。另外显式处理 testbench 中有意的位宽截取，轨迹输入在截取前做范围检查。工程 RTL、完整仿真和形式验证证据分别见上表。

## 交付边界

要评估是否能在目标设计中替代现有乘法器，需固定 FPGA 器件或 ASIC 工艺库、时钟约束、寄存器边界、DSP 策略及布局布线条件，分别测量面积、时延、吞吐和功耗。本工程的通用综合表只用于解释架构与工具映射的关系。
